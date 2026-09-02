import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/features/notes/presentation/import/shared_import.dart';

/// Siri/Kestirmeler tesliminin Dart tarafındaki sınırı.
///
/// Sözleşmenin tamamı `ios/Shared/SharedImportStore.swift` ile paylaşılıyor;
/// buradaki testler o JSON'un karşılığını doğruluyor.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('latermark/shared_import');
  final calls = <MethodCall>[];
  Map<String, Object?>? pending;

  setUp(() {
    calls.clear();
    pending = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'takePendingSharedImport' => pending,
            'completeSharedImport' => true,
            'cancelQueuedReminder' => true,
            _ => null,
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('metin teslimi karesiz çözülür ve mutlak anı taşır', () async {
    pending = <String, Object?>{
      'id': '9f2c0f4e-0000-4000-8000-000000000001',
      'kind': 'text',
      'imageName': '',
      'path': '',
      'initialText': 'Akşamki işi hatırlat',
      'createdAtMilliseconds': 1756704000000,
      'saveImmediately': true,
      'remindAfterDays': 0,
      'remindAtMilliseconds': 1756742400000,
    };

    final shared = await SharedImportBridge.takePending();

    expect(shared, isNotNull);
    expect(shared!.isText, isTrue);
    expect(shared.image, isNull);
    expect(shared.initialText, 'Akşamki işi hatırlat');
    expect(
      shared.createdAt,
      DateTime.fromMillisecondsSinceEpoch(1756704000000),
    );
    // Gün sayısına çevrilmiyor: "yarın 9'da" diyen birinin saati kaybolurdu.
    expect(shared.remindAt, DateTime.fromMillisecondsSinceEpoch(1756742400000));
  });

  test('hatırlatmasız metin teslimi de geçerli', () async {
    pending = <String, Object?>{
      'id': '9f2c0f4e-0000-4000-8000-000000000002',
      'kind': 'text',
      'imageName': '',
      'path': '',
      'initialText': 'Sadece not',
      'createdAtMilliseconds': 1756704000000,
      'saveImmediately': true,
      'remindAfterDays': 0,
      'remindAtMilliseconds': null,
    };

    final shared = await SharedImportBridge.takePending();

    expect(shared!.isText, isTrue);
    expect(shared.remindAt, isNull);
  });

  test('kind alanı olmayan eski teslim fotoğraf sayılır', () async {
    // Yayındaki Share Extension `kind` yazmıyor; güncellemede kuyrukta
    // bekleyen bir kare kaybolmamalı.
    pending = <String, Object?>{
      'id': '9f2c0f4e-0000-4000-8000-000000000003',
      'path': '/tmp/frame.jpg',
      'initialText': '',
      'createdAtMilliseconds': 1756704000000,
      'saveImmediately': true,
      'remindAfterDays': 3,
    };

    final shared = await SharedImportBridge.takePending();

    expect(shared!.isText, isFalse);
    expect(shared.image!.path, '/tmp/frame.jpg');
    expect(shared.remindAfterDays, 3);
    expect(shared.remindAt, isNull);
  });

  test('dosyası olmayan fotoğraf teslimi yok sayılır', () async {
    pending = <String, Object?>{
      'id': '9f2c0f4e-0000-4000-8000-000000000004',
      'kind': 'photo',
      'path': '',
      'initialText': '',
      'createdAtMilliseconds': 1756704000000,
      'saveImmediately': true,
      'remindAfterDays': 0,
    };

    expect(await SharedImportBridge.takePending(), isNull);
  });

  test('geçici alarm kimliğiyle iptal ediliyor', () async {
    await SharedImportBridge.cancelQueuedReminder('9f2c');

    expect(calls.single.method, 'cancelQueuedReminder');
    expect(calls.single.arguments, {'id': '9f2c'});
  });

  test('ayna Pro, hatırlatma tercihi ve saklama süresini birlikte gönderir',
      () async {
    await SharedImportBridge.setShareMirror(
      proUnlocked: true,
      reminderEnabled: true,
      // Sıfır "süresiz sakla"; uzantı bunu "değer yok" ile karıştırmamalı.
      retentionMinutes: 0,
    );

    expect(calls.single.method, 'setShareMirror');
    expect(calls.single.arguments, {
      'unlocked': true,
      'reminderEnabled': true,
      'retentionMinutes': 0,
    });
  });
}
