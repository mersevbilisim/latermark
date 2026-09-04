import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'photo_store.dart';

/// Veritabanı açılamadığında kalan tek gerçek: kareler diskte duruyor.
///
/// Latermark'ta fotoğraflar veritabanının **dışında**, `captures/` altında
/// saklanıyor; kayıtta yalnızca dosya adı var. Dosya adı da çekim damgasını
/// taşıyor (`<mikrosaniye>-<tuz>.jpg`). Yani veritabanı tamamen gitse bile bir
/// kaydın karesi ve tarihi geri kurulabiliyor — kullanıcının yeri
/// doldurulamayan iki şeyi.
///
/// Kurtarılamayan: yazılan not, hatırlatma, saklama süresi, konum. Onlar
/// yalnızca veritabanındaydı. Yazı işletim sisteminin Spotlight indeksinde de
/// duruyor ama orada kaydın **kimliği** var, dosya adı yok; eşleştirmenin
/// dayanağı kalmadığı için oradan okumak sahipsiz cümleler getirirdi.
///
/// Onarım hiçbir şeyi silmiyor: bozuk dosya yana alınıyor, kareler yerinde
/// kalıyor. Geri dönüşü olmayan tek işlem kullanıcının uygulamayı silmesi
/// olurdu ve ekran tam da onu söylüyor.
class ArchiveRecovery {
  ArchiveRecovery({required this.photos, this.databaseDirectory});

  final PhotoStore photos;

  /// Testlerde veritabanı dosyasının bulunduğu klasörü sabitlemek için.
  /// Boşsa `drift_flutter`'ın kullandığı yer çözülür.
  @visibleForTesting
  final Directory? databaseDirectory;

  /// `driftDatabase(name: 'latermark_db')` bu adı kullanıyor.
  @visibleForTesting
  static const databaseFileName = 'latermark_db.sqlite';

  /// Kurtarılabilecek kareler.
  ///
  /// Sıralama tarihe göre: kullanıcı arşivini bıraktığı düzende buluyor.
  List<RecoveredFrame> scan() {
    final frames = <RecoveredFrame>[];
    for (final name in photos.frameNames()) {
      final stamp = stampOf(name);
      if (stamp == null) continue;
      frames.add(RecoveredFrame(imageName: name, createdAt: stamp));
    }
    frames.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return frames;
  }

  /// Dosya adındaki çekim anı.
  ///
  /// Ad `<mikrosaniye>-<tuz>.<uzantı>`. Tuz rastgele bir sayı, damga ise
  /// kaydın kendi anı — kaydederken oraya yazılmış olması bugün kurtarmanın
  /// dayandığı tek şey.
  ///
  /// Çözülemeyen ad atlanıyor: uydurma bir tarih vermektense o kareyi hiç
  /// almamak yeğ. Böyle bir dosya diskte kalıyor, silinmiyor.
  @visibleForTesting
  static DateTime? stampOf(String name) {
    final micros = int.tryParse(
      p.basenameWithoutExtension(name).split('-').first,
    );
    if (micros == null || micros <= 0) return null;
    final stamp = DateTime.fromMicrosecondsSinceEpoch(micros);
    // Akla yatkın bir aralık: uygulamanın kendi ürettiği her ad buraya düşer.
    // Dışarıdan gelmiş, tesadüfen sayıyla başlayan bir dosya düşmez.
    if (stamp.year < 2020 || stamp.year > DateTime.now().year + 1) return null;
    return stamp;
  }

  /// Bozuk veritabanını yana alır ve taşındığı dosyayı döner.
  ///
  /// **Silmiyor.** Bugün okuyamadığımız dosya yarın başka bir araçla
  /// okunabilir; kullanıcının verisini geri dönüşsüz atmak bize düşmez.
  /// Dosya yoksa `null` döner — onarımın kalanı yine de anlamlı.
  ///
  /// Taşıma eşzamanlı: tek seferlik, birkaç dosyalık bir iş ve onarımın geri
  /// kalanı buna bağlı — yarım kalmış bir taşımanın üstüne taze veritabanı
  /// açmak istemiyoruz.
  Future<File?> setAsideDatabase() async {
    final directory =
        databaseDirectory ?? await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, databaseFileName));
    if (!file.existsSync()) return null;

    final stamp = DateTime.now().millisecondsSinceEpoch;
    final aside = File('${file.path}.broken-$stamp');
    try {
      file.renameSync(aside.path);
    } on FileSystemException catch (error) {
      debugPrint('Bozuk veritabanı yana alınamadı: $error');
      rethrow;
    }
    // Yardımcı dosyalar geride kalırsa taze veritabanı onların üstüne açılır ve
    // aynı bozulmayı devralır.
    for (final suffix in const ['-wal', '-shm']) {
      final extra = File('${file.path}$suffix');
      if (!extra.existsSync()) continue;
      try {
        extra.renameSync('${aside.path}$suffix');
      } on FileSystemException {
        // Yardımcı dosyanın taşınamaması onarımı durdurmaz.
      }
    }
    return aside;
  }
}

/// Diskte bulunmuş, nota geri döndürülebilecek bir kare.
final class RecoveredFrame {
  const RecoveredFrame({required this.imageName, required this.createdAt});

  final String imageName;
  final DateTime createdAt;
}
