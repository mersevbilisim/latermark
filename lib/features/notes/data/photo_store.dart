import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:cross_file/cross_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'image_compressor.dart';

/// Çekilen kareleri uygulama belge klasöründe tutar.
///
/// Veritabanı yalnızca dosya *adını* bilir; mutlak yola çeviren tek yer
/// burasıdır. Böylece iOS'ta konteyner yolu değişse bile kayıtlar bozulmaz.
class PhotoStore {
  PhotoStore._(this._directory, {ImageCompressor? compressor})
    : _compressor = compressor ?? ImageCompressor();

  final Directory _directory;
  final ImageCompressor _compressor;
  static final _random = Random();

  static const _folderName = 'captures';

  /// Klasörü çözer ve yoksa oluşturur. Uygulama açılışında bir kez çağrılır,
  /// sonrasında tüm erişim eşzamanlıdır.
  static Future<PhotoStore> open() =>
      _openIn(getApplicationDocumentsDirectory());

  /// Testlerde geçici bir klasöre bağlanmak için.
  static Future<PhotoStore> openIn(Directory parent) =>
      _openIn(Future.value(parent));

  static Future<PhotoStore> _openIn(Future<Directory> parent) async {
    final directory = Directory(p.join((await parent).path, _folderName));
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    return PhotoStore._(directory);
  }

  /// Kayıtlı bir dosya adını okunabilir [File] nesnesine çevirir.
  File fileFor(String name) => File(p.join(_directory.path, name));

  /// Kamera çıktısını kalıcı klasöre taşır ve saklanacak dosya adını döner.
  ///
  /// Kare **önce** kaydediliyor, sonra küçültülüyor. Sıra böyle: sıkıştırma
  /// başarısız olsa bile kullanıcının fotoğrafı yerinde duruyor.
  ///
  /// Küçültme **beklenmiyor**. Kullanıcının kaydettiği an bittiğinde kare
  /// zaten diskte ve not yazılabilir durumda; sıkıştırma yalnızca dosyayı
  /// küçülten bir iyileştirme ve sonucu ekranda hiçbir şeyi değiştirmiyor.
  /// Beklemek, kullanıcıyı 12 MP bir kareyi çözüp yeniden kodlamanın süresi
  /// kadar "Kaydet" ekranında tutmak demekti — görünürde hiçbir karşılığı
  /// olmayan bir bekleme.
  ///
  /// Arka planda yürütmek yalnızca yazma atomik olduğu için güvenli: her iki
  /// platform da yeni kareyi yan dosyaya yazıp yerine taşıyor, dolayısıyla
  /// aynı anda okuyan akış hep bütün bir kare görüyor. Uygulama arada
  /// kapanırsa kare sıkıştırılmamış kalır — yalnızca daha büyük, bozuk değil.
  Future<String> persist(XFile capture) async {
    final name = _uniqueName(p.extension(capture.path));
    final destination = p.join(_directory.path, name);
    await capture.saveTo(destination);
    unawaited(_compressInBackground(File(destination)));
    return name;
  }

  /// Sıkıştırmayı kaydetme yolundan ayırır ve hatalarını yutar.
  ///
  /// Kullanıcı kaydettiği notu hemen silerse sıkıştırma silinmiş bir dosyayı
  /// geri yazabilir; [pruneOrphans] açılışta o yetimi zaten topluyor.
  Future<void> _compressInBackground(File image) async {
    try {
      await _compressor.compress(image);
    } catch (_) {
      // Sıkıştırma bir iyileştirme; başarısızlığı kaydı etkilemez.
    }
  }

  /// Notu silerken çağrılır. Dosya zaten yoksa sessizce geçer.
  Future<void> remove(String name) async {
    final file = fileFor(name);
    if (file.existsSync()) {
      try {
        await file.delete();
      } on FileSystemException {
        // Disk hatası bir notun silinmesini engellememeli.
      }
    }
  }

  Future<void> removeAll(Iterable<String> names) async {
    for (final name in names) {
      await remove(name);
    }
  }

  /// Veritabanında karşılığı kalmamış dosyaları temizler. Kayıt silinirken
  /// uygulama öldürülürse ortaya çıkan yetim dosyalar için.
  Future<void> pruneOrphans(Set<String> knownNames) async {
    if (!_directory.existsSync()) return;
    await for (final entity in _directory.list()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (knownNames.contains(name)) continue;
      try {
        await entity.delete();
      } on FileSystemException {
        // Yoksay.
      }
    }
  }

  String _uniqueName(String extension) {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final salt = _random.nextInt(0xFFFF).toRadixString(16).padLeft(4, '0');
    final safeExtension = extension.isEmpty ? '.jpg' : extension;
    return '$stamp-$salt$safeExtension';
  }
}
