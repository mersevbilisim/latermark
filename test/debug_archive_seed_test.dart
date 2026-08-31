import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/features/notes/data/notes_database.dart';
import 'package:latermark/features/notes/data/notes_repository.dart';
import 'package:latermark/features/notes/data/photo_store.dart';
import 'package:latermark/features/notes/domain/retention.dart';
import 'package:latermark/features/settings/data/debug_archive_seed.dart';
import 'package:latermark/features/settings/data/settings_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory sandbox;
  late NotesDatabase database;
  late NotesRepository repository;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('lm_seed');
    database = NotesDatabase.forExecutor(NativeDatabase.memory());
    repository = NotesRepository(
      database: database,
      photos: await PhotoStore.openIn(sandbox),
    );
    // Tohumlayıcı geçici klasöre yazıyor; testte eklenti yok.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => sandbox.path,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    await database.close();
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  testWidgets('tohumlanan kayıtlar gerçek yoldan geçiyor', (tester) async {
    await tester.runAsync(() async {
      // Hatırlatma Pro'ya bağlı: depo hak kapalıyken seçimi düşürüyor.
      await SettingsRepository(database).setProUnlocked(true);

      // Kullanıcının kendi kaydı: silmenin ona dokunmadığını göreceğiz.
      final mine = File('${sandbox.path}/benim.png')
        ..writeAsBytesSync(Uint8List.fromList([1, 2, 3]));
      await repository.create(
        capture: XFile(mine.path),
        body: 'Kendi notum',
        retention: const RetentionChoice(Retention.off),
      );

      final progress = <int>[];
      await DebugArchiveSeed.fill(
        repository,
        count: 12,
        onProgress: (done, _) => progress.add(done),
      );

      final notes = await repository.watchNotes().first;
      final seeded =
          notes.where((n) => n.body.startsWith(DebugArchiveSeed.marker));

      expect(notes, hasLength(13));
      expect(seeded, hasLength(12));
      expect(progress.last, 12);

      // Her beşincisine hatırlatma: 0, 5, 10 → üç tane.
      expect(seeded.where((n) => n.remindAt != null), hasLength(3));

      // Her kaydın kendi dosyası var: görüntü önbelleği yolla anahtarlandığı
      // için ölçümün gerçek olması buna bağlı.
      final names = seeded.map((n) => n.imageName).toSet();
      expect(names, hasLength(12));
      for (final note in seeded) {
        expect(repository.imageOf(note).existsSync(), isTrue);
      }

      final bytes = repository.imageOf(seeded.first).lengthSync();
      // Testte native sıkıştırıcı yok; cihazda bu bayt JPEG'e iner.
      debugPrint('KARE ${(bytes / 1024).round()} KB '
          '(masaüstünde ham PNG; cihazda 2048/q88 JPEG olur)');

      // Kayıtlar geriye yayılıyor: yaş bölümleri oluşsun.
      final span = notes.first.createdAt.difference(notes.last.createdAt);
      expect(span.inDays, greaterThanOrEqualTo(7));

      // Temizlik yalnız tohumlananları alıyor.
      final removed = await DebugArchiveSeed.clear(repository);
      expect(removed, 12);

      final left = await repository.watchNotes().first;
      expect(left, hasLength(1));
      expect(left.single.body, 'Kendi notum');
    });
  });
}
