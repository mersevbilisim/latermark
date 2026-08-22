import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/supported_locale.dart';
import '../notes/data/notes_database.dart';
import '../notes/data/notes_repository.dart';
import '../notes/data/photo_store.dart';
import '../notes/domain/reminder_action.dart';
import '../settings/data/settings_repository.dart';
import 'reminder_service.dart';

/// Bildirimdeki bir düğmeye basıldığında **uygulama açılmadan** çalışan giriş
/// noktası.
///
/// İşletim sistemi cevabı ana motora değil, `flutter_local_notifications`'ın
/// başlattığı ayrı ve başsız bir Flutter motoruna teslim ediyor. Uygulama
/// tamamen kapalıyken de, açıkken de aynı yol işliyor; ayrı motor demek ayrı
/// bir isolate, ayrı bir Dart yığını ve **ayrı bir SQLite bağlantısı** demek.
///
/// Buradaki iş bilinçli olarak ince: kararı [reminderOutcomeFor] veriyor,
/// yazmayı [NotesRepository] yapıyor, programı da uygulamanın kullandığı
/// [ReminderService.sync] yeniden kuruyor. Bu dosyada kopyalanmış hiçbir
/// zamanlama kuralı yok — olsaydı iki yol zamanla ayrışır ve ayrıştığı gün
/// kimse fark etmezdi.
@pragma('vm:entry-point')
Future<void> handleReminderActionInBackground(
  NotificationResponse response,
) async {
  final action = ReminderAction.fromId(response.actionId);
  final noteId = noteIdFromReminderPayload(response.payload);
  if (action == null || noteId == null) return;

  await applyReminderActionFromNotification(
    action: action,
    noteId: noteId,
    payload: response.payload,
    eventId: '${response.id ?? -1}:${response.actionId}:${response.payload}',
  );
}

/// Eylemi veriye yazar ve bildirim programını yeniden kurar.
///
/// Giriş noktasından ayrı durması test edilebilmesi için: burada platform
/// kanalı dışında hiçbir şey gizli değil.
@visibleForTesting
Future<void> applyReminderActionFromNotification({
  required ReminderAction action,
  required int noteId,
  required String? payload,
  String? eventId,
  DateTime? now,
}) async {
  final moment = now ?? DateTime.now();
  final database = NotesDatabase();
  final reminders = ReminderService();
  var applied = false;

  try {
    // Tarih verisi ana motorda `main()` içinde yükleniyor; bu motor oradan
    // hiçbir şey miras almıyor ve bildirim metinleri widget ağacının dışında
    // biçimlendiği için veri bulunmayan bir yerel `LocaleDataException`
    // atardı.
    await initializeDateFormatting();
    final photos = await PhotoStore.open();
    final notes = NotesRepository(database: database, photos: photos);
    final settingsRepository = SettingsRepository(database);

    final updated = await notes.applyReminderAction(
      noteId,
      action,
      firedAt: reminderFiredAt(payload, now: moment),
      now: moment,
      eventId: eventId,
    );
    // Not silinmiş, hatırlatması kapanmış ya da hak düşmüş olabilir. Yazacak
    // bir şey yoksa programa da dokunmuyoruz.
    if (updated == null) return;
    applied = true;

    final settings = await settingsRepository.read();
    final l10n = await L10n.delegate.load(
      settings.locale.locale ??
          resolveSupportedLocale(PlatformDispatcher.instance.locale),
    );

    reminders.photoOf = notes.imageOf;
    await reminders.sync(await notes.watchNotes().first, settings, l10n);
  } catch (error) {
    // Kullanıcının gördüğü tek şey bildirimin kapanması. Burada patlamak
    // motoru düşürür ve hiçbir yerde iz bırakmaz; en azından günlüğe yaz.
    debugPrint('Bildirim eylemi tamamlanamadı: $error');
  } finally {
    unawaited(reminders.dispose());
    // Bağlantıyı kapatmak şart: motor bu çağrıdan sonra bir süre daha ayakta
    // kalıyor ve açık bir yazma bağlantısı, uygulamanın kendi bağlantısını
    // kilitli tutardı.
    await database.close();
    // Yalnızca gerçekten bir şey değiştiyse: haber, açık duran uygulamanın
    // bütün sorgularını yeniden koşturuyor ve boşuna tetiklenirse akış tam
    // ekran bir listeyi sebepsiz yere baştan kurar.
    if (applied) await _notifyRunningApp();
  }
}

/// Uygulama o an açıksa listeyi tazelemesini söyler.
///
/// Drift'in akış geçersizleştirmesi süreç içi çalışıyor; ayrı motordan yapılan
/// yazma, açık duran uygulamanın kartlarına kendiliğinden yansımaz. Native
/// taraf bu haberi ana motora aktarıyor. Uygulama kapalıysa alan olmaz ve
/// çağrı sessizce düşer — zaten açılışta her şey diskten okunuyor.
Future<void> _notifyRunningApp() async {
  try {
    await const MethodChannel(
      kReminderActionChannel,
    ).invokeMethod<void>('reminderActionApplied');
  } on MissingPluginException {
    // Kanal yalnızca iOS'ta kurulu; başka yerde tazelenecek ikinci motor da
    // yok.
  } on PlatformException catch (error) {
    debugPrint('Tazeleme haberi verilemedi: $error');
  }
}

/// Arka plan motoru ile ana motor arasındaki köprü kanalı.
const String kReminderActionChannel = 'latermark/reminder_actions';
