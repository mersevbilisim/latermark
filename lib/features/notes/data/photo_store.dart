import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'image_compressor.dart';

/// Çekilen kareleri uygulama belge klasöründe tutar.
///
/// Veritabanı yalnızca dosya *adını* bilir; mutlak yola çeviren tek yer
/// burasıdır. Böylece iOS'ta konteyner yolu değişse bile kayıtlar bozulmaz.
class PhotoStore {
  PhotoStore._(this._directory, {ImageCompressor? compressor})
    : _compressor = compressor ?? ImageCompressor();

  final Directory _directory;
  final ImageCompressor _compressor;
  static final _random = Random();

  static const _folderName = 'captures';

  /// Izgaranın küçük kopyaları. `captures` **içinde** duruyor, kardeşi değil:
  ///
  /// * [pruneOrphans] yalnız dosyaları geziyor, klasörü kendiliğinden atlıyor
  /// * Geri yükleme bütün `captures` klasörünü değiştirdiği için eski küçük
  ///   kopyalar da doğal olarak gidiyor; kardeş klasörde kalsalar yeni
  ///   kayıtlarla eşleşmeyen yetimler olurdu
  static const _thumbFolder = 'thumbs';

  /// Küçük kopyanın uzun kenarı.
  ///
  /// Izgara sütunu 3x ekranda ~524 fiziksel piksel; 600 hem onu karşılıyor hem
  /// de küçük bir pay bırakıyor. Ölçüm: 2048 kaynaktan çözmek kare başına
  /// 11,9 ms, 600'den çözmek 1,9 ms — altı kattan fazla fark ve ızgaradaki
  /// takılmanın tamamı buradan geliyordu.
  static const thumbEdge = 600;

  /// Klasörü çözer ve yoksa oluşturur. Uygulama açılışında bir kez çağrılır,
  /// sonrasında tüm erişim eşzamanlıdır.
  static Future<PhotoStore> open() =>
      _openIn(getApplicationDocumentsDirectory());

  /// Testlerde geçici bir klasöre bağlanmak için.
  static Future<PhotoStore> openIn(
    Directory parent, {
    @visibleForTesting ImageCompressor? compressor,
  }) => _openIn(Future.value(parent), compressor: compressor);

  static Future<PhotoStore> _openIn(
    Future<Directory> parent, {
    ImageCompressor? compressor,
  }) async {
    final directory = Directory(p.join((await parent).path, _folderName));
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    return PhotoStore._(directory, compressor: compressor);
  }

  /// Kayıtlı bir dosya adını okunabilir [File] nesnesine çevirir.
  File fileFor(String name) => File(p.join(_directory.path, name));

  /// Aynı adın küçük kopyası. Var olduğu garanti değil.
  File thumbFor(String name) =>
      File(p.join(_directory.path, _thumbFolder, name));

  /// Izgaranın çizeceği dosya.
  ///
  /// Küçük kopya yoksa tam kare dönüyor — bu, yükseltmeden gelen kullanıcının
  /// akışının ilk açılışta da eksiksiz çizilmesini sağlıyor. Kopyalar arka
  /// planda üretildikçe akış kendiliğinden hızlanıyor.
  File gridFileFor(String name) {
    final thumb = thumbFor(name);
    return thumb.existsSync() ? thumb : fileFor(name);
  }

  /// Küçük kopya üretilebiliyor mu.
  ///
  /// Küçültme yerel kanaldan geçiyor ve o kanal yalnız iOS/Android'de var.
  /// Desteklenmeyen bir ortamda geri doldurmaya hiç girmemek gerekiyor: her
  /// kare için kopya oluşturup küçülmediğini görüp silmek boşuna iş.
  bool get canThumbnail => _compressor.supported;

  /// Küçük kopyayı üretir. Zaten varsa dokunmaz.
  ///
  /// Küçültme gerçekleşmezse kopya **siliniyor**: tam boy bir ikinci dosya
  /// tutmak yer harcar ve hiçbir hız kazandırmaz. Böyle bir durumda ızgara
  /// tam kareyi çizmeye devam eder.
  Future<bool> ensureThumbnail(String name) async {
    if (!canThumbnail) return false;
    final source = fileFor(name);
    if (!source.existsSync()) return false;

    final thumb = thumbFor(name);
    if (thumb.existsSync()) return true;

    try {
      await thumb.parent.create(recursive: true);
      await source.copy(thumb.path);
      final shrunk = await _compressor.compress(thumb, edge: thumbEdge);
      if (!shrunk) {
        if (thumb.existsSync()) await thumb.delete();
        return false;
      }
      return true;
    } on FileSystemException {
      return false;
    }
  }

  /// Geri yüklenen kareleri hazırlar ve klasörleri atomik olarak değiştirir.
  ///
  /// Geçici klasör başka bir dosya sisteminde olabilir. Bu yüzden yeni kareler
  /// önce `captures` ile **aynı ebeveynde** bir kardeş klasöre kopyalanır;
  /// mevcut klasöre o tamamlanmadan dokunulmaz. Sonra iki kısa `rename` ile
  /// eski depo kenara, yeni depo yerine alınır.
  ///
  /// Dönen işlem DB yazımı başarılı olursa [PhotoStoreReplacement.commit],
  /// hata verirse [PhotoStoreReplacement.rollback] çağrılmadan bırakılamaz.
  Future<PhotoStoreReplacement> beginReplaceAllFrom(Directory staging) async {
    final token =
        '${DateTime.now().microsecondsSinceEpoch}-'
        '${_random.nextInt(0xFFFFFF).toRadixString(16)}';
    final incoming = Directory('${_directory.path}.incoming-$token');
    final previous = Directory('${_directory.path}.previous-$token');
    await incoming.create();

    try {
      if (staging.existsSync()) {
        await for (final entity in staging.list(followLinks: false)) {
          if (entity is! File) continue;
          final name = p.basename(entity.path);
          await entity.copy(p.join(incoming.path, name));
        }
      }

      final hadPrevious = _directory.existsSync();
      if (hadPrevious) await _directory.rename(previous.path);
      try {
        await incoming.rename(_directory.path);
      } catch (_) {
        if (hadPrevious && previous.existsSync() && !_directory.existsSync()) {
          await previous.rename(_directory.path);
        }
        rethrow;
      }

      return PhotoStoreReplacement._(
        current: _directory,
        previous: previous,
        hadPrevious: hadPrevious,
        token: token,
      );
    } catch (_) {
      if (incoming.existsSync()) {
        try {
          await incoming.delete(recursive: true);
        } on FileSystemException {
          // Asıl hatayı koru; bu yalnız tamamlanmamış bir kardeş klasör.
        }
      }
      rethrow;
    }
  }

  /// Kamera çıktısını kalıcı klasöre taşır ve saklanacak dosya adını döner.
  ///
  /// Kare **önce** kaydediliyor, sonra küçültülüyor. Sıra böyle: sıkıştırma
  /// başarısız olsa bile kullanıcının fotoğrafı yerinde duruyor.
  ///
  /// Küçültme **beklenmiyor**. Kullanıcının kaydettiği an bittiğinde kare
  /// zaten diskte ve not yazılabilir durumda; sıkıştırma yalnızca dosyayı
  /// küçülten bir iyileştirme ve sonucu ekranda hiçbir şeyi değiştirmiyor.
  /// Beklemek, kullanıcıyı 12 MP bir kareyi çözüp yeniden kodlamanın süresi
  /// kadar "Kaydet" ekranında tutmak demekti — görünürde hiçbir karşılığı
  /// olmayan bir bekleme.
  ///
  /// Arka planda yürütmek yalnızca yazma atomik olduğu için güvenli: her iki
  /// platform da yeni kareyi yan dosyaya yazıp yerine taşıyor, dolayısıyla
  /// aynı anda okuyan akış hep bütün bir kare görüyor. Uygulama arada
  /// kapanırsa kare sıkıştırılmamış kalır — yalnızca daha büyük, bozuk değil.
  Future<String> persist(XFile capture) async {
    final name = _uniqueName(p.extension(capture.path));
    final destination = p.join(_directory.path, name);
    await capture.saveTo(destination);
    unawaited(_compressInBackground(File(destination)));
    return name;
  }

  /// Dokunulmamış kareyi saklar ve dosya adını döner.
  ///
  /// [persist]'ten tek farkı küçültmemesi — orijinalin bütün anlamı olduğu
  /// gibi kalması. Küçük kopya da üretilmiyor: orijinal ızgarada, aramada,
  /// ana ekranda ya da widget'ta hiç çizilmiyor. Yalnızca detay ekranı ve
  /// kullanıcının açıkça istediği paylaşım onu okuyor.
  ///
  /// Sıkıştırma [persist]'in kendi kopyası üzerinde çalıştığı için kaynak
  /// dosyaya dokunulmuyor; iki kopyanın sırası önemli değil.
  Future<String> persistOriginal(XFile capture) async {
    final name = _uniqueName(p.extension(capture.path));
    await capture.saveTo(p.join(_directory.path, name));
    return name;
  }

  /// Sıkıştırmayı kaydetme yolundan ayırır ve hatalarını yutar.
  ///
  /// Kullanıcı kaydettiği notu hemen silerse sıkıştırma silinmiş bir dosyayı
  /// geri yazabilir; [pruneOrphans] açılışta o yetimi zaten topluyor.
  Future<void> _compressInBackground(File image) async {
    try {
      await _compressor.compress(image);
      // Küçük kopya sıkıştırmadan **sonra** üretiliyor: 2048'lik kareden
      // küçültmek 12 MP'lik ham kareden küçültmekten belirgin ucuz.
      await ensureThumbnail(p.basename(image.path));
    } catch (_) {
      // Sıkıştırma bir iyileştirme; başarısızlığı kaydı etkilemez.
    }
  }

  /// Notu silerken çağrılır. Dosya zaten yoksa sessizce geçer.
  Future<void> remove(String name) async {
    for (final file in [fileFor(name), thumbFor(name)]) {
      if (!file.existsSync()) continue;
      try {
        await file.delete();
      } on FileSystemException {
        // Disk hatası bir notun silinmesini engellememeli.
      }
    }
  }

  Future<void> removeAll(Iterable<String> names) async {
    for (final name in names) {
      await remove(name);
    }
  }

  /// Yeni yazılmış bir dosyanın yetim sayılmadan önce tanınacağı süre.
  ///
  /// [persist] kareyi **satırdan önce** diske yazıyor; arada bir pencere var.
  /// Süpürme açılışta `unawaited` koştuğu ve isim listesini önden aldığı için
  /// o pencerede kaydedilen kare "kaydı yok" diye silinebiliyordu — kullanıcı
  /// notu görüyor, fotoğrafı gitmiş oluyordu. Paylaşımdan gelip açılışta
  /// kendiliğinden kaydedilen kareler tam da bu aralığa denk geliyor.
  ///
  /// Bu yaşta bir dosyayı atlamak hiçbir şey kaybettirmiyor: gerçek yetim
  /// bir sonraki açılışta zaten toplanıyor.
  static const _orphanGrace = Duration(minutes: 5);

  /// Veritabanında karşılığı kalmamış dosyaları temizler. Kayıt silinirken
  /// uygulama öldürülürse ortaya çıkan yetim dosyalar için.
  Future<void> pruneOrphans(Set<String> knownNames) async {
    if (!_directory.existsSync()) return;
    final cutoff = DateTime.now().subtract(_orphanGrace);
    await _pruneIn(_directory, knownNames, cutoff);
    // Küçük kopyalar ayrı klasörde; kaydı kalkmış bir kopya orada kalırsa
    // hiçbir şeyin bakmadığı bir yerde yer kaplardı.
    final thumbs = Directory(p.join(_directory.path, _thumbFolder));
    if (thumbs.existsSync()) await _pruneIn(thumbs, knownNames, cutoff);
  }

  Future<void> _pruneIn(
    Directory directory,
    Set<String> knownNames,
    DateTime cutoff,
  ) async {
    await for (final entity in directory.list()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (knownNames.contains(name)) continue;
      try {
        if (entity.lastModifiedSync().isAfter(cutoff)) continue;
        await entity.delete();
      } on FileSystemException {
        // Yoksay.
      }
    }
  }

  String _uniqueName(String extension) {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final salt = _random.nextInt(0xFFFF).toRadixString(16).padLeft(4, '0');
    final safeExtension = extension.isEmpty ? '.jpg' : extension;
    return '$stamp-$salt$safeExtension';
  }
}

/// Fotoğraf klasörü değişiminin DB transaction'ıyla birlikte tamamlanan ikinci
/// yarısı. Yalnız [PhotoStore] üretir.
final class PhotoStoreReplacement {
  PhotoStoreReplacement._({
    required this._current,
    required this._previous,
    required this._hadPrevious,
    required this._token,
  });

  final Directory _current;
  final Directory _previous;
  final bool _hadPrevious;
  final String _token;
  bool _closed = false;

  /// DB yeni kayıtları başarıyla aldı; eski kareler artık gereksiz.
  Future<void> commit() async {
    if (_closed) return;
    _closed = true;
    if (!_previous.existsSync()) return;
    try {
      await _previous.delete(recursive: true);
    } on FileSystemException {
      // Yeni veri eksiksiz yerinde. Eski kardeş klasör yalnız disk artığıdır;
      // geri yüklemeyi başarısız göstermemeli.
    }
  }

  /// DB yazımı başarısız oldu; yeni kareleri kenara alıp eskileri geri koyar.
  Future<void> rollback() async {
    if (_closed) return;
    _closed = true;
    final failed = Directory('${_current.path}.failed-$_token');

    if (_current.existsSync()) await _current.rename(failed.path);
    try {
      if (_hadPrevious && _previous.existsSync()) {
        await _previous.rename(_current.path);
      } else {
        await _current.create(recursive: true);
      }
    } catch (_) {
      // Eskiyi geri alamadıysak en azından az önce kenara koyduğumuz, doğrulanmış
      // yeni klasörü tekrar görünür yapmayı dene; depo boş kalmasın.
      if (!_current.existsSync() && failed.existsSync()) {
        await failed.rename(_current.path);
      }
      rethrow;
    }

    if (failed.existsSync()) {
      try {
        await failed.delete(recursive: true);
      } on FileSystemException {
        // Eski depo geri döndü; başarısız yeni kopya yalnız disk artığıdır.
      }
    }
  }
}
