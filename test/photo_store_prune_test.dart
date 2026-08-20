import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/features/notes/data/photo_store.dart';

void main() {
  test('taze kaydedilen kare, eski listeyle koşan süpürmede hayatta kalmalı', () async {
    final sandbox = Directory.systemTemp.createTempSync('lm_prune');
    addTearDown(() => sandbox.deleteSync(recursive: true));
    final store = await PhotoStore.openIn(sandbox);

    // Açılış süpürmesi isim listesini alır...
    final snapshot = <String>{'eski.jpg'};
    final old = store.fileFor('eski.jpg')..writeAsBytesSync(<int>[1]);
    expect(old.existsSync(), isTrue);

    // ...tam o sırada kullanıcı yeni bir kare kaydeder. Dosya diskte, satırı
    // henüz yazılmadı: create() fotoğrafı transaction'dan önce yazıyor.
    final fresh = store.fileFor('yeni.jpg')..writeAsBytesSync(<int>[2]);

    // Süpürme eski listeyle yürür.
    await store.pruneOrphans(snapshot);

    expect(old.existsSync(), isTrue, reason: 'kayıtlı kare durmalı');
    expect(
      fresh.existsSync(),
      isTrue,
      reason: 'satırı yazılmak üzere olan taze kare silinmemeli',
    );
  });

  test('gerçek yetim yine de toplanır', () async {
    final sandbox = Directory.systemTemp.createTempSync('lm_prune2');
    addTearDown(() => sandbox.deleteSync(recursive: true));
    final store = await PhotoStore.openIn(sandbox);

    final orphan = store.fileFor('yetim.jpg')..writeAsBytesSync(<int>[3]);
    orphan.setLastModifiedSync(
      DateTime.now().subtract(const Duration(hours: 2)),
    );

    await store.pruneOrphans(<String>{});
    expect(orphan.existsSync(), isFalse);
  });
}
