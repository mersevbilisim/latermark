import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/features/notes/data/image_compressor.dart';
import 'package:latermark/features/notes/data/photo_store.dart';

/// Yerel sıkıştırıcıyı taklit eder: hedef kenarın altına inen kareyi
/// "küçültüldü" sayar ve dosyayı gerçekten küçültür.
class _FakeCompressor {
  _FakeCompressor();

  final calls = <({String path, int edge, int quality})>[];

  /// Kaynak karenin uzun kenarı. Gerçek dosyayı çözmeden taklit ediyoruz.
  int sourceEdge = 2048;
  bool fails = false;

  MethodChannel install() {
    const channel = MethodChannel('latermark/image');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method != 'compress') return null;
      final args = (call.arguments as Map).cast<String, Object?>();
      final path = args['path']! as String;
      final edge = args['maxEdge']! as int;
      calls.add((path: path, edge: edge, quality: args['quality']! as int));

      if (fails) return false;
      // Yerel taraf sınırın altındaki kareye dokunmuyor.
      if (sourceEdge <= edge) return false;
      // Küçültme: dosyayı hedefle orantılı biçimde kısalt.
      final file = File(path);
      if (!file.existsSync()) return false;
      final bytes = file.readAsBytesSync();
      final shrunk = (bytes.length * edge / sourceEdge).round().clamp(1, bytes.length);
      file.writeAsBytesSync(bytes.sublist(0, shrunk));
      return true;
    });
    return channel;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory sandbox;
  late _FakeCompressor native;
  late PhotoStore store;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('lm_thumb');
    native = _FakeCompressor()..install();
    store = await PhotoStore.openIn(
      sandbox,
      // Yerel kanal masaüstünde yok; sahte kanalla gerçek davranışı sınıyoruz.
      compressor: ImageCompressor(supported: true),
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('latermark/image'), null);
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  /// Kaydedilmiş bir kare üretir; sıkıştırma arka planda koştuğu için
  /// döngüyü testte elle tamamlıyoruz.
  Future<String> capture({int bytes = 400000}) async {
    final source = File('${sandbox.path}/kaynak.jpg')
      ..writeAsBytesSync(List<int>.filled(bytes, 7));
    final name = await store.persist(XFile(source.path));
    // `persist` küçültmeyi beklemiyor; testte tamamlanmasını bekleyelim.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return name;
  }

  test('kaydedilen kare için küçük kopya üretiliyor', () async {
    final name = await capture();

    expect(store.thumbFor(name).existsSync(), isTrue);
    // Izgara küçük kopyayı çiziyor, tam kareyi değil.
    expect(store.gridFileFor(name).path, store.thumbFor(name).path);
    // Küçük kopya gerçekten küçük.
    expect(
      store.thumbFor(name).lengthSync(),
      lessThan(store.fileFor(name).lengthSync()),
    );
    // Yerel tarafa iki ayrı hedef gitti: saklama sınırı ve ızgara sınırı.
    expect(native.calls.map((c) => c.edge), contains(ImageCompressor.maxEdge));
    expect(native.calls.map((c) => c.edge), contains(PhotoStore.thumbEdge));
  });

  /// Yayındaki 1.0.2 sürümünden gelen kullanıcının arşivinde tek bir küçük
  /// kopya yok. Izgara o kayıtlar için tam kareyi çizmeye devam etmeli —
  /// yoksa güncelleme sonrası akış boş görünürdü.
  test('kopyası olmayan eski kayıt tam kareyi çiziyor', () async {
    // 1.0.2'nin bıraktığı hâl: yalnızca tam kare, thumbs klasörü bile yok.
    final legacy = File(store.fileFor('eski.jpg').path)
      ..writeAsBytesSync(List<int>.filled(400000, 3));
    expect(legacy.existsSync(), isTrue);
    expect(store.thumbFor('eski.jpg').existsSync(), isFalse);

    expect(store.gridFileFor('eski.jpg').path, store.fileFor('eski.jpg').path);

    // Geri doldurma çalışınca ızgara kendiliğinden küçük kopyaya geçiyor.
    expect(await store.ensureThumbnail('eski.jpg'), isTrue);
    expect(store.gridFileFor('eski.jpg').path, store.thumbFor('eski.jpg').path);
  });

  /// Küçültme gerçekleşmezse tam boy bir ikinci dosya tutmanın anlamı yok:
  /// yer harcar, hiç hız kazandırmaz.
  test('küçültme başarısızsa kopya bırakılmıyor', () async {
    File(store.fileFor('a.jpg').path).writeAsBytesSync(List<int>.filled(1000, 1));
    native.fails = true;

    expect(await store.ensureThumbnail('a.jpg'), isFalse);
    expect(store.thumbFor('a.jpg').existsSync(), isFalse);
    expect(store.gridFileFor('a.jpg').path, store.fileFor('a.jpg').path);
  });

  test('zaten küçük olan kare için kopya üretilmiyor', () async {
    File(store.fileFor('b.jpg').path).writeAsBytesSync(List<int>.filled(1000, 1));
    native.sourceEdge = 400; // ızgara sınırının altında

    expect(await store.ensureThumbnail('b.jpg'), isFalse);
    expect(store.thumbFor('b.jpg').existsSync(), isFalse);
  });

  test('not silinince küçük kopya da siliniyor', () async {
    final name = await capture();
    expect(store.thumbFor(name).existsSync(), isTrue);

    await store.remove(name);

    expect(store.fileFor(name).existsSync(), isFalse);
    expect(store.thumbFor(name).existsSync(), isFalse);
  });

  test('yetim küçük kopya süpürmede toplanıyor', () async {
    final name = await capture();
    final thumb = store.thumbFor(name);
    expect(thumb.existsSync(), isTrue);

    // Kaydı kalkmış ama dosyaları duruyor; süpürme yaşça eski olanı alır.
    final old = DateTime.now().subtract(const Duration(hours: 1));
    store.fileFor(name).setLastModifiedSync(old);
    thumb.setLastModifiedSync(old);

    await store.pruneOrphans(<String>{});

    expect(store.fileFor(name).existsSync(), isFalse);
    expect(thumb.existsSync(), isFalse);
  });

  test('kayıtlı kare süpürmede korunuyor', () async {
    final name = await capture();
    final old = DateTime.now().subtract(const Duration(hours: 1));
    store.fileFor(name).setLastModifiedSync(old);
    store.thumbFor(name).setLastModifiedSync(old);

    await store.pruneOrphans({name});

    expect(store.fileFor(name).existsSync(), isTrue);
    expect(store.thumbFor(name).existsSync(), isTrue);
  });

  /// Yedekleme not listesinden besleniyor, klasör taramıyor: küçük kopyalar
  /// yedeğe hiç girmiyor. Geri yükleme ise bütün klasörü değiştirdiği için
  /// kopyalar gidiyor — ızgara o anda tam kareye düşüyor, sonra yeniden
  /// üretiliyor. Hiçbir aşamada kare kaybolmuyor.
  test('geri yükleme kopyaları siliyor, ızgara tam kareye düşüyor', () async {
    final name = await capture();
    expect(store.thumbFor(name).existsSync(), isTrue);

    // Geri yüklemenin bıraktığı hâl: yalnız tam kareler, thumbs yok.
    final staging = Directory('${sandbox.path}/staging')..createSync();
    File('${staging.path}/$name').writeAsBytesSync(List<int>.filled(400000, 9));
    final replacement = await store.beginReplaceAllFrom(staging);
    await replacement.commit();

    expect(store.fileFor(name).existsSync(), isTrue);
    expect(store.thumbFor(name).existsSync(), isFalse);
    // Kare kaybolmuyor: ızgara tam kareyi çiziyor.
    expect(store.gridFileFor(name).path, store.fileFor(name).path);

    // Geri doldurma kopyayı yeniden üretiyor.
    expect(await store.ensureThumbnail(name), isTrue);
    expect(store.gridFileFor(name).path, store.thumbFor(name).path);
  });
}
