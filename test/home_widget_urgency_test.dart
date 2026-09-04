import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/features/home_widget/home_widget_bridge.dart';
import 'package:latermark/features/home_widget/widget_keys.dart';
import 'package:latermark/features/notes/data/notes_database.dart';
import 'package:latermark/features/notes/data/notes_repository.dart';
import 'package:latermark/features/notes/data/photo_store.dart';
import 'package:latermark/features/notes/domain/retention.dart';
import 'package:latermark/features/settings/data/settings_repository.dart';

/// Paylaşılan alanın yerine geçen kayıt defteri.
class _FakeStore {
  final values = <String, Object?>{};

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
    if (call.method == 'saveWidgetData') {
      values[arguments['id']! as String] = arguments['data'];
    }
    return true;
  }

  void dispose() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  }
}

/// Widget'ta duran kayıt **tazeliğe** değil **aciliyete** göre seçilir.
///
/// En son kayıt, kullanıcının hâlâ hatırladığı tek kayıttır; uygulamanın sözü
/// ise "yaz ve unut". Geri dönüşü olmayan tek olay kaydın silinmesi, ve onun
/// hatırlatma gibi kendi başına gelen bir uyarısı yok.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory sandbox;
  late NotesDatabase database;
  late NotesRepository repository;
  late _FakeStore store;
  HomeWidgetBridge? bridge;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('lm_widget_urgency');
    database = NotesDatabase.forExecutor(NativeDatabase.memory());
    repository = NotesRepository(
      database: database,
      photos: await PhotoStore.openIn(sandbox),
    );
    store = _FakeStore();
    // Özel saklama süresi Pro'ya kilitli; kilitliyken depo süreyi ücretsiz
    // karşılığına düşürüyor ve testin kurduğu aciliyet hiç oluşmuyor.
    await SettingsRepository(database).setProUnlocked(true);
  });

  tearDown(() async {
    await bridge?.dispose();
    store.dispose();
    await database.close();
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  Future<void> waitFor(String reason, bool Function() ready) async {
    for (var i = 0; i < 400; i++) {
      if (ready()) return;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('Beklenen duruma ulaşılamadı: $reason');
  }

  /// Sıralamayı belirsiz bırakmamak için ayrık damgalar.
  ///
  /// `created_at` saniye çözünürlüklü ve `watchNotes` ona göre sıralıyor; aynı
  /// saniyede kurulan iki kaydın sırası testten teste değişiyordu.
  late final DateTime base = DateTime.now();
  DateTime stamp(int secondsAgo) =>
      base.subtract(Duration(seconds: secondsAgo));

  Future<HomeWidgetBridge> startBridge() async {
    final value = HomeWidgetBridge(repository, supported: true)..pro = true;
    bridge = value;
    await value.start();
    return value;
  }

  test('yakında silinecek kayıt en son kaydın önüne geçiyor', () async {
    // Önce süresi yakın olan yazılıyor, sonra ondan **daha yeni** ama uzun
    // ömürlü bir kayıt. Tazelik ölçütü olsaydı ikincisi kazanırdı.
    final expiring = await repository.createText(
      body: 'Bugün gidiyor',
      retention: RetentionChoice.custom(90),
      createdAt: stamp(60),
    );
    await repository.createText(
      body: 'Daha yeni ama acelesi yok',
      retention: const RetentionChoice(Retention.oneWeek),
      createdAt: stamp(10),
    );

    await startBridge();
    await waitFor(
      'acil kayıt seçildi',
      () => store.values[WidgetKeys.noteId] == expiring,
    );
    expect(store.values[WidgetKeys.body], 'Bugün gidiyor');
  });

  test('ufkun ötesindeki kayıt öne çıkmıyor, en son kayda dönülüyor', () async {
    // Bir hafta sonra silinecek kayıt bugünün derdi değil. Onu öne çıkarmak
    // widget'ı kalıcı olarak aynı nota kilitler ve "yakında gidiyor" sözünü
    // değersizleştirirdi.
    await repository.createText(
      body: 'Haftaya gidiyor',
      retention: const RetentionChoice(Retention.oneWeek),
      createdAt: stamp(60),
    );
    final newest = await repository.createText(
      body: 'En son kayıt',
      retention: const RetentionChoice.off(),
      createdAt: stamp(10),
    );

    await startBridge();
    await waitFor(
      'en son kayda dönüldü',
      () => store.values[WidgetKeys.noteId] == newest,
    );
    expect(store.values[WidgetKeys.body], 'En son kayıt');
  });

  test('iki acil kayıttan en yakını kazanıyor', () async {
    // Yakın olan **daha eski**: tazelik ölçütü hâlâ ayakta olsaydı diğeri
    // kazanırdı, yani bu test o ihtimali de eliyor.
    final sooner = await repository.createText(
      body: 'Bir saat',
      retention: RetentionChoice.custom(60),
      createdAt: stamp(60),
    );
    await repository.createText(
      body: 'Beş saat',
      retention: RetentionChoice.custom(300),
      createdAt: stamp(10),
    );

    await startBridge();
    await waitFor(
      'en yakın kayıt seçildi',
      () => store.values[WidgetKeys.noteId] == sooner,
    );
  });

  test('süresiz kayıtlarda davranış değişmiyor', () async {
    await repository.createText(
      body: 'Eski',
      retention: const RetentionChoice.off(),
      createdAt: stamp(60),
    );
    final newest = await repository.createText(
      body: 'Yeni',
      retention: const RetentionChoice.off(),
      createdAt: stamp(10),
    );

    await startBridge();
    await waitFor(
      'en son kayıt',
      () => store.values[WidgetKeys.noteId] == newest,
    );
  });
}
