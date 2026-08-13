import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/features/review/review_prompt_service.dart';

void main() {
  late Directory sandbox;
  late DateTime now;
  late String version;
  late _FakeRequester requester;
  late ReviewPromptService service;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('latermark_review');
    now = DateTime(2026, 1, 10, 12);
    version = '1.0.0';
    requester = _FakeRequester();
    service = ReviewPromptService(
      requester: requester,
      stateFile: () async => File('${sandbox.path}/review.json'),
      appVersion: () async => version,
      now: () => now,
      pause: (_) async {},
      isForeground: () => true,
    );
  });

  tearDown(() async {
    service.dispose();
    if (sandbox.existsSync()) await sandbox.delete(recursive: true);
  });

  test('ilk gün üç not kaydetmek kullanıcıyı hemen bölmez', () async {
    await service.recordSuccessfulSave();
    await service.recordSuccessfulSave();
    await service.recordSuccessfulSave();

    expect(requester.requests, 0);
  });

  test(
    'üçüncü başarılı not ikinci kullanım günündeyse native istek gelir',
    () async {
      await service.recordSuccessfulSave();
      await service.recordSuccessfulSave();
      now = DateTime(2026, 1, 11, 12);

      await service.recordSuccessfulSave();

      expect(requester.requests, 1);
    },
  );

  test('kapatılmış olabilecek istek aynı sürümde tekrar kovalanmaz', () async {
    await service.recordSuccessfulSave();
    await service.recordSuccessfulSave();
    now = DateTime(2026, 1, 11, 12);
    await service.recordSuccessfulSave();
    expect(requester.requests, 1);

    now = DateTime(2026, 8, 1, 12);
    await service.recordSuccessfulSave();

    expect(requester.requests, 1);
  });

  test('yeni sürüm üç günlük sakinleşme süresine uyar', () async {
    await service.recordSuccessfulSave();
    await service.recordSuccessfulSave();
    now = DateTime(2026, 1, 11, 12);
    await service.recordSuccessfulSave();
    expect(requester.requests, 1);

    version = '1.1.0';
    now = DateTime(2026, 1, 13, 12); // İki gün sonra.
    await service.recordSuccessfulSave();
    expect(requester.requests, 1);

    now = DateTime(2026, 1, 14, 12); // Üç gün sonra.
    await service.recordSuccessfulSave();
    expect(requester.requests, 2);
  });

  test('mağaza yüzeyi yoksa deneme hakkı tüketilmez', () async {
    requester.available = false;
    await service.recordSuccessfulSave();
    await service.recordSuccessfulSave();
    now = DateTime(2026, 1, 11, 12);
    await service.recordSuccessfulSave();
    expect(requester.requests, 0);

    requester.available = true;
    await service.recordSuccessfulSave();
    expect(requester.requests, 1);
  });

  test('uygulama arka plandaysa doğal an sonraki kayda bırakılır', () async {
    var foreground = false;
    service.dispose();
    service = ReviewPromptService(
      requester: requester,
      stateFile: () async => File('${sandbox.path}/review.json'),
      appVersion: () async => version,
      now: () => now,
      pause: (_) async {},
      isForeground: () => foreground,
    );

    await service.recordSuccessfulSave();
    await service.recordSuccessfulSave();
    now = DateTime(2026, 1, 11, 12);
    await service.recordSuccessfulSave();
    expect(requester.requests, 0);

    foreground = true;
    await service.recordSuccessfulSave();
    expect(requester.requests, 1);
  });
}

final class _FakeRequester implements ReviewRequester {
  bool available = true;
  int requests = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> requestReview() async => requests++;
}
