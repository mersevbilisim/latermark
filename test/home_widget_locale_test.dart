import 'dart:io';
import 'dart:ui';

import 'package:cross_file/cross_file.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/core/theme/accent_tone.dart';
import 'package:latermark/core/theme/app_accent.dart';
import 'package:latermark/features/home_widget/home_widget_bridge.dart';
import 'package:latermark/features/home_widget/widget_keys.dart';
import 'package:latermark/features/notes/data/notes_database.dart';
import 'package:latermark/features/notes/data/notes_repository.dart';
import 'package:latermark/features/notes/data/photo_store.dart';
import 'package:latermark/features/notes/domain/retention.dart';

/// Paylaşılan alanın yerine geçen kayıt defteri.
///
/// `home_widget` eklentisi tek bir kanaldan geçiyor; native depoyu burada
/// taklit edip köprünün gerçekten ne yazdığını okuyoruz.
class _FakeStore {
  final values = <String, Object?>{};
  final refreshed = <String>[];

  static const channel = MethodChannel('home_widget');

  _FakeStore() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, _handle);
  }

  Future<Object?> _handle(MethodCall call) async {
    final arguments = switch (call.arguments) {
      final Map value => value.cast<String, Object?>(),
      _ => <String, Object?>{},
    };
    switch (call.method) {
      case 'saveWidgetData':
        values[arguments['id']! as String] = arguments['data'];
        return true;
      case 'updateWidget':
        refreshed.add((arguments['ios'] ?? arguments['android'] ?? '') as String);
        return true;
    }
    return null;
  }

  void dispose() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory sandbox;
  late NotesDatabase database;
  late NotesRepository repository;
  late _FakeStore store;
  late HomeWidgetBridge bridge;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('latermark_widget_locale');
    database = NotesDatabase.forExecutor(NativeDatabase.memory());
    repository = NotesRepository(
      database: database,
      photos: await PhotoStore.openIn(sandbox),
    );
    store = _FakeStore();
    bridge = HomeWidgetBridge(repository, supported: true);
  });

  tearDown(() async {
    await bridge.dispose();
    store.dispose();
    await database.close();
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  Future<XFile> fakeCapture() async {
    final file = File('${sandbox.path}/shot.jpg');
    await file.writeAsBytes(List<int>.filled(64, 7));
    return XFile(file.path);
  }

  /// Beklenen durum oluşana kadar olay döngüsünü çevirir.
  ///
  /// Sabit sayıda tur yetmiyor: hem Drift'in not akışı hem köprünün kendi
  /// yayın kuyruğu asenkron ve yüklü bir makinede tam sayısı değişiyor.
  Future<void> waitFor(String reason, bool Function() ready) async {
    for (var i = 0; i < 400; i++) {
      if (ready()) return;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('Beklenen duruma ulaşılamadı: $reason');
  }

  test('seçilen dil paylaşılan alana yazılır', () async {
    bridge.pro = true;
    bridge.locale = const Locale('tr');
    await bridge.start();
    await repository.create(
      capture: await fakeCapture(),
      body: 'Muhasebeye göndereceğim',
      retention: RetentionChoice(Retention.off),
    );
    await waitFor('tr yayını', () => store.values[WidgetKeys.locale] == 'tr');
  });

  test('ülke kodu taşıyan dil BCP-47 etiketi olarak gider', () async {
    bridge.pro = true;
    bridge.locale = const Locale('pt', 'BR');
    await bridge.start();
    await repository.create(
      capture: await fakeCapture(),
      body: 'Nota',
      retention: RetentionChoice(Retention.off),
    );
    await waitFor(
      'pt-BR yayını',
      () => store.values[WidgetKeys.locale] == 'pt-BR',
    );
  });

  test('not değişmeden dil değişince yayın yine yapılır', () async {
    bridge.pro = true;
    bridge.locale = const Locale('en');
    await bridge.start();
    await repository.create(
      capture: await fakeCapture(),
      body: 'Send this to Accounting',
      retention: RetentionChoice(Retention.off),
    );
    await waitFor('en yayını', () => store.values[WidgetKeys.locale] == 'en');

    final before = store.refreshed.length;
    bridge.locale = const Locale('tr');

    // İmza engeli dili de kapsamalı: aksi hâlde ayarlardan dili değiştiren
    // kullanıcının widget'ı eski dilde donup kalıyordu.
    await waitFor(
      'dil değişiminden sonra yeniden yayın',
      () => store.values[WidgetKeys.locale] == 'tr',
    );
    expect(store.refreshed.length, greaterThan(before));
  });

  test('kilitli yayında da dil gider', () async {
    bridge.pro = false;
    bridge.locale = const Locale('de');
    await bridge.start();
    await repository.create(
      capture: await fakeCapture(),
      body: 'Notiz',
      retention: RetentionChoice(Retention.off),
    );
    // Kilit ekranındaki "Latermark Pro" alt yazısı da kullanıcının dilinde
    // olmalı; hak kapalıyken içerik temizlenir ama dil temizlenmez.
    await waitFor('de yayını', () => store.values[WidgetKeys.locale] == 'de');
    expect(store.values[WidgetKeys.hasNote], isFalse);
  });

  test('özel renk değişince native widget yeniden boyanıyor', () async {
    bridge.pro = true;
    bridge.locale = const Locale('tr');
    bridge.accent = AppAccent.orange.onPhotoFor();
    await bridge.start();
    await repository.create(
      capture: await fakeCapture(),
      body: 'Not',
      retention: RetentionChoice(Retention.off),
    );
    await waitFor(
      'turuncu yayını',
      () => store.values[WidgetKeys.accent] == 'ffff7a55',
    );

    // Köprüye çözülmüş renk geçiyor: tonu native tarafın yeniden hesaplaması,
    // aynı formülü iki dilde tutmak olurdu.
    final custom = AccentTone.onPhoto(214);
    bridge.accent = custom;

    // Not hiç değişmedi; yayını tetikleyen tek şey rengin kendisi.
    await waitFor(
      'özel renk yayını',
      () =>
          store.values[WidgetKeys.accent] ==
          custom.toARGB32().toRadixString(16).padLeft(8, '0'),
    );
  });

  test('dil bilinmeden yayın yapılırsa etiket boş kalır', () async {
    bridge.pro = true;
    bridge.accent = AppAccent.orange.onPhotoFor();
    await bridge.start();
    await repository.create(
      capture: await fakeCapture(),
      body: 'Not',
      retention: RetentionChoice(Retention.off),
    );
    // Boş etiket native tarafa "sistem dilini kendin çöz" demek.
    await waitFor(
      'dilsiz yayın',
      () => store.values.containsKey(WidgetKeys.locale),
    );
    expect(store.values[WidgetKeys.locale], '');
  });
}
