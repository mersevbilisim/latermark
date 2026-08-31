import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/features/notes/data/notes_database.dart';
import 'package:latermark/features/notes/data/notes_repository.dart';
import 'package:latermark/features/notes/data/photo_store.dart';
import 'package:latermark/features/notes/data/search_text.dart';
import 'package:latermark/features/notes/domain/note_reminder.dart';
import 'package:latermark/features/notes/domain/retention.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

void main() {
  late Directory sandbox;
  late NotesDatabase database;
  late PhotoStore photos;
  late NotesRepository repository;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('latermark_search_test');
    database = NotesDatabase.forExecutor(NativeDatabase.memory());
    photos = await PhotoStore.openIn(sandbox);
    repository = NotesRepository(database: database, photos: photos);
  });

  tearDown(() async {
    await database.close();
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  Future<XFile> fakeCapture() async {
    final file = File(
      '${sandbox.path}/shot-${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(List<int>.filled(64, 7));
    return XFile(file.path);
  }

  Future<int> addNote(String body, {String? scan}) async {
    final id = await repository.create(
      capture: await fakeCapture(),
      body: body,
      retention: RetentionChoice(Retention.off),
    );
    if (scan != null) await repository.saveScan(id, scan);
    return id;
  }

  group('katlama', () {
    test('Türkçe büyük/küçük ve diakritik farkları silinir', () {
      expect(SearchText.fold('İSTANBUL'), 'istanbul');
      expect(SearchText.fold('Işık'), 'isik');
      expect(SearchText.fold('ÇĞÖŞÜ'), 'cgosu');
    });

    test('diğer dillerin aksanlı büyük harfleri de küçülür', () {
      // Uygulama sekiz dilde; `É` gibi harfler eski hâlde de küçülüyordu,
      // hızlandırılmış sürüm bunu kaybetmemeli.
      expect(SearchText.fold('ÉCOLE'), 'école');
      expect(SearchText.fold('MÜNCHEN'), 'munchen');
    });
  });

  group('sınırlama', () {
    test('boşluklar daraltılır', () {
      // iOS satırları ham hâlde birleştiriyordu, Android daraltıyordu; aynı
      // fotoğraf iki telefonda aynı indekslenmeli.
      expect(SearchText.normalize('  fatura \n\n  no   42 '), 'fatura no 42');
    });

    test('uzun metin sınırda ve kelime sınırında kesilir', () {
      final long = List.filled(4000, 'kelime').join(' ');
      final capped = SearchText.normalize(long);

      expect(capped.length, lessThanOrEqualTo(SearchText.maxIndexedChars));
      expect(capped.length, greaterThan(SearchText.maxIndexedChars - 64));
      // Yarım kelimeyle bitmemeli.
      expect(capped.endsWith('kelime'), isTrue);
    });

    test('boşluksuz gürültü olduğu yerden kesilir', () {
      final blob = 'x' * (SearchText.maxIndexedChars * 2);
      expect(SearchText.normalize(blob).length, SearchText.maxIndexedChars);
    });
  });

  group('arama', () {
    test('not metninde geçen sorgu bulunur', () async {
      final id = await addNote('Kombi bakımı');
      await addNote('Araba plakası');

      final hits = await repository.search('kombi');
      expect(hits.ids, {id});
      expect(hits.photoOnly, isEmpty);
    });

    test('yalnızca karedeki yazıda geçen sorgu da bulunur', () async {
      final id = await addNote('Fiş', scan: 'ARAÇ MUAYENE ÜCRETİ 4521 TL');
      await addNote('Başka');

      final hits = await repository.search('4521');
      expect(hits.ids, {id});
      // Eşleşmenin sebebi notta görünmüyor; arayüz bunu işaretleyebilsin.
      expect(hits.photoOnly, {id});
    });

    test('sorgu Türkçe katlamayla eşleşir', () async {
      final id = await addNote('', scan: 'ISITMA SİSTEMİ');

      expect((await repository.search('ısıtma')).ids, {id});
      expect((await repository.search('sistemi')).ids, {id});
      expect((await repository.search('SİSTEMİ')).ids, {id});
    });

    test('A4 sayfasının ortasındaki metin de bulunur', () async {
      // Sınırın niye cömert olduğunun testi: aranan şey (tutar, fiş no)
      // belgenin başında değil ortasında olur. Yoğun bir A4 ~3.000 karakter;
      // aşağıdaki sayfa onu taklit ediyor.
      final page = [
        'MERSEV BILISIM LTD',
        List.filled(80, 'satır dolgu metni').join(' '),
        'TOPLAM 1.284,50 TL',
        List.filled(80, 'devam eden metin').join(' '),
      ].join(' ');
      expect(page.length, greaterThan(2500));
      expect(page.length, lessThan(SearchText.maxIndexedChars));

      final id = await addNote('Fatura', scan: page);
      expect((await repository.search('1.284,50')).ids, {id});
    });

    test('sınırın ötesindeki metin indekslenmez', () async {
      // Ödünün dürüst kaydı: bir gazete sayfası kadar yazı gelirse kuyruğun
      // sonu düşer. Gerçek bir belgede bu bölgeye girilmiyor.
      final id = await addNote(
        'çok uzun belge',
        scan:
            '${List.filled(2000, 'dolgu').join(' ')} SONDAKIKA '
            '${'x' * SearchText.maxIndexedChars}',
      );

      expect((await repository.search('dolgu')).ids, {id});
      expect((await repository.search('sondakika')).ids, isEmpty);
    });

    test('joker karakterler düz metin sayılır', () async {
      await addNote('sıradan not');
      final id = await addNote('%20 indirim');

      // Kaçış olmasa `%` deseni her kaydı döndürürdü.
      final hits = await repository.search('%20');
      expect(hits.ids, {id});
      expect((await repository.search('_')).ids, isEmpty);
    });

    test('boş sorgu süzmez', () async {
      await addNote('bir şey');
      final hits = await repository.search('   ');
      expect(hits.filtering, isFalse);
      expect(hits.contains(1), isTrue);
    });

    test('düzenlenen not eski metniyle bulunmaz', () async {
      final id = await addNote('ilk hâli');
      final note = (await repository.watchNotes().first).single;

      await repository.update(
        note,
        body: 'ikinci hâli',
        reminder: const ReminderChoice.off(),
      );

      expect((await repository.search('ilk')).ids, isEmpty);
      expect((await repository.search('ikinci')).ids, {id});
    });

    test('silinen notun indeks satırı da gider', () async {
      await addNote('gidecek', scan: 'GIDECEK BELGE');
      final note = (await repository.watchNotes().first).single;

      await repository.delete(note);

      expect((await repository.search('gidecek')).ids, isEmpty);
      final left = await database.select(database.noteSearch).get();
      expect(left, isEmpty);
    });
  });

  group('tarama kuyruğu', () {
    test('taranmamış kayıt sırada, taranan sırada değil', () async {
      final id = await addNote('bekleyen');
      expect((await repository.unscanned()).map((n) => n.id), [id]);

      await repository.saveScan(id, 'okundu');
      expect(await repository.unscanned(), isEmpty);
    });

    test('yazısız kare tarandı sayılır', () async {
      final id = await addNote('boş kare');
      // Boş dize "okundu, yazı yok" demek — tekrar denenmemeli.
      await repository.saveScan(id, '');
      expect(await repository.unscanned(), isEmpty);
    });

    test('okunamayan kare deneme hakkı bitince kuyruktan düşer', () async {
      final id = await addNote('bozuk kare');

      for (var i = 0; i < NotesRepository.maxScanAttempts; i++) {
        expect(
          (await repository.unscanned()).map((n) => n.id),
          [id],
          reason: '${i + 1}. denemeden önce hâlâ sırada olmalı',
        );
        await repository.saveScan(id, null);
      }

      expect(await repository.unscanned(), isEmpty);
    });

    test('tarama not akışını yeniden yaymaz', () async {
      // Bu testin koruduğu şey mimarinin kendisi: OCR sonucu `notes`
      // tablosuna yazılsaydı her taranan kare tüm listeyi baştan kurdururdu.
      final id = await addNote('kayıt');

      var emissions = 0;
      final sub = repository.watchNotes().listen((_) => emissions++);
      addTearDown(sub.cancel);
      await pumpEventQueue();
      final baseline = emissions;

      await repository.saveScan(id, 'sayfa dolusu yazı');
      await pumpEventQueue();

      expect(emissions, baseline);
    });

    test('indeks satırı kayıpsa tarama onu tamamlar', () async {
      final id = await addNote('yetim');
      await database.customStatement(
        'DELETE FROM note_search WHERE note_id = ?',
        [id],
      );

      await repository.saveScan(id, 'ONARILDI');

      // Hem kare yazısı hem not metni yerine gelmeli.
      expect((await repository.search('onarildi')).ids, {id});
      expect((await repository.search('yetim')).ids, {id});
    });
  });

  group('göç', () {
    test('v6 OCR içeriği v7 fingerprint sütununa taşınır', () async {
      final path = '${sandbox.path}/v6.sqlite';

      // Önce gerçek güncel şemayı üretip yalnız v7 sütununu geri alıyoruz.
      // Böylece fixture, artık kullanılmayan `not_app.sqlite` şemasını değil
      // uygulamanın gerçekten yükselteceği latermark_db v6'yı temsil eder.
      final seed = NotesDatabase.forExecutor(NativeDatabase(File(path)));
      await seed.select(seed.notes).get();
      await seed.close();

      final v6 = raw.sqlite3.open(path);
      // v7 sütununu ve v8'in hatırlatma şeklini geri alıyoruz: o sürümde
      // hatırlatma "çıpa + kaç gün sonra" olarak duruyordu.
      v6.execute(
        'ALTER TABLE notes DROP COLUMN original_name; '
        'ALTER TABLE settings DROP COLUMN share_signature; '
        'ALTER TABLE note_search DROP COLUMN photo_fingerprint; '
        'ALTER TABLE notes DROP COLUMN remind_at; '
        'ALTER TABLE notes RENAME COLUMN remind_every_days '
        'TO remind_after_days; '
        'ALTER TABLE notes ADD COLUMN reminder_anchor_at INTEGER NULL; '
        'ALTER TABLE notes ADD COLUMN remind_repeats '
        'INTEGER NOT NULL DEFAULT 0; '
        'PRAGMA user_version = 6;',
      );
      v6.execute(
        'INSERT INTO notes (image_name, body, created_at) VALUES (?, ?, ?)',
        ['a.jpg', 'Fiş', 1754000000],
      );
      v6.execute(
        'INSERT INTO note_search '
        '(note_id, body_folded, photo_folded, attempts) '
        'VALUES (?, ?, ?, ?)',
        [1, 'fis', 'muayene ucreti 4521 tl', 0],
      );
      v6.close();

      final migrated = NotesDatabase.forExecutor(NativeDatabase(File(path)));
      addTearDown(migrated.close);

      final row = await migrated.select(migrated.noteSearch).getSingle();
      expect(
        row.photoFingerprint,
        SearchText.fingerprint('muayene ucreti 4521 tl'),
      );
    });
  });

  test('yeni kaydın indeks satırı notla birlikte doğar', () async {
    final id = await addNote('doğuştan indeksli');
    final rows = await database.select(database.noteSearch).get();

    expect(rows, hasLength(1));
    expect(rows.single.noteId, id);
    expect(rows.single.bodyFolded, 'dogustan indeksli');
    // Henüz taranmadı.
    expect(rows.single.photoFolded, isNull);
    expect(rows.single.attempts, 0);
  });

  test('kaydedilen kare yazısı sınırlanır', () async {
    final id = await addNote('uzun belge');
    await repository.saveScan(id, List.filled(4000, 'kelime').join(' '));

    final row = await (database.select(
      database.noteSearch,
    )..where((t) => t.noteId.equals(id))).getSingle();

    expect(
      row.photoFolded!.length,
      lessThanOrEqualTo(SearchText.maxIndexedChars),
    );
  });
}
