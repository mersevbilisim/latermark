import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/features/notes/data/notes_database.dart';
import 'package:latermark/features/notes/data/notes_repository.dart';
import 'package:latermark/features/notes/data/photo_store.dart';
import 'package:latermark/features/notes/domain/retention.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory sandbox;
  late NotesDatabase database;
  late NotesRepository repository;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('lm_original');
    database = NotesDatabase.forExecutor(NativeDatabase.memory());
    repository = NotesRepository(
      database: database,
      photos: await PhotoStore.openIn(sandbox),
    );
  });

  tearDown(() async {
    await database.close();
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  Future<XFile> capture(String name, {int bytes = 500000}) async {
    final file = File('${sandbox.path}/$name')
      ..writeAsBytesSync(List<int>.filled(bytes, 5));
    return XFile(file.path);
  }

  Future<Note> only() async => (await repository.watchNotes().first).single;

  /// Varsayılan her zaman kapalı. Kullanıcı istemediyse tek bir fazladan
  /// dosya bile yazılmamalı.
  test('varsayılanda orijinal saklanmıyor', () async {
    await repository.create(
      capture: await capture('a.jpg'),
      body: 'Fiş',
      retention: const RetentionChoice(Retention.off),
    );

    final note = await only();
    expect(note.originalName, isNull);
    expect(repository.originalOf(note), isNull);
    expect(NotesRepository.filesOf(note), [note.imageName]);
  });

  test('istendiğinde orijinal işlenmiş karenin yanına yazılıyor', () async {
    await repository.create(
      capture: await capture('b.jpg'),
      body: 'Anı',
      retention: const RetentionChoice(Retention.off),
      keepOriginal: true,
    );

    final note = await only();
    expect(note.originalName, isNotNull);
    // İşlenmiş kare **yerinde duruyor**; orijinal onun yerine geçmiyor.
    expect(repository.imageOf(note).existsSync(), isTrue);
    expect(repository.originalOf(note)!.existsSync(), isTrue);
    expect(note.originalName, isNot(note.imageName));
    expect(NotesRepository.filesOf(note), hasLength(2));

    // Orijinal dokunulmamış: küçültülmemiş, kaynakla aynı boyutta.
    expect(repository.originalOf(note)!.lengthSync(), 500000);
  });

  test('not silinince orijinal de siliniyor', () async {
    await repository.create(
      capture: await capture('c.jpg'),
      body: 'Anı',
      retention: const RetentionChoice(Retention.off),
      keepOriginal: true,
    );

    final note = await only();
    final processed = repository.imageOf(note);
    final original = repository.originalOf(note)!;

    await repository.delete(note);

    expect(processed.existsSync(), isFalse);
    expect(original.existsSync(), isFalse);
  });

  test('toplu silme de orijinalleri bırakmıyor', () async {
    for (final name in ['d.jpg', 'e.jpg']) {
      await repository.create(
        capture: await capture(name),
        body: name,
        retention: const RetentionChoice(Retention.off),
        keepOriginal: true,
      );
    }

    final notes = await repository.watchNotes().first;
    final files = [
      for (final note in notes) ...[
        repository.imageOf(note),
        repository.originalOf(note)!,
      ],
    ];
    expect(files, hasLength(4));

    await repository.deleteAll(notes);

    for (final file in files) {
      expect(file.existsSync(), isFalse, reason: file.path);
    }
  });

  /// Yetim süpürme `imageName` sayıyordu; orijinali bilmezse onu sahipsiz
  /// sanıp kullanıcının sakladığı kareyi silerdi.
  test('süpürme kayıtlı orijinali silmiyor', () async {
    await repository.create(
      capture: await capture('f.jpg'),
      body: 'Anı',
      retention: const RetentionChoice(Retention.off),
      keepOriginal: true,
    );

    final note = await only();
    final original = repository.originalOf(note)!;
    // Süpürme yalnız yaşça eski dosyaları alıyor.
    final old = DateTime.now().subtract(const Duration(hours: 1));
    repository.imageOf(note).setLastModifiedSync(old);
    original.setLastModifiedSync(old);

    await repository.sweepOrphanFiles();

    expect(repository.imageOf(note).existsSync(), isTrue);
    expect(original.existsSync(), isTrue);
  });

  test('süresi dolan kayıt orijinalini de götürüyor', () async {
    await repository.create(
      capture: await capture('g.jpg'),
      body: 'Anı',
      retention: const RetentionChoice(Retention.threeDays),
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
      keepOriginal: true,
    );

    final note = await only();
    final original = repository.originalOf(note)!;
    expect(original.existsSync(), isTrue);

    expect(await repository.purgeExpired(reminderPermissionGranted: false), 1);
    expect(original.existsSync(), isFalse);
  });

  /// Küçük yüzeyler küçük kopyayı okuyor, büyük olanlar işlenmiş kareyi.
  /// Orijinal yalnızca detay, tam ekran ve paylaşımda.
  test('her yüzey kendi boyuna uygun dosyayı okuyor', () async {
    await repository.create(
      capture: await capture('h.jpg'),
      body: 'Anı',
      retention: const RetentionChoice(Retention.off),
      keepOriginal: true,
    );

    final note = await only();
    final processed = repository.imageOf(note).path;
    final original = repository.originalOf(note)!.path;

    // Detay, tam ekran ve paylaşım: orijinal.
    expect(repository.fullImageOf(note).path, original);
    // Izgara, arama, paywall, widget: küçük kopya yoksa işlenmiş kare —
    // yükseltmeden gelen kullanıcı da eksiksiz görüyor.
    expect(repository.gridImageOf(note).path, processed);
    // Orijinal hiçbir küçük yüzeye sızmıyor.
    expect(repository.gridImageOf(note).path, isNot(original));
    expect(repository.imageOf(note).path, isNot(original));
  });

  /// Orijinali olmayan kayıtta hiçbir şey değişmiyor: yükseltmeden gelen
  /// bütün arşiv bu durumda.
  test('orijinalsiz kayıtta bütün yüzeyler işlenmiş kareyi okuyor', () async {
    await repository.create(
      capture: await capture('i.jpg'),
      body: 'Fiş',
      retention: const RetentionChoice(Retention.off),
    );

    final note = await only();
    final processed = repository.imageOf(note).path;
    expect(repository.fullImageOf(note).path, processed);
    expect(repository.gridImageOf(note).path, processed);
  });

  /// Etiket yalnızca ekranda yaşıyor. Kareye basılsaydı paylaşılan ve dışa
  /// aktarılan dosyaya da işlenmiş olurdu — geri alınamaz biçimde.
  test('paylaşılan dosya karenin kendisi, üstüne hiçbir şey basılmıyor',
      () async {
    final source = File('${sandbox.path}/j.jpg')
      ..writeAsBytesSync(List<int>.filled(700000, 9));
    await repository.create(
      capture: XFile(source.path),
      body: 'Anı',
      retention: const RetentionChoice(Retention.off),
      keepOriginal: true,
    );

    final note = await only();
    final shared = repository.fullImageOf(note);

    // Paylaşıma giden dosya, kaydedilen orijinalin **birebir aynısı**.
    expect(shared.path, repository.originalOf(note)!.path);
    expect(shared.lengthSync(), 700000);
    expect(shared.readAsBytesSync(), source.readAsBytesSync());
  });
}
