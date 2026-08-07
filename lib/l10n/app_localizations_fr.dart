// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class L10nFr extends L10n {
  L10nFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Latermark';

  @override
  String get actionSave => 'Enregistrer';

  @override
  String get actionCancel => 'Annuler';

  @override
  String get actionClose => 'Fermer';

  @override
  String get actionBack => 'Retour';

  @override
  String get actionDelete => 'Supprimer';

  @override
  String get actionEdit => 'Modifier';

  @override
  String get actionRetry => 'Réessayer';

  @override
  String get actionGoBack => 'Revenir';

  @override
  String get actionOpen => 'Ouvrir';

  @override
  String get settingsAction => 'Réglages';

  @override
  String get shutterSemantic => 'Prendre une photo';

  @override
  String get searchHint => 'Ara';

  @override
  String searchResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sonuç',
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
  String get notesTitle => 'Notes';

  @override
  String noteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes',
      one: '1 note',
      zero: 'Aucune note',
    );
    return '$_temp0';
  }

  @override
  String get noteWithoutBody => 'Sans note';

  @override
  String get inviteTitle => 'Touchez pour capturer';

  @override
  String get inviteBody =>
      'Un ticket, une place de parking, un détail…\nPhotographiez, ajoutez quelques mots, passez à autre chose.';

  @override
  String get pickFromGallery => 'Choisir dans Photos';

  @override
  String get pickFromGallerySemantic => 'Choisir une photo dans la photothèque';

  @override
  String get galleryPickerOpening => 'Ouverture de la photothèque';

  @override
  String get manifestoFirst => 'Simple';

  @override
  String get manifestoSecond => 'Privé';

  @override
  String get manifestoThird => 'À vous';

  @override
  String get switchToLargeView => 'Passer à la vue agrandie';

  @override
  String get switchToGridView => 'Passer à la grille';

  @override
  String get toastPhotoPickFailed =>
      'Impossible de sélectionner cette photo. Réessayez.';

  @override
  String get toastPendingPickFailed =>
      'La sélection interrompue n’a pas pu être récupérée.';

  @override
  String get toastSharedPhotoAdded => 'Photo partagée ajoutée.';

  @override
  String get toastSharedPhotoFailed =>
      'Impossible d’ajouter la photo partagée. Nous réessaierons.';

  @override
  String get toastDeleteFailed => 'Suppression impossible. Réessayez.';

  @override
  String get toastSaveFailed => 'Enregistrement impossible. Réessayez.';

  @override
  String get toastEditFailed => 'Impossible d’enregistrer les modifications.';

  @override
  String get toastPermissionDenied =>
      'Les notifications sont désactivées. Les rappels resteront silencieux.';

  @override
  String get deleteConfirmTitle => 'Supprimer cette capture ?';

  @override
  String get deleteConfirmCaption =>
      'La photo et sa note seront supprimées ensemble.';

  @override
  String get holdToDelete => 'Maintenir pour supprimer';

  @override
  String get holdStageAlmost => 'Presque';

  @override
  String get holdStageRelease => 'Maintenez encore…';

  @override
  String get holdStageGone => 'Supprimé';

  @override
  String get cameraNotFoundTitle => 'Caméra indisponible';

  @override
  String get cameraNotFoundBody =>
      'Aucune caméra n’est disponible sur cet appareil.';

  @override
  String get cameraDeniedTitle => 'Accès à la caméra désactivé';

  @override
  String get cameraDeniedBody =>
      'Autorisez l’accès dans Réglages › Latermark pour prendre des photos ici.';

  @override
  String get cameraFailedTitle => 'Impossible d’ouvrir la caméra';

  @override
  String get cameraFailedBody => 'Un problème inattendu est survenu.';

  @override
  String get switchLens => 'Changer de caméra';

  @override
  String flashSemantic(String state) {
    return 'Flash : $state';
  }

  @override
  String get flashOff => 'désactivé';

  @override
  String get flashAuto => 'automatique';

  @override
  String get flashOn => 'activé';

  @override
  String get composeHint => 'Pourquoi avez-vous pris cette photo ?';

  @override
  String get composeAnotherPhoto => 'Choisir une autre photo';

  @override
  String get composeRetake => 'Reprendre';

  @override
  String get sourceGallery => 'PHOTOS';

  @override
  String get sourceShared => 'PARTAGÉ';

  @override
  String get reminderLabel => 'Me rappeler';

  @override
  String get reminderSuffixActive => 'jours plus tard';

  @override
  String get reminderSuffixOff => 'jours — désactivé';

  @override
  String get reminderBlocked =>
      'Les notifications sont désactivées. La capture sera tout de même enregistrée ; le rappel fonctionnera dès que vous les autoriserez.';

  @override
  String get editNoteSemantic => 'Modifier la note';

  @override
  String get editSheetHeader => 'MODIFIER LA NOTE';

  @override
  String get retentionSelectorTitle => 'Suppression automatique';

  @override
  String get retentionOffNotice =>
      'La suppression automatique est désactivée — cette capture restera jusqu’à ce que vous la supprimiez.';

  @override
  String get retentionCustom => 'Personnalisée';

  @override
  String get retentionCustomTitle => 'Durée personnalisée';

  @override
  String retentionCustomHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count heures',
      one: '1 heure',
    );
    return '$_temp0';
  }

  @override
  String retentionCustomDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours',
      one: '1 jour',
    );
    return '$_temp0';
  }

  @override
  String retentionCustomWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count semaines',
      one: '1 semaine',
    );
    return '$_temp0';
  }

  @override
  String get retentionUnitHours => 'Heures';

  @override
  String get retentionUnitDays => 'Jours';

  @override
  String get retentionUnitWeeks => 'Semaines';

  @override
  String get retentionCustomDescription =>
      'Cette capture sera automatiquement supprimée à la fin de cette durée.';

  @override
  String get retentionOff => 'Désactivée';

  @override
  String get retentionThreeDays => '3 jours';

  @override
  String get retentionOneWeek => '1 semaine';

  @override
  String get retentionOffDescription => 'Désactivée';

  @override
  String get retentionThreeDaysDescription => 'Suppression après 3 jours';

  @override
  String get retentionOneWeekDescription => 'Suppression après 1 semaine';

  @override
  String get legalPrivacy => 'Confidentialité';

  @override
  String get legalTerms => 'Conditions d’utilisation';

  @override
  String get legalOpenFailed => 'Impossible d’ouvrir le lien.';

  @override
  String get settingsTitle => 'Réglages';

  @override
  String get sectionAppearance => 'Apparence';

  @override
  String get sectionReminder => 'Rappels';

  @override
  String get themeTitle => 'Thème';

  @override
  String get themeDescription =>
      'Suivez l’apparence du système ou choisissez-en une.';

  @override
  String get themeSystem => 'Système';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get retentionTitle => 'Suppression automatique';

  @override
  String get retentionDescription =>
      'Les nouvelles captures utilisent cette durée. Vous pouvez la modifier pour chacune depuis sa fiche.';

  @override
  String get feedTitle => 'Fil';

  @override
  String get feedDescription =>
      'Affichez de grandes captures ou davantage d’éléments dans une grille.';

  @override
  String get densityLarge => 'Grand';

  @override
  String get densityGrid => 'Grille';

  @override
  String get languageTitle => 'Langue';

  @override
  String get languageDescription =>
      'Latermark suit la langue de votre appareil. Vous pouvez aussi en choisir une autre.';

  @override
  String get languageSystem => 'Système';

  @override
  String get remindersTitle => 'Rappels';

  @override
  String get remindersDescription =>
      'Seules les captures auxquelles vous attribuez une échéance enverront une notification. Les autres resteront silencieuses.';

  @override
  String get remindersBlockedDescription =>
      'Les notifications sont désactivées dans les réglages système. Les rappels reprendront dès que vous les autoriserez.';

  @override
  String get openSystemSettings => 'Ouvrir les réglages système';

  @override
  String get openSettingsShort => 'Ouvrir les réglages';

  @override
  String versionMark(String version, String build) {
    return 'Version $version ($build)';
  }

  @override
  String get dayToday => 'Aujourd’hui';

  @override
  String get dayYesterday => 'Hier';

  @override
  String get relativeJustNow => 'à l’instant';

  @override
  String relativeMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min',
      one: '1 min',
    );
    return '$_temp0';
  }

  @override
  String relativeHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count h',
      one: '1 h',
    );
    return '$_temp0';
  }

  @override
  String get relativeYesterday => 'hier';

  @override
  String relativeDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours',
      one: '1 jour',
    );
    return '$_temp0';
  }

  @override
  String get remainingNow => 'maintenant';

  @override
  String remainingShortDays(int count) {
    return '$count j';
  }

  @override
  String remainingShortHours(int count) {
    return '$count h';
  }

  @override
  String remainingShortMinutes(int count) {
    return '$count min';
  }

  @override
  String get remainingShortLessThanMinute => '<1 min';

  @override
  String get remainingSoon => 'Suppression imminente';

  @override
  String remainingLongDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Suppression dans $days jours',
      one: 'Suppression dans 1 jour',
    );
    return '$_temp0';
  }

  @override
  String remainingLongDaysHours(int days, int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days jours',
      one: '1 jour',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours heures',
      one: '1 heure',
    );
    return 'Suppression dans $_temp0 et $_temp1';
  }

  @override
  String remainingLongHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'Suppression dans $hours heures',
      one: 'Suppression dans 1 heure',
    );
    return '$_temp0';
  }

  @override
  String remainingLongHoursMinutes(int hours, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours heures',
      one: '1 heure',
    );
    String _temp1 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
    );
    return 'Suppression dans $_temp0 et $_temp1';
  }

  @override
  String remainingLongMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Suppression dans $minutes minutes',
      one: 'Suppression dans 1 minute',
    );
    return '$_temp0';
  }

  @override
  String get paywallLimitTitle => 'Vos 10 emplacements sont occupés';

  @override
  String paywallLimitBody(int limit) {
    return 'La version gratuite conserve jusqu’à $limit captures à la fois. Pro supprime cette limite — ou vous pouvez effacer une capture pour continuer.';
  }

  @override
  String get paywallLimitDelete => 'Supprimer une capture';

  @override
  String paywallCounter(int count, int limit) {
    return '$count/$limit';
  }

  @override
  String get proBadge => 'PRO';

  @override
  String get paywallHeadline => 'Certaines images méritent de rester.';

  @override
  String get paywallSubtitle =>
      'Latermark est pensé pour laisser partir. Pro est là pour ce que vous souhaitez garder.';

  @override
  String paywallOwnedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vous avez actuellement $count captures.',
      one: 'Vous avez actuellement 1 capture.',
    );
    return '$_temp0';
  }

  @override
  String get paywallFeatureUnlimited => 'Captures illimitées';

  @override
  String paywallFeatureUnlimitedDetail(int limit) {
    return 'La version gratuite conserve jusqu’à $limit captures.';
  }

  @override
  String get paywallFeatureCustomRetention => 'Choisissez la durée';

  @override
  String get paywallFeatureCustomRetentionDetail =>
      'Au-delà de 3 jours et 1 semaine.';

  @override
  String get paywallFeatureReminders => 'Rappels';

  @override
  String get paywallFeatureRemindersDetail =>
      'Un rappel discret pour ce qui compte.';

  @override
  String get paywallFeatureWidget => 'Widgets d’accueil et d’écran verrouillé';

  @override
  String get paywallFeatureWidgetDetail =>
      'Votre dernière capture, toujours à portée de regard.';

  @override
  String paywallPrice(String price) {
    return '$price';
  }

  @override
  String get paywallOneTime => 'Achat unique';

  @override
  String get paywallNoSubscription =>
      'Sans abonnement. Un seul paiement, Pro pour toujours.';

  @override
  String get paywallFeatureNoSubscription => 'Sans abonnement';

  @override
  String get paywallFeatureNoSubscriptionDetail =>
      'La plupart des apps facturent chaque mois. Pas Latermark.';

  @override
  String get paywallCta => 'Débloquer Pro';

  @override
  String get paywallRestore => 'Restaurer les achats';

  @override
  String get paywallClose => 'Fermer';

  @override
  String get paywallLifeFree => 'Gratuit';

  @override
  String get paywallLifePro => 'Pro';

  @override
  String get notificationTitle => 'Rappel';

  @override
  String get notificationTitleNoBody => 'Une capture vous attend';

  @override
  String get notificationBodyNoBody =>
      'Vous aviez demandé un rappel pour cette capture.';

  @override
  String get notificationChannelName => 'Rappels';

  @override
  String get notificationChannelDescription =>
      'Vous rappelle les captures que vous avez programmées.';

  @override
  String get actionOK => 'OK';

  @override
  String get widgetDescription => 'Affiche votre dernière capture et sa note.';

  @override
  String get widgetEmptySubtitle => 'Votre première note apparaîtra ici';

  @override
  String get widgetPhotoDescription => 'Photo de votre dernière capture';

  @override
  String get widgetLeaveTrace => 'Laisser une nouvelle trace';

  @override
  String get widgetOpenApp => 'Ouvrir Latermark';

  @override
  String get widgetCreateNote => 'Créer une note';

  @override
  String get widgetLeaveFirstTrace => 'Laissez votre première trace';

  @override
  String get widgetProRequired =>
      'Les widgets sont disponibles avec Latermark Pro.';

  @override
  String get widgetPreviewNote => 'À envoyer à la comptabilité';

  @override
  String get widgetPreviewDay => 'AUJOURD’HUI';

  @override
  String get shareComposeHint => 'Pourquoi souhaitez-vous garder cette photo ?';

  @override
  String get shareErrorTitle => 'Impossible d’ajouter la photo';

  @override
  String get shareErrorBody =>
      'La photo n’a pas pu être envoyée à Latermark. Réessayez.';

  @override
  String get cameraUsageDescription =>
      'L’accès à la caméra permet de prendre des photos pour vos notes.';

  @override
  String get photoLibraryUsageDescription =>
      'L’accès aux photos permet d’ajouter des images de votre photothèque à vos notes.';
}
