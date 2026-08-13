import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/features/notes/data/photo_store.dart';

void main() {
  late Directory sandbox;
  late PhotoStore store;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('latermark_photo_restore');
    store = await PhotoStore.openIn(sandbox);
    await store.fileFor('old.jpg').writeAsBytes([1, 2, 3]);
  });

  tearDown(() async {
    if (sandbox.existsSync()) await sandbox.delete(recursive: true);
  });

  test('DB işlemi düşerse eski fotoğraf klasörü geri alınır', () async {
    final staging = Directory('${sandbox.path}/staging')..createSync();
    await File('${staging.path}/new.jpg').writeAsBytes([7, 8, 9]);

    final replacement = await store.beginReplaceAllFrom(staging);
    expect(store.fileFor('new.jpg').readAsBytesSync(), [7, 8, 9]);
    expect(store.fileFor('old.jpg').existsSync(), isFalse);

    await replacement.rollback();

    expect(store.fileFor('old.jpg').readAsBytesSync(), [1, 2, 3]);
    expect(store.fileFor('new.jpg').existsSync(), isFalse);
  });

  test('DB işlemi başarıyla biterse yalnız yeni fotoğraflar kalır', () async {
    final staging = Directory('${sandbox.path}/staging')..createSync();
    await File('${staging.path}/new.jpg').writeAsBytes([7, 8, 9]);

    final replacement = await store.beginReplaceAllFrom(staging);
    await replacement.commit();

    expect(store.fileFor('new.jpg').readAsBytesSync(), [7, 8, 9]);
    expect(store.fileFor('old.jpg').existsSync(), isFalse);
  });
}
