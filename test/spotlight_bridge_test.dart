import 'dart:convert';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latermark/features/notes/data/notes_database.dart';
import 'package:latermark/features/notes/data/notes_repository.dart';
import 'package:latermark/features/notes/data/photo_store.dart';
import 'package:latermark/features/notes/domain/retention.dart';
import 'package:latermark/features/spotlight/spotlight_bridge.dart';
import 'package:latermark/features/spotlight/spotlight_item.dart';
import 'package:latermark/l10n/app_localizations.dart';

/// Native tarafın yerine geçen kayıt defteri.
class _FakeSpotlight {
  final indexed = <List<Map<String, Object?>>>[];
  final removed = <List<int>>[];
  int resets = 0;

  static const channel = MethodChannel('latermark/spotlight');

  _FakeSpotlight() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, _handle);
  }

  Future<Object?> _handle(MethodCall call) async {
    final arguments = (call.arguments as Map).cast<String, Object?>();
    switch (call.method) {
      case 'index':
        indexed.add([
          for (final item in arguments['items']! as List)
            (item as Map).cast<String, Object?>(),
        ]);
      case 'remove':
        removed.add((arguments['ids']! as List).cast<int>());
      case 'reset':
        resets++;
    }
    return null;
  }

  List<int> get indexedIds => [
    for (final batch in indexed)
      for (final item in batch) item['id']! as int,
  ];

  void clear() {
    indexed.clear();
    removed.clear();
    resets = 0;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory sandbox;
  late NotesDatabase database;
  late NotesRepository repository;
  late _FakeSpotlight native;
  late L10n l10n;

  setUp(() async {
    // Boş notların başlığı kaydın tarihinden üretiliyor; uygulamada bu veriyi
    // `main()` yüklüyor.
    await initializeDateFormatting();
    sandbox = await Directory.systemTemp.createTemp('latermark_spotlight');
    database = NotesDatabase.forExecutor(NativeDatabase.memory());
    repository = NotesRepository(
      database: database,
      photos: await PhotoStore.openIn(sandbox),
    );
    native = _FakeSpotlight();
    l10n = await L10n.delegate.load(const Locale('en'));
  });

  tearDown(() async {
    await database.close();
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  SpotlightBridge newBridge() => SpotlightBridge(
    repository,
    channel: _FakeSpotlight.channel,
    stateDirectory: () async => sandbox,
    supported: true,
  )..l10n = l10n;

  Future<XFile> fakeCapture() async {
    final file = File(
      '${sandbox.path}/shot-${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(List<int>.filled(64, 7));
    return XFile(file.path);
  }

  Future<int> addNote(String body) async => repository.create(
    capture: await fakeCapture(),
    body: body,
    retention: const RetentionChoice.off(),
  );

  /// Köprü akışı dinliyor ve yayınlar sıraya giriyor: önce Drift'in yeni
  /// değeri yayması, sonra kuyruğun boşalması gerekiyor. Testin bir sonraki
  /// beklentisi ikisi de bitmeden kurulamaz.
  Future<void> settle(SpotlightBridge bridge) async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
      await bridge.settled;
    }
  }

  test('yeni kayıt indekse girer', () async {
    await addNote('Kombi garanti belgesi');
    final bridge = newBridge();
    await bridge.start();
    await settle(bridge);

    expect(native.indexed, hasLength(1));
    expect(native.indexed.single.single['title'], 'Kombi garanti belgesi');
    await bridge.dispose();
  });

  test('notu boş kayıt tarihiyle adlandırılır', () async {
    await addNote('');
    final bridge = newBridge();
    await bridge.start();
    await settle(bridge);

    expect(native.indexed.single.single['title'], isNotEmpty);
    await bridge.dispose();
  });

  test('OCR metni sonradan geldiğinde kayıt yeniden indekslenir', () async {
    final id = await addNote('Fiş');
    final bridge = newBridge();
    await bridge.start();
    await settle(bridge);
    native.clear();

    await repository.saveScan(id, 'TOPLAM 4521 TL');
    bridge.scanCompleted();
    await settle(bridge);

    expect(native.indexedIds, [id]);
    expect(native.indexed.single.single['text'], contains('4521'));
    await bridge.dispose();
  });

  test('dolu OCR metni değiştiğinde kayıt yeniden indekslenir', () async {
    final id = await addNote('Fiş');
    await repository.saveScan(id, 'ESKİ TOPLAM 100 TL');
    final bridge = newBridge();
    await bridge.start();
    await settle(bridge);
    native.clear();

    await repository.saveScan(id, 'YENİ TOPLAM 4521 TL');
    bridge.scanCompleted();
    await settle(bridge);

    expect(native.indexedIds, [id]);
    expect(native.indexed.single.single['text'], contains('4521'));
    await bridge.dispose();
  });

  test('düzenlenen notun başlığı indekste güncellenir', () async {
    final id = await addNote('Fiş');
    final bridge = newBridge();
    await bridge.start();
    await settle(bridge);
    native.clear();

    await repository.update(
      (await repository.noteById(id))!,
      body: 'Kombi fişi',
      remindAfterDays: 0,
    );
    await settle(bridge);

    expect(native.indexedIds, [id]);
    expect(native.indexed.single.single['title'], 'Kombi fişi');
    await bridge.dispose();
  });

  test('silinen kayıt indeksten kaldırılır', () async {
    final id = await addNote('Fiş');
    final bridge = newBridge();
    await bridge.start();
    await settle(bridge);
    native.clear();

    await repository.delete((await repository.noteById(id))!);
    await settle(bridge);

    expect(native.removed, [
      [id],
    ]);
    expect(native.indexed, isEmpty);
    await bridge.dispose();
  });

  test('hiçbir şey değişmediyse açılışta hiç iş yapılmaz', () async {
    // İmzalar diskte tutuluyor; ikinci açılış Spotlight'a hiç gitmemeli.
    // Gitseydi her açılış bütün arşivi yeniden indeksleyerek pil ve süre
    // yakardı.
    await addNote('Kombi garanti belgesi');
    final first = newBridge();
    await first.start();
    await settle(first);
    await first.dispose();
    expect(native.indexed, hasLength(1));
    native.clear();

    final second = newBridge();
    await second.start();
    await settle(second);

    expect(native.indexed, isEmpty);
    expect(native.removed, isEmpty);
    await second.dispose();
  });

  test('uygulama kapalıyken silinen kayıt açılışta indeksten düşer', () async {
    final id = await addNote('Fiş');
    final first = newBridge();
    await first.start();
    await settle(first);
    await first.dispose();
    native.clear();

    // Süresi dolan kayıtlar açılıştan önce, akış hiç yayın yapmadan
    // temizleniyor.
    await repository.delete((await repository.noteById(id))!);

    final second = newBridge();
    await second.start();
    await settle(second);

    expect(native.removed, [
      [id],
    ]);
    await second.dispose();
  });

  test('imza dosyası bozuksa her şey yeniden indekslenir', () async {
    await addNote('Fiş');
    await File('${sandbox.path}/spotlight_index.json').writeAsString('{{{');

    final bridge = newBridge();
    await bridge.start();
    await settle(bridge);

    expect(native.indexed, hasLength(1));
    expect(native.resets, 1);
    await bridge.dispose();
  });

  test('imzalar diske yazılır', () async {
    final id = await addNote('Fiş');
    final bridge = newBridge();
    await bridge.start();
    await settle(bridge);

    final state =
        jsonDecode(
              await File('${sandbox.path}/spotlight_index.json').readAsString(),
            )
            as Map<String, dynamic>;
    expect(state['version'], 2);
    expect(state['rebuilding'], isFalse);
    expect((state['items'] as Map<String, dynamic>).keys, ['$id']);
    await bridge.dispose();
  });

  group('imza', () {
    final createdAt = DateTime(2026, 8, 8, 9);

    test('bilinen girdiler için sabit bir değer üretir', () {
      // Değer diske yazılıp bir sonraki **açılışta** karşılaştırılıyor.
      // Hesap sürümden sürüme kayarsa ya her açılış bütün arşivi yeniden
      // indeksler ya da hiçbir değişikliği fark etmez. Bu beklenti,
      // hesabın kazara değiştirilmesine karşı kilit.
      expect(
        spotlightFingerprint(
          title: 'Kombi garanti belgesi',
          createdAt: createdAt,
          photoFingerprint: null,
          localeName: 'tr',
        ),
        '2618747846:${createdAt.millisecondsSinceEpoch}:-:',
      );
    });

    test('içerik, tarama durumu ve boş başlıkta dil imzayı değiştirir', () {
      String signature({
        String title = 'Fiş',
        String? photoFingerprint,
        String localeName = 'tr',
      }) => spotlightFingerprint(
        title: title,
        createdAt: createdAt,
        photoFingerprint: photoFingerprint,
        localeName: localeName,
      );

      expect(signature(), isNot(signature(title: 'Fatura')));
      expect(signature(), isNot(signature(photoFingerprint: 'a1b2c3d4')));
      // Notu olan kayıt dil değişince yeniden indekslenmez: başlığı zaten
      // kullanıcının kendi yazısı ve değişmiyor.
      expect(signature(), signature(localeName: 'en'));
      // Notu boş olanın başlığını tarih üretiyor, o da dile bağlı.
      expect(
        signature(title: ''),
        isNot(signature(title: '', localeName: 'en')),
      );
    });
  });

  test('desteklenmeyen platformda hiç çalışmaz', () async {
    await addNote('Fiş');
    final bridge = SpotlightBridge(
      repository,
      channel: _FakeSpotlight.channel,
      stateDirectory: () async => sandbox,
      supported: false,
    )..l10n = l10n;

    await bridge.start();
    await settle(bridge);

    expect(native.indexed, isEmpty);
    expect(File('${sandbox.path}/spotlight_index.json').existsSync(), isFalse);
    await bridge.dispose();
  });
}
