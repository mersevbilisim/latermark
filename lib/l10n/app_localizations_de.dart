// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class L10nDe extends L10n {
  L10nDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Latermark';

  @override
  String get actionSave => 'Sichern';

  @override
  String get composeSaving => 'Wird gesichert';

  @override
  String get actionCancel => 'Abbrechen';

  @override
  String get actionClose => 'Schließen';

  @override
  String get actionBack => 'Zurück';

  @override
  String get actionDelete => 'Löschen';

  @override
  String get actionEdit => 'Bearbeiten';

  @override
  String get actionMore => 'Mehr';

  @override
  String get openPhotoSemantic => 'Foto im Vollbild öffnen';

  @override
  String get actionRetry => 'Erneut versuchen';

  @override
  String get actionGoBack => 'Zurück';

  @override
  String get actionOpen => 'Öffnen';

  @override
  String get settingsAction => 'Einstellungen';

  @override
  String get shutterSemantic => 'Foto aufnehmen';

  @override
  String get searchHint => 'Suchen';

  @override
  String searchResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Ergebnisse',
      one: '$count Ergebnis',
    );
    return '$_temp0';
  }

  @override
  String get searchEmpty => 'Eşleşen kayıt yok';

  @override
  String get searchCancel => 'Vazgeç';

  @override
  String get searchInPhoto => 'karede';

  @override
  String get notesTitle => 'Notizen';

  @override
  String get dateGroupToday => 'Heute';

  @override
  String get dateGroupYesterday => 'Gestern';

  @override
  String get dateGroupPastWeek => 'Letzte 7 Tage';

  @override
  String get dateGroupPastMonth => 'Letzter Monat';

  @override
  String get dateGroupPastThreeMonths => 'Letzte 3 Monate';

  @override
  String get dateGroupPastYear => 'Letztes Jahr';

  @override
  String get dateGroupOlder => 'Vor mehr als einem Jahr';

  @override
  String noteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Notizen',
      one: '1 Notiz',
      zero: 'Keine Notizen',
    );
    return '$_temp0';
  }

  @override
  String get noteWithoutBody => 'Ohne Notiz';

  @override
  String get inviteTitle => 'Tippen und aufnehmen';

  @override
  String get inviteBody =>
      'Ein Beleg, ein Parkplatz, ein Detail …\nFotografieren, ein paar Worte dazu, weiter.';

  @override
  String get pickFromGallery => 'Aus Fotos wählen';

  @override
  String get pickFromGallerySemantic => 'Foto aus der Mediathek wählen';

  @override
  String get galleryPickerOpening => 'Fotoauswahl wird geöffnet';

  @override
  String get manifestoFirst => 'Einfach';

  @override
  String get manifestoSecond => 'Privat';

  @override
  String get manifestoThird => 'Deins';

  @override
  String get switchToLargeView => 'Zur großen Ansicht wechseln';

  @override
  String get switchToGridView => 'Zur Rasteransicht wechseln';

  @override
  String get toastPhotoPickFailed =>
      'Dieses Foto konnte nicht ausgewählt werden. Versuch es erneut.';

  @override
  String get toastPendingPickFailed =>
      'Die unterbrochene Fotoauswahl konnte nicht fortgesetzt werden.';

  @override
  String get toastSharedPhotoAdded => 'Geteiltes Foto hinzugefügt.';

  @override
  String get toastSharedPhotoFailed =>
      'Das geteilte Foto konnte nicht hinzugefügt werden. Wir versuchen es erneut.';

  @override
  String get toastDeleteFailed => 'Löschen fehlgeschlagen. Versuch es erneut.';

  @override
  String get toastSaveFailed => 'Sichern fehlgeschlagen. Versuch es erneut.';

  @override
  String get toastEditFailed =>
      'Die Änderungen konnten nicht gesichert werden.';

  @override
  String get toastPermissionDenied =>
      'Mitteilungen sind deaktiviert. Erinnerungen bleiben stumm.';

  @override
  String get deleteConfirmTitle => 'Diese Aufnahme löschen?';

  @override
  String get deleteConfirmCaption =>
      'Foto und Notiz werden gemeinsam gelöscht.';

  @override
  String get holdToDelete => 'Zum Löschen gedrückt halten';

  @override
  String get holdStageAlmost => 'Fast geschafft';

  @override
  String get holdStageRelease => 'Weiter halten …';

  @override
  String get holdStageGone => 'Gelöscht';

  @override
  String get cameraNotFoundTitle => 'Kamera nicht verfügbar';

  @override
  String get cameraNotFoundBody =>
      'Auf diesem Gerät ist keine Kamera verfügbar.';

  @override
  String get cameraDeniedTitle => 'Kamerazugriff deaktiviert';

  @override
  String get cameraDeniedBody =>
      'Erlaube den Kamerazugriff unter Einstellungen › Latermark, um hier Fotos aufzunehmen.';

  @override
  String get cameraFailedTitle => 'Kamera konnte nicht geöffnet werden';

  @override
  String get cameraFailedBody => 'Ein unerwarteter Fehler ist aufgetreten.';

  @override
  String get switchLens => 'Kamera wechseln';

  @override
  String flashSemantic(String state) {
    return 'Blitz: $state';
  }

  @override
  String get flashOff => 'aus';

  @override
  String get flashAuto => 'automatisch';

  @override
  String get flashOn => 'ein';

  @override
  String get composeHint => 'Warum hast du das aufgenommen?';

  @override
  String get composeReminderDescription =>
      'Bringt dir diese Aufnahme am gewählten Tag zurück.';

  @override
  String get composeLocationDescription =>
      'Verknüpft deinen aktuellen Ort nur mit dieser Aufnahme.';

  @override
  String get composeLocationResolving => 'Ort wird ermittelt …';

  @override
  String get composeLocationReady => 'Der Ort ist für diese Aufnahme bereit.';

  @override
  String get composeLocationPermissionRequired =>
      'Standortfreigabe erforderlich.';

  @override
  String get composeAnotherPhoto => 'Anderes Foto wählen';

  @override
  String get composeRetake => 'Neu aufnehmen';

  @override
  String get sourceGallery => 'FOTOS';

  @override
  String get sourceShared => 'GETEILT';

  @override
  String get reminderLabel => 'Erinnern';

  @override
  String get addedLabel => 'Hinzugefügt am';

  @override
  String get lastUpdatedLabel => 'Zuletzt geändert';

  @override
  String get locationLabel => 'Ort';

  @override
  String get locationAddLabel => 'Ort hinzufügen';

  @override
  String get locationBlocked =>
      'Das Hinzufügen des Ortes hängt von deiner Erlaubnis ab. Erlaube den Ortungszugriff, um den Aufnahmeort zu speichern.';

  @override
  String get compassNorth => 'N';

  @override
  String get compassSouth => 'S';

  @override
  String get compassEast => 'O';

  @override
  String get compassWest => 'W';

  @override
  String get toastMapFailed => 'Karten konnte nicht geöffnet werden';

  @override
  String get reminderSuffixActive => 'Tage später';

  @override
  String get reminderSuffixOff => 'Tage — aus';

  @override
  String get reminderBlocked =>
      'Mitteilungen sind deaktiviert. Die Aufnahme wird trotzdem gesichert; die Erinnerung wird aktiv, sobald du Mitteilungen erlaubst.';

  @override
  String get editNoteSemantic => 'Notiz bearbeiten';

  @override
  String get editSheetHeader => 'NOTIZ BEARBEITEN';

  @override
  String get retentionSelectorTitle => 'Automatisch löschen';

  @override
  String get retentionOffNotice =>
      'Automatisches Löschen ist aus — diese Aufnahme bleibt, bis du sie selbst löschst.';

  @override
  String get retentionCustom => 'Eigene';

  @override
  String get retentionCustomTitle => 'Eigene Dauer';

  @override
  String retentionCustomHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Stunden',
      one: '1 Stunde',
    );
    return '$_temp0';
  }

  @override
  String retentionCustomDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage',
      one: '1 Tag',
    );
    return '$_temp0';
  }

  @override
  String retentionCustomWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Wochen',
      one: '1 Woche',
    );
    return '$_temp0';
  }

  @override
  String get retentionUnitHours => 'Stunden';

  @override
  String get retentionUnitDays => 'Tage';

  @override
  String get retentionUnitWeeks => 'Wochen';

  @override
  String get retentionCustomDescription =>
      'Die Aufnahme wird nach dieser Dauer automatisch gelöscht.';

  @override
  String get retentionOff => 'Aus';

  @override
  String get retentionThreeDays => '3 Tage';

  @override
  String get retentionOneWeek => '1 Woche';

  @override
  String get retentionOffDescription => 'Aus';

  @override
  String get retentionThreeDaysDescription => 'Wird nach 3 Tagen gelöscht';

  @override
  String get retentionOneWeekDescription => 'Wird nach 1 Woche gelöscht';

  @override
  String get legalPrivacy => 'Datenschutz';

  @override
  String get legalTerms => 'Nutzungsbedingungen';

  @override
  String get yourDataTitle => 'Latermark & deine Daten';

  @override
  String get yourDataSubtitle =>
      'Deine Privatsphäre ist uns wichtig. Wir behandeln sie mit Respekt.';

  @override
  String get yourDataSafetyQuestion => 'Sind meine Daten sicher?';

  @override
  String get yourDataSafetyAnswer =>
      'Latermark verarbeitet deine Notizen, Bilder und Ortsangaben vollständig auf deinem Gerät. Solange du sie nicht selbst teilst, verlassen deine Inhalte das Gerät nicht – auch nicht für Analysen, Absturzberichte oder Nutzungsstatistiken.';

  @override
  String get yourDataLocationQuestion =>
      'Warum benötigt Latermark meinen Standort?';

  @override
  String get yourDataLocationAnswer =>
      'Nur wenn du einer Aufnahme einen Ort hinzufügen möchtest, wird dein Standort einmalig ermittelt. Er wird ausschließlich in dieser Aufnahme gespeichert; eine Ortung im Hintergrund findet nicht statt. Erst wenn du die Karte öffnest, wird die Koordinate an deine Karten-App übergeben.';

  @override
  String get yourDataPhotosQuestion => 'Wofür wird der Fotozugriff verwendet?';

  @override
  String get yourDataPhotosAnswer =>
      'Der Zugriff wird nur benötigt, wenn du ein Bild aus deiner Fotomediathek auswählen möchtest. Latermark übernimmt ausschließlich das von dir gewählte Bild. Eine Internetverbindung ist dafür nicht erforderlich.';

  @override
  String get yourDataRemindersQuestion => 'Wie funktionieren Erinnerungen?';

  @override
  String get yourDataRemindersAnswer =>
      'Erinnerungen werden direkt auf deinem Gerät geplant und angezeigt. Kein externer Server sendet oder aktiviert sie.';

  @override
  String get yourDataDeletionQuestion =>
      'Was passiert, wenn ich die App lösche?';

  @override
  String get yourDataDeletionAnswer =>
      'Alle in Latermark gespeicherten Notizen, importierten Bilder und Ortsangaben werden dauerhaft entfernt. Deine Fotomediathek und die Daten anderer Apps bleiben davon unberührt.';

  @override
  String get legalOpenFailed => 'Der Link konnte nicht geöffnet werden.';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get sectionAppearance => 'Darstellung';

  @override
  String get sectionReminder => 'Erinnerungen';

  @override
  String get themeTitle => 'Erscheinungsbild';

  @override
  String get themeDescription =>
      'Systemdarstellung übernehmen oder eine feste Darstellung wählen.';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Hell';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get appColorTitle => 'App-Farbe';

  @override
  String get appColorDescription =>
      'Wähle die Akzentfarbe für Bedienelemente und Hervorhebungen.';

  @override
  String get accentOrange => 'Orange';

  @override
  String get accentBlue => 'Blau';

  @override
  String get accentViolet => 'Violett';

  @override
  String get accentPink => 'Rosa';

  @override
  String get accentGreen => 'Grün';

  @override
  String get accentGold => 'Gold';

  @override
  String get retentionTitle => 'Automatisch löschen';

  @override
  String get retentionDescription =>
      'Neue Aufnahmen starten mit dieser Dauer. Du kannst sie für jede Aufnahme in der Detailansicht ändern.';

  @override
  String get feedTitle => 'Übersicht';

  @override
  String get feedDescription =>
      'Aufnahmen groß anzeigen oder mehr davon im Raster sehen.';

  @override
  String get densityLarge => 'Groß';

  @override
  String get densityGrid => 'Raster';

  @override
  String get languageTitle => 'Sprache';

  @override
  String get languageDescription =>
      'Latermark folgt der Gerätesprache. Du kannst auch eine andere wählen.';

  @override
  String get languageSystem => 'System';

  @override
  String get remindersTitle => 'Erinnerungen';

  @override
  String get remindersDescription =>
      'Nur Aufnahmen, für die du beim Sichern eine Zeit festlegst, senden eine Mitteilung. Alle anderen bleiben still.';

  @override
  String get remindersBlockedDescription =>
      'Mitteilungen sind in den Systemeinstellungen deaktiviert. Erinnerungen laufen weiter, sobald du sie erlaubst.';

  @override
  String get openSystemSettings => 'Systemeinstellungen öffnen';

  @override
  String get openSettingsShort => 'Einstellungen öffnen';

  @override
  String versionMark(String version, String build) {
    return 'Version $version ($build)';
  }

  @override
  String get dayToday => 'Heute';

  @override
  String get dayYesterday => 'Gestern';

  @override
  String get relativeJustNow => 'gerade eben';

  @override
  String relativeMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Min.',
      one: '1 Min.',
    );
    return '$_temp0';
  }

  @override
  String relativeHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Std.',
      one: '1 Std.',
    );
    return '$_temp0';
  }

  @override
  String get relativeYesterday => 'gestern';

  @override
  String relativeDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage',
      one: '1 Tag',
    );
    return '$_temp0';
  }

  @override
  String get remainingNow => 'jetzt';

  @override
  String remainingShortDays(int count) {
    return '$count T';
  }

  @override
  String remainingShortHours(int count) {
    return '$count Std.';
  }

  @override
  String remainingShortMinutes(int count) {
    return '$count Min.';
  }

  @override
  String get remainingShortLessThanMinute => '<1 Min.';

  @override
  String get remainingSoon => 'Wird gleich gelöscht';

  @override
  String remainingLongDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Wird in $days Tagen gelöscht',
      one: 'Wird in 1 Tag gelöscht',
    );
    return '$_temp0';
  }

  @override
  String remainingLongDaysHours(int days, int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days Tagen',
      one: '1 Tag',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours Stunden',
      one: '1 Stunde',
    );
    return 'Wird in $_temp0 und $_temp1 gelöscht';
  }

  @override
  String remainingLongHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'Wird in $hours Stunden gelöscht',
      one: 'Wird in 1 Stunde gelöscht',
    );
    return '$_temp0';
  }

  @override
  String remainingLongHoursMinutes(int hours, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours Stunden',
      one: '1 Stunde',
    );
    String _temp1 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes Minuten',
      one: '1 Minute',
    );
    return 'Wird in $_temp0 und $_temp1 gelöscht';
  }

  @override
  String remainingLongMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Wird in $minutes Minuten gelöscht',
      one: 'Wird in 1 Minute gelöscht',
    );
    return '$_temp0';
  }

  @override
  String get paywallLimitTitle => 'Deine 10 Plätze sind belegt';

  @override
  String paywallLimitBody(int limit) {
    return 'In der kostenlosen Version bleiben bis zu $limit Aufnahmen gleichzeitig erhalten. Pro hebt das Limit auf — oder du löschst eine Aufnahme und machst weiter.';
  }

  @override
  String get paywallLimitDelete => 'Eine Aufnahme löschen';

  @override
  String paywallCounter(int count, int limit) {
    return '$count/$limit';
  }

  @override
  String get proBadge => 'PRO';

  @override
  String get paywallHeadline => 'Manche Aufnahmen sollten bleiben.';

  @override
  String get paywallSubtitle =>
      'Latermark ist zum Loslassen gemacht. Pro ist für das, was bleiben soll.';

  @override
  String paywallOwnedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Du hast derzeit $count Aufnahmen.',
      one: 'Du hast derzeit 1 Aufnahme.',
    );
    return '$_temp0';
  }

  @override
  String get paywallFeatureUnlimited => 'Unbegrenzte Aufnahmen';

  @override
  String paywallFeatureUnlimitedDetail(int limit) {
    return 'Kostenlos bleiben bis zu $limit Aufnahmen.';
  }

  @override
  String get paywallFeatureCustomRetention => 'Dauer frei wählen';

  @override
  String get paywallFeatureCustomRetentionDetail =>
      'Mehr als 3 Tage oder 1 Woche.';

  @override
  String get paywallFeatureReminders => 'Erinnerungen';

  @override
  String get paywallFeatureRemindersDetail =>
      'Ein leiser Hinweis für das, was zählt.';

  @override
  String get paywallFeatureWidget => 'Widgets für Home- & Sperrbildschirm';

  @override
  String get paywallFeatureWidgetDetail =>
      'Die neueste Aufnahme immer im Blick.';

  @override
  String paywallPrice(String price) {
    return '$price';
  }

  @override
  String get paywallOneTime => 'Einmaliger Kauf';

  @override
  String get paywallNoSubscription => 'Kein Abo. Einmal zahlen, Pro behalten.';

  @override
  String get paywallOwned => 'Latermark Pro gehört dir.';

  @override
  String get paywallFeatureNoSubscription => 'Kein Abonnement';

  @override
  String get paywallFeatureNoSubscriptionDetail =>
      'Andere Apps verlangen monatlich Geld. Latermark nicht.';

  @override
  String get paywallCta => 'Pro freischalten';

  @override
  String get paywallRestore => 'Käufe wiederherstellen';

  @override
  String get paywallClose => 'Schließen';

  @override
  String get paywallLifeFree => 'Kostenlos';

  @override
  String get paywallLifePro => 'Pro';

  @override
  String get notificationTitle => 'Erinnerung';

  @override
  String get notificationTitleNoBody => 'Eine Aufnahme wartet';

  @override
  String get notificationBodyNoBody =>
      'Du wolltest an diese Aufnahme erinnert werden.';

  @override
  String get notificationChannelName => 'Erinnerungen';

  @override
  String get notificationChannelDescription =>
      'Erinnert dich an geplante Aufnahmen.';

  @override
  String get actionOK => 'OK';

  @override
  String get widgetDescription => 'Zeigt deine neueste Aufnahme und Notiz.';

  @override
  String get widgetEmptySubtitle => 'Deine erste Notiz erscheint hier';

  @override
  String get widgetPhotoDescription => 'Foto deiner neuesten Aufnahme';

  @override
  String get widgetLeaveTrace => 'Neue Spur hinterlassen';

  @override
  String get widgetOpenApp => 'Latermark öffnen';

  @override
  String get widgetCreateNote => 'Neue Notiz erstellen';

  @override
  String get widgetLeaveFirstTrace => 'Hinterlasse deine erste Spur';

  @override
  String get widgetProRequired => 'Widgets sind mit Latermark Pro verfügbar.';

  @override
  String get widgetPreviewNote => 'An die Buchhaltung senden';

  @override
  String get widgetPreviewDay => 'HEUTE';

  @override
  String get shareComposeHint => 'Warum möchtest du dieses Foto behalten?';

  @override
  String get shareErrorTitle => 'Foto konnte nicht hinzugefügt werden';

  @override
  String get shareErrorBody =>
      'Das Foto konnte nicht an Latermark übertragen werden. Versuch es erneut.';

  @override
  String get cameraUsageDescription =>
      'Mit Kamerazugriff kannst du Fotos für deine Notizen aufnehmen.';

  @override
  String get photoLibraryUsageDescription =>
      'Mit Fotozugriff kannst du Bilder aus deiner Mediathek zu Notizen hinzufügen.';

  @override
  String get actionShare => 'Teilen';

  @override
  String get shareNoteSemantic => 'Foto und Notiz teilen';
}
