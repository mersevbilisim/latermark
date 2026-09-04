import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app_boot.dart';
import 'features/notes/data/notes_database.dart';
import 'features/notes/data/notes_repository.dart';
import 'features/reminders/reminder_service.dart';
import 'features/notes/data/photo_store.dart';
import 'features/paywall/data/debug_entitlement.dart';
import 'features/review/review_prompt_service.dart';

/// Yalnızca açılış sırası. Ekran ve iş mantığı `app/` ile `features/` altında.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Tüm diller için tarih verisi.
  //
  // Tek yerel yüklemek yetmiyor: `flutter_localizations` yalnızca *arayüzün*
  // yereline veri yüklüyor, oysa bildirim ve widget metinleri widget ağacının
  // dışında, elle yüklenmiş bir [L10n] ile biçimleniyor. Orada veri
  // bulunmayan bir yerel `LocaleDataException` atardı.
  await initializeDateFormatting();

  // Geliştirme anahtarı ilk kareden önce okunur; release'de no-op.
  await DebugEntitlement.load();

  final database = NotesDatabase();
  final photos = await PhotoStore.open();
  final notes = NotesRepository(database: database, photos: photos);
  // Açılışta iki temizlik: süresi dolan kayıtlar ve kaydı kalmamış dosyalar.
  //
  // Temizlik ilk kareden önce yapılıyor ki süresi dolmuş bir kayıt bir an
  // olsun görünmesin. Ama bu bir **bakım** işi ve `runApp`'in önünde duramaz.
  // Korumasız `await` burada veritabanından gelen her hatayı uygulamanın
  // açılışına çeviriyordu: kullanıcının gördüğü tek şey hiç geçmeyen açılış
  // ekranı oluyordu — ne ekranda bir işaret, ne bir çökme raporu, yani teşhis
  // edilemez bir ölüm. Aynı temizlik `AppScope` içinde açılışta ve dakikada
  // bir yeniden koşuyor; buradaki tur kaçarsa bir sonraki tutar.
  try {
    // İzin **süpürmeden önce** okunuyor.
    //
    // Süpürme, çalmış bir hatırlatmayı taşıyan kaydı silerken ücretsiz hakkın
    // hesabını da kapatıyor. Burada izni bilmeden silmek, o hesabı sessizce
    // kaçırmak olurdu: kayıt yok olduğu için `AppScope` de sonradan
    // kapatamazdı ve kullanıcı aynı üç hakkı sonsuza kadar yeniden
    // kullanabilirdi. Okuma başarısız olursa hak yakılmıyor — kullanıcının
    // aleyhine olan yön, kaçırılan gelirden daha pahalı.
    final permissionProbe = ReminderService();
    var granted = false;
    try {
      granted = await permissionProbe.hasPermission();
    } on Object catch (error) {
      debugPrint('Açılışta bildirim izni okunamadı: $error');
    } finally {
      unawaited(permissionProbe.dispose());
    }
    await notes.purgeExpired(reminderPermissionGranted: granted);
  } on Object catch (error) {
    debugPrint('Açılış temizliği yapılamadı: $error');
  }
  // Aynı gerekçe: yetim dosya toplamak da bakım. Beklenmiyor ama hatası da
  // bölgeye düşmemeli.
  unawaited(
    notes.sweepOrphanFiles().onError(
      (error, _) => debugPrint('Yetim dosyalar toplanamadı: $error'),
    ),
  );

  // Kök `LatermarkApp` değil, yığına sahip olan `LatermarkBoot`: onarım bozuk
  // veritabanının yerine yenisini kurabilmek için depoları tazelemek zorunda.
  runApp(
    LatermarkBoot(
      photos: photos,
      initialDatabase: database,
      reviewPrompts: ReviewPromptService(),
    ),
  );
}
