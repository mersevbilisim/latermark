import 'dart:io';
import 'dart:ui' as ui;

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../notes/data/image_compressor.dart';
import '../../notes/data/notes_repository.dart';
import '../../notes/domain/note_reminder.dart';
import '../../notes/domain/retention.dart';

/// Büyük bir arşivi gerçek cihazda kurmanın tek pratik yolu.
///
/// Performansın asıl sınandığı yer bin kayıtlık bir arşiv; oraya elle bin
/// fotoğraf eklemek mümkün değil. Bu sınıf aynı yolu — depoya kopyalama,
/// sıkıştırma, veritabanına yazma — gerçekten kullanarak arşivi doldurur.
///
/// **Ölçümün gerçek kalmasının sebebi dosya yollarının ayrı olması.** Flutter
/// görüntü önbelleğini dosya yoluna göre anahtarlıyor; içerik aynı olsa da her
/// kayıt kendi karesini taşıdığı için çözme maliyeti kaydırma sırasında
/// birebir oluşuyor. Tek bir kare üretip bin ayrı yola yazmak, bin ayrı kare
/// üretmekle aynı ölçümü çok daha ucuza veriyor.
///
/// Yayınlanan uygulamada **hiç var olmaz**: [available] `kDebugMode` ile
/// kapılı ve arayüzdeki satır da öyle. Ölçüm bittiğinde [clear] tohumlanan
/// kayıtları geri toplar; kodu kaldırmak içinse bu dosyayı silmek ve
/// `settings_page.dart` içindeki tek satırlık çağrıyı çıkarmak yeter.
abstract final class DebugArchiveSeed {
  /// Tohumlanan kaydın gövdesine düşen işaret.
  ///
  /// Ayrı bir sütun açmak yerine gövde: şema yalnızca ürünün gerçek alanlarını
  /// taşısın, ölçüm kolaylığı üretim veritabanına sızmasın. [clear] tam da bu
  /// işareti arar, dolayısıyla kullanıcının kendi kayıtlarına hiç dokunmaz.
  static const marker = '⟦seed⟧';

  /// Üretilen karenin uzun kenarı. Depodaki gerçek sınırla aynı.
  static const _edge = 2048;

  /// Yayınlanan uygulamada hiçbir çağrı iş yapmaz.
  ///
  /// [DebugEntitlement]'tan farklı olarak `FLUTTER_TEST` dışlanmıyor: oradaki
  /// dışlama anahtarın Ayarlar yerleşim testlerine sahte bir satır eklememesi
  /// içindi. Buradaki satır zaten `DebugEntitlement.available` ile kapılı bir
  /// bölümün içinde, yani testlerde hiç çizilmiyor. Kapıyı burada gevşetmek,
  /// cihazda koşacak kodun testle doğrulanabilmesini sağlıyor.
  static const available = kDebugMode;

  /// Arşivi [count] kayıtla doldurur.
  ///
  /// Kayıtlar iki yıla yayılır ki akıştaki bütün yaş bölümleri oluşsun, ve
  /// her beşincisine hatırlatma kurulur — bin kayıtta iki yüz hatırlatma,
  /// iOS'un altmış dört bekleyen bildirim sınırını gerçekten zorlayan oran.
  ///
  /// Hatırlatmanın gerçekten yazılması için **Pro hakkı açık olmalı**: depo
  /// hak kapalıyken seçimi bilerek düşürüyor. Ölçümü hatırlatmalarla birlikte
  /// yapmak istiyorsan önce debug Pro anahtarını aç.
  static Future<void> fill(
    NotesRepository repository, {
    required int count,
    void Function(int done, int total)? onProgress,
  }) async {
    if (!available) return;

    final scratch = await getTemporaryDirectory();
    final bytes = await _frame(scratch);
    final now = DateTime.now();

    for (var index = 0; index < count; index++) {
      final file = File('${scratch.path}/seed_$index.jpg');
      await file.writeAsBytes(bytes);
      await repository.create(
        capture: XFile(file.path),
        body: '$marker $index',
        retention: const RetentionChoice(Retention.off),
        createdAt: now.subtract(Duration(hours: index * 17)),
        reminder: index % 5 == 0
            ? ReminderChoice(at: now.add(Duration(days: 1 + index ~/ 5)))
            : const ReminderChoice.off(),
      );
      if (await file.exists()) await file.delete();
      onProgress?.call(index + 1, count);
    }
  }

  /// Tohumlanan kayıtları siler. Kullanıcının kendi kareleri kalır.
  static Future<int> clear(NotesRepository repository) async {
    if (!available) return 0;

    final notes = await repository.watchNotes().first;
    final seeded = notes.where((note) => note.body.startsWith(marker)).toList();
    if (seeded.isEmpty) return 0;
    await repository.deleteAll(seeded);
    return seeded.length;
  }

  /// Kaç tohumlanmış kayıt var.
  static Future<int> count(NotesRepository repository) async {
    if (!available) return 0;
    final notes = await repository.watchNotes().first;
    return notes.where((note) => note.body.startsWith(marker)).length;
  }

  /// Ölçüme uygun tek bir kare.
  ///
  /// İki ayrı maliyet var ve ikisi ayrı şeye bağlı: **çözme** piksel sayısına,
  /// **okuma** dosya boyutuna. Bu yüzden kadraj gerçek bir karenin ölçüsünde
  /// (uzun kenar 2048) ama içerik ölçülü tutuluyor — gürültüyü artırmak PNG'yi
  /// megabaytlara çıkarıp bin kayıtta gigabaytlarca geçici yazma yaratıyordu,
  /// oysa depodaki gerçek JPEG birkaç yüz kilobayt.
  ///
  /// Kare bir kez **gerçek sıkıştırıcıdan** geçiriliyor ve ortaya çıkan JPEG
  /// baytları bütün kopyalar için kullanılıyor. Ham PNG'yi çoğaltmak bin
  /// kayıtta gigabayta yakın geçici yazma yaratıyordu; oysa depodaki gerçek
  /// dosya zaten sıkıştırılmış olan. Böylece hem yazma ucuzluyor hem her kopya
  /// baştan gerçek boyutta oluyor.
  static Future<Uint8List> _frame(Directory scratch) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final size = ui.Size(_edge.toDouble(), _edge * 3 / 4);

    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, size.width, size.height),
      ui.Paint()
        ..shader = ui.Gradient.linear(
          ui.Offset.zero,
          ui.Offset(size.width, size.height),
          const [ui.Color(0xFF2B1D14), ui.Color(0xFFFF7A55)],
        ),
    );
    for (var i = 0; i < 24; i++) {
      canvas.drawCircle(
        ui.Offset((i * 337) % size.width, (i * 229) % size.height),
        40 + (i % 7) * 30,
        ui.Paint()..color = ui.Color(0xFF000000 | (i * 7919) & 0x00FFFFFF),
      );
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      size.width.round(),
      size.height.round(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    image.dispose();
    final raw = data!.buffer.asUint8List();

    // Sıkıştırıcı yalnız iOS/Android'de var; başka yerde ham kare kullanılır.
    final source = File('${scratch.path}/seed_source.jpg');
    await source.writeAsBytes(raw);
    await ImageCompressor().compress(source);
    final compressed = await source.readAsBytes();
    if (await source.exists()) await source.delete();
    return compressed;
  }
}
