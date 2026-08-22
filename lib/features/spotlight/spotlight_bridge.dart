import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/utils/app_format.dart';
import '../../l10n/app_localizations.dart';
import '../notes/data/notes_database.dart';
import '../notes/data/notes_repository.dart';
import 'spotlight_item.dart';

/// Kayıtları iPhone'un Spotlight aramasına taşıyan köprü.
///
/// Native taraf bilinçli olarak akılsız: "şunları indeksle", "şunları kaldır"
/// dışında bir şey bilmiyor. Neyin değiştiğine karar veren, imzaları diskte
/// tutan ve OCR metnini yalnızca gerektiğinde okuyan taraf burası. Böylece
/// kuralın tamamı tek dilde, test edilebilir bir yerde duruyor.
///
/// Uygulamanın **kendi** araması bundan hiç etkilenmiyor: o hâlâ `note_search`
/// tablosu üzerinde dönüyor ve bu köprü aynı tabloyu yalnızca okuyor.
class SpotlightBridge {
  SpotlightBridge(
    this._repository, {
    @visibleForTesting MethodChannel? channel,
    @visibleForTesting Future<Directory> Function()? stateDirectory,
    @visibleForTesting bool? supported,
  }) : _channel = channel ?? const MethodChannel(_channelName),
       _stateDirectory = stateDirectory ?? getApplicationSupportDirectory,
       _supportedOverride = supported;

  static const _channelName = 'latermark/spotlight';
  static const _stateFileName = 'spotlight_index.json';
  static const _stateVersion = 3;

  /// Tek turda kaç kaydın metni belleğe alınır.
  ///
  /// İlk açılışta —ya da uygulama güncellendikten sonraki ilk açılışta— bütün
  /// arşiv indekslenmek zorunda. Bir karenin metni 8.000 karaktere kadar
  /// çıkabildiği için binlik bir arşivde hepsini birden okumak on megabaytları
  /// bulur. Bölerek ilerlemek tavanı sabit tutuyor ve aradaki `await`'ler
  /// arayüze nefes aldırıyor.
  static const _batchSize = 40;

  final NotesRepository _repository;
  final MethodChannel _channel;
  final Future<Directory> Function() _stateDirectory;
  final bool? _supportedOverride;

  StreamSubscription<List<Note>>? _subscription;
  Map<int, String>? _indexed;
  List<Note>? _lastNotes;
  L10n? _l10n;
  bool _disposed = false;
  bool _requiresFullRebuild = false;

  /// Yayınlar tek sırada ilerler: liste akışı ile OCR taraması peş peşe
  /// yayın yapabiliyor ve iki diff aynı anda koşarsa imza dosyası birinin
  /// gördüğü, diğerinin görmediği bir hâlde kalırdı.
  Future<void> _queue = Future<void>.value();

  bool get _supported => _supportedOverride ?? (!kIsWeb && Platform.isIOS);

  /// Boş notların başlığı kaydın tarihinden üretiliyor; o da dile bağlı.
  set l10n(L10n value) {
    if (_l10n?.localeName == value.localeName) return;
    _l10n = value;
    final notes = _lastNotes;
    if (notes != null) _schedule(notes);
  }

  Future<void> start() async {
    if (!_supported || _disposed) return;
    _channel.setMethodCallHandler(_handleNativeCall);
    _subscription = _repository.watchNotes().listen((notes) {
      _lastNotes = notes;
      _schedule(notes);
    });
  }

  /// Arka planda bir kare okunduğunda çağrılır.
  ///
  /// Liste akışı bundan haberdar olmuyor — tarama bilinçli olarak `notes`
  /// tablosuna dokunmuyor, yoksa her taranan kare bütün listeyi yeniden
  /// kurdururdu. Haberi bu yüzden tarayan taraf veriyor.
  void scanCompleted() {
    final notes = _lastNotes;
    if (notes != null) _schedule(notes);
  }

  /// Sıradaki yayınların bitmesini bekler.
  ///
  /// Yayınlar akış dinleyicisinden tetiklendiği ve kuyruğa girdiği için
  /// testin bekleyeceği tek bir `Future` yok; kuyruk büyümeyi bırakana kadar
  /// beklenir.
  @visibleForTesting
  Future<void> get settled async {
    var previous = _queue;
    while (true) {
      await previous;
      if (identical(previous, _queue)) return;
      previous = _queue;
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _channel.setMethodCallHandler(null);
    await _subscription?.cancel();
    _subscription = null;
  }

  void _schedule(List<Note> notes) {
    if (!_supported || _disposed || _l10n == null) return;
    _queue = _queue.then((_) async {
      if (_disposed) return;
      try {
        await _publish(notes);
      } catch (error) {
        // İndeksleme bir kolaylık; başarısızlığı uygulamanın hiçbir işini
        // durdurmuyor. Bir sonraki değişimde yeniden denenir.
        debugPrint('Spotlight indeksi güncellenemedi: $error');
      }
    });
    unawaited(_queue);
  }

  Future<void> _publish(List<Note> notes) async {
    final l10n = _l10n;
    if (l10n == null) return;

    if (_indexed == null) {
      final state = await _readState();
      _indexed = Map<int, String>.of(state.items);
      _requiresFullRebuild = _requiresFullRebuild || state.requiresRebuild;

      // Uygulamanın imza dosyası ile Core Spotlight'ın kendi deposu ayrı
      // yaşıyor. iOS indeksi yeniden kurduğunda (simülatör reset'i ve
      // düşük disk alanı dâhil) uygulama dosyası yerinde kalabiliyor. Yalnız
      // bu dosyaya güvenmek, aslında kayıp bir kaydı sonsuza dek "değişmedi"
      // sanmamıza yol açar. Core Spotlight'taki bütün Latermark kimliklerini
      // tek sorguda okuyup yerel imzalarla birebir karşılaştırmak hem tam hem
      // de kısmi indeks kaybını yakalar. Fazladan/hayalet bir kayıt da aynı
      // şekilde temiz bir rebuild'e yükseltilir.
      if (!_requiresFullRebuild) {
        final nativeIds =
            (await _channel.invokeListMethod<int>('indexedIds'))?.toSet() ??
            <int>{};
        if (nativeIds.length != _indexed!.length ||
            !nativeIds.containsAll(_indexed!.keys)) {
          _requiresFullRebuild = true;
        }
      }
    }
    final indexed = _indexed!;
    final photoFingerprints = await _repository.spotlightPhotoFingerprints();

    if (_requiresFullRebuild) {
      // Önce diske "rebuild sürüyor" yazılır. Reset'ten hemen sonra süreç
      // kapanırsa sonraki açılış eski imzalara güvenmek yerine tekrar resetler.
      await _writeState(indexed, rebuilding: true);
      await _invoke('reset', const {});
      indexed.clear();
    }

    final desired = <int, String>{};
    final titles = <int, String>{};
    for (final note in notes) {
      final title = note.body.trim();
      titles[note.id] = title.isEmpty
          ? l10n.calendarDate(note.createdAt)
          : title;
      desired[note.id] = spotlightFingerprint(
        title: title,
        createdAt: note.createdAt,
        photoFingerprint: photoFingerprints[note.id],
        localeName: l10n.localeName,
      );
    }

    final stale = [
      for (final id in indexed.keys)
        if (!desired.containsKey(id)) id,
    ];
    final changed = [
      for (final entry in desired.entries)
        if (indexed[entry.key] != entry.value) entry.key,
    ];
    if (stale.isEmpty && changed.isEmpty) {
      if (_requiresFullRebuild) {
        _requiresFullRebuild = false;
        await _writeState(indexed);
      }
      return;
    }

    if (stale.isNotEmpty) {
      await _invoke('remove', {'ids': stale});
      indexed.removeWhere((id, _) => !desired.containsKey(id));
    }

    for (var start = 0; start < changed.length; start += _batchSize) {
      if (_disposed) break;
      final batch = changed.sublist(
        start,
        (start + _batchSize).clamp(0, changed.length),
      );
      // Metin yalnızca **bu** tur için okunuyor; taranmamış kayıtlar sonuçta
      // hiç görünmüyor ve boş metinle indekslenmeleri de doğru.
      final texts = await _repository.photoTextOf(batch);
      final byId = {for (final note in notes) note.id: note};

      await _invoke('index', {
        'items': [
          for (final id in batch)
            if (byId[id] case final note?)
              SpotlightItem(
                noteId: id,
                title: titles[id] ?? '',
                photoText: texts[id] ?? '',
                createdAt: note.createdAt,
              ).toArguments(),
        ],
      });

      for (final id in batch) {
        if (desired[id] case final fingerprint?) indexed[id] = fingerprint;
      }
      // Her tur diske yazılıyor: uygulama ilk indeksleme yarıda kalırken
      // kapanırsa bir sonraki açılış kaldığı yerden devam etsin.
      await _writeState(indexed, rebuilding: _requiresFullRebuild);
    }

    if (changed.isEmpty) {
      await _writeState(indexed, rebuilding: _requiresFullRebuild);
    }
    if (!_disposed && _requiresFullRebuild) {
      _requiresFullRebuild = false;
      await _writeState(indexed);
    }
  }

  Future<void> _invoke(String method, Map<String, Object?> arguments) async {
    await _channel.invokeMethod<void>(method, arguments);
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method != 'reindexAll') throw MissingPluginException();
    _requiresFullRebuild = true;
    final notes = _lastNotes;
    if (notes != null) _schedule(notes);
    await settled;
  }

  /// İmzaların diskteki hâli.
  ///
  /// Veritabanına bir sütun eklemek yerine yanda küçük bir dosya: bu veri
  /// kullanıcının değil, indeksin durumu. Silinirse en kötü ihtimalle bir
  /// sonraki açılış her şeyi yeniden indeksler — kaybolacak bir şey yok.
  Future<File> _stateFile() async =>
      File('${(await _stateDirectory()).path}/$_stateFileName');

  Future<_SpotlightState> _readState() async {
    try {
      final file = await _stateFile();
      if (!file.existsSync()) return const _SpotlightState.rebuild();
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map || decoded['version'] != _stateVersion) {
        return const _SpotlightState.rebuild();
      }
      final rawItems = decoded['items'];
      if (rawItems is! Map) return const _SpotlightState.rebuild();
      return _SpotlightState(
        items: {
          for (final entry in rawItems.entries)
            if (int.tryParse('${entry.key}') case final id?)
              if (entry.value is String) id: entry.value as String,
        },
        requiresRebuild: decoded['rebuilding'] == true,
      );
    } catch (error) {
      // Bozuk dosyada native indeksin ne içerdiği bilinmez; yalnız mevcut
      // kayıtları eklemek hayalet sonuçları bıraktığından tam reset gerekir.
      debugPrint('Spotlight imzaları okunamadı: $error');
      return const _SpotlightState.rebuild();
    }
  }

  Future<void> _writeState(
    Map<int, String> indexed, {
    bool rebuilding = false,
  }) async {
    try {
      final file = await _stateFile();
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(
        jsonEncode({
          'version': _stateVersion,
          'rebuilding': rebuilding,
          'items': {for (final e in indexed.entries) '${e.key}': e.value},
        }),
        flush: true,
      );
      await temporary.rename(file.path);
    } catch (error) {
      debugPrint('Spotlight imzaları yazılamadı: $error');
    }
  }
}

final class _SpotlightState {
  const _SpotlightState({required this.items, required this.requiresRebuild});

  const _SpotlightState.rebuild() : items = const {}, requiresRebuild = true;

  final Map<int, String> items;
  final bool requiresRebuild;
}
