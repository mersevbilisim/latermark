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
  String get composeSaving => 'Enregistrement';

  @override
  String get composeWaitingForLocation => 'Localisation en cours';

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
  String get actionMore => 'Plus';

  @override
  String get openPhotoSemantic => 'Ouvrir la photo en plein écran';

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
  String get searchHint => 'Rechercher';

  @override
  String searchResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count résultats',
      one: '$count résultat',
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
  String get dateGroupToday => 'Aujourd’hui';

  @override
  String get dateGroupYesterday => 'Hier';

  @override
  String get dateGroupPastWeek => '7 derniers jours';

  @override
  String get dateGroupPastMonth => 'Mois dernier';

  @override
  String get dateGroupPastThreeMonths => '3 derniers mois';

  @override
  String get dateGroupPastYear => 'Année passée';

  @override
  String get dateGroupOlder => 'Il y a plus d’un an';

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
  String get toastQueuedNoteAdded => 'Note ajoutée.';

  @override
  String get toastQueuedNoteReminderDropped =>
      'Note ajoutée, mais le rappel tombait après la date de suppression de la note.';

  @override
  String get toastQueuedNoteFailed =>
      'Impossible d’ajouter la note. Nous réessaierons.';

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
  String get selectionStart => 'Choisir des vues à supprimer';

  @override
  String get selectionExit => 'Quitter la sélection';

  @override
  String get selectionTitle => 'Sélection';

  @override
  String selectionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sélectionnées',
      one: '1 sélectionnée',
      zero: 'Aucune sélection',
    );
    return '$_temp0';
  }

  @override
  String get selectionHint => 'Touchez les vues que vous voulez supprimer';

  @override
  String deleteManyConfirmTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Supprimer $count vues ?',
      one: 'Supprimer cette vue ?',
    );
    return '$_temp0';
  }

  @override
  String get deleteManyConfirmCaption =>
      'Les photos et les notes seront supprimées ensemble.';

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
  String get composeReminderDescription =>
      'Retrouvez cette capture le jour de votre choix.';

  @override
  String get composeLocationDescription =>
      'Associe votre position actuelle à cette seule capture.';

  @override
  String get composeLocationResolving => 'Localisation en cours…';

  @override
  String get composeLocationReady => 'Le lieu est prêt pour cette capture.';

  @override
  String get composeLocationPermissionRequired =>
      'Autorisation de localisation requise.';

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
  String get addedLabel => 'Date d\'ajout';

  @override
  String get lastUpdatedLabel => 'Dernière modification';

  @override
  String get locationLabel => 'Lieu';

  @override
  String get locationAddLabel => 'Ajouter le lieu';

  @override
  String get locationBlocked =>
      'L\'ajout du lieu dépend de votre autorisation. Autorisez l\'accès à la localisation pour enregistrer où la photo a été prise.';

  @override
  String get compassNorth => 'N';

  @override
  String get compassSouth => 'S';

  @override
  String get compassEast => 'E';

  @override
  String get compassWest => 'O';

  @override
  String get toastMapFailed => 'Impossible d\'ouvrir Plans';

  @override
  String get reminderSuffixActive => 'jours plus tard';

  @override
  String get reminderSuffixOff => 'jours — désactivé';

  @override
  String get backupSectionTitle => 'Sauvegarde';

  @override
  String get backupManageTitle => 'Gérer les sauvegardes';

  @override
  String get backupManageDescription =>
      'Crée une copie chiffrée ou restaure une sauvegarde existante.';

  @override
  String get backupCreateTitle => 'Créer une sauvegarde';

  @override
  String get backupNothingToSave => 'Il n’y a encore rien à sauvegarder.';

  @override
  String get backupCreateDescription =>
      'Tout ce que contient votre Latermark, dans un seul fichier chiffré.';

  @override
  String get backupRestoreTitle => 'Restaurer une sauvegarde';

  @override
  String get backupRestoreDescription =>
      'Restaurez votre sauvegarde et récupérez toutes vos notes.';

  @override
  String get backupPasswordTitle => 'Choisis un mot de passe';

  @override
  String get backupPasswordSubtitle =>
      'Ce mot de passe est la seule clé de ta sauvegarde.';

  @override
  String get backupPasswordLabel => 'Mot de passe';

  @override
  String get backupPasswordRepeat => 'Répète le mot de passe';

  @override
  String get backupPasswordMismatch =>
      'Les deux mots de passe ne correspondent pas.';

  @override
  String backupPasswordShort(int count) {
    return 'Utilise au moins $count caractères.';
  }

  @override
  String get backupStrengthWeak => 'Faible';

  @override
  String get backupStrengthFair => 'Moyen';

  @override
  String get backupStrengthStrong => 'Fort';

  @override
  String get backupLossWarning =>
      'Je comprends que si je perds ce mot de passe, cette sauvegarde ne pourra plus jamais être ouverte.';

  @override
  String get backupActionCreate => 'Créer la sauvegarde';

  @override
  String get backupPhasePreparing => 'Préparation';

  @override
  String get backupPhaseKey => 'Dérivation de la clé';

  @override
  String get backupPhaseWriting => 'Chiffrement';

  @override
  String get backupPhaseReading => 'Déchiffrement';

  @override
  String get backupPhaseVerifying => 'Vérification';

  @override
  String get backupPhaseApplying => 'Restauration';

  @override
  String backupItems(int done, int total) {
    return '$done sur $total';
  }

  @override
  String get backupReadyTitle => 'Ta sauvegarde est prête';

  @override
  String backupReadySubtitle(int notes, int photos) {
    return '$notes notes et $photos photos, chiffrées.';
  }

  @override
  String get backupActionSave => 'Enregistrer sur cet appareil';

  @override
  String get backupSavedToDevice => 'Enregistré.';

  @override
  String get backupPickFile => 'Choisir un fichier';

  @override
  String get backupUnlockTitle => 'Saisis le mot de passe';

  @override
  String get backupUnlockSubtitle =>
      'Le mot de passe choisi lors de la création de cette sauvegarde.';

  @override
  String get backupFoundTitle => 'Sauvegarde trouvée';

  @override
  String backupFoundCounts(int notes, int photos) {
    return '$notes notes, $photos photos';
  }

  @override
  String backupFoundDate(String when) {
    return 'Créée le $when';
  }

  @override
  String get backupReplaceWarning =>
      'La restauration remplace toutes les notes et photos de cet appareil. C’est irréversible.';

  @override
  String get backupReplaceAcknowledge =>
      'Je comprends que mes données actuelles seront supprimées.';

  @override
  String get backupActionRestore => 'Restaurer';

  @override
  String get backupRestoredTitle => 'Tout est revenu.';

  @override
  String get backupErrorWrongPassword => 'Mot de passe incorrect.';

  @override
  String get backupErrorNotABackup => 'Ce n’est pas une sauvegarde Latermark.';

  @override
  String get backupErrorCorrupt => 'Ce fichier est endommagé ou incomplet.';

  @override
  String get backupErrorUnsupported =>
      'Cette sauvegarde vient d’une version plus récente de Latermark.';

  @override
  String get backupErrorGeneric => 'Une erreur est survenue. Réessaie.';

  @override
  String get paywallFeatureBackup => 'Sauvegarde sécurisée';

  @override
  String get paywallFeatureBackupDetail =>
      'Emporte tes notes et tes photos sur un nouveau téléphone.';

  @override
  String get reminderSuffixRepeating => 'jours · répété';

  @override
  String get reminderRepeatToggle => 'Répéter le rappel';

  @override
  String get reminderRepeatOnce => 'Rappelé une seule fois.';

  @override
  String get reminderRepeatNeedsInterval =>
      'Saisissez d’abord le nombre de jours.';

  @override
  String reminderRepeatSummary(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Rappelé tous les $days jours.',
      one: 'Rappelé chaque jour.',
    );
    return '$_temp0';
  }

  @override
  String reminderDailyValue(String when) {
    return 'Chaque jour · prochain $when';
  }

  @override
  String reminderWeeklyValue(String when) {
    return 'Chaque semaine · prochain $when';
  }

  @override
  String reminderMonthlyValue(String when) {
    return 'Chaque mois · prochain $when';
  }

  @override
  String reminderYearlyValue(String when) {
    return 'Chaque année · prochain $when';
  }

  @override
  String get reminderCadenceOnce => 'Une fois';

  @override
  String get reminderCadenceDaily => 'Jour';

  @override
  String get reminderCadenceWeekly => 'Semaine';

  @override
  String get reminderCadenceMonthly => 'Mois';

  @override
  String get reminderCadenceYearly => 'An';

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
  String get yourDataTitle => 'Latermark et vos données';

  @override
  String get yourDataSubtitle =>
      'Votre vie privée compte. Nous la traitons avec tout le respect qu’elle mérite.';

  @override
  String get yourDataSafetyQuestion => 'Mes données sont-elles en sécurité ?';

  @override
  String get yourDataSafetyAnswer =>
      'Latermark fonctionne entièrement sur votre appareil. Vos notes et souvenirs ne sont transmis à aucun service d’analyse, de rapport d’erreurs ou de statistiques. Ils ne quittent l’appareil que lorsque vous choisissez de les partager. Pour la mesure publicitaire, seules deux informations sont transmises à Meta : l’installation de l’application et la réalisation d’un achat. Ni l’une ni l’autre ne contient ce que vous écrivez, photographiez ou localisez.';

  @override
  String get yourDataLocationQuestion =>
      'Pourquoi Latermark demande-t-il l’accès à ma position ?';

  @override
  String get yourDataLocationAnswer =>
      'Cette autorisation n’est demandée que si vous choisissez d’ajouter un lieu à une note ou à un souvenir. La position reste associée à cette seule entrée, sans suivi en arrière-plan. Elle n’est transmise à votre app de cartes que si vous ouvrez la carte.';

  @override
  String get yourDataPhotosQuestion => 'À quoi sert l’accès à mes photos ?';

  @override
  String get yourDataPhotosAnswer =>
      'Uniquement à vous permettre de choisir une image dans votre photothèque plutôt que d’en prendre une nouvelle. Latermark n’importe que l’image sélectionnée, sans nécessiter de connexion à Internet.';

  @override
  String get yourDataRemindersQuestion => 'Comment fonctionnent les rappels ?';

  @override
  String get yourDataRemindersAnswer =>
      'Ils sont programmés et affichés localement sur votre appareil. Aucun serveur externe ne les envoie ni ne les déclenche.';

  @override
  String get yourDataDeletionQuestion =>
      'Que se passe-t-il si je supprime l’app ?';

  @override
  String get yourDataDeletionAnswer =>
      'Les notes, images importées et positions enregistrées dans Latermark sont supprimées définitivement. Les photos de votre photothèque et les données des autres apps restent intactes.';

  @override
  String get legalOpenFailed => 'Impossible d’ouvrir le lien.';

  @override
  String get settingsTitle => 'Réglages';

  @override
  String get sectionAppearance => 'Apparence';

  @override
  String get sectionReminder => 'Rappels';

  @override
  String get sectionSharing => 'Partage';

  @override
  String get shareSignatureTitle => 'Signature de partage';

  @override
  String get shareSignatureDescription =>
      'Les notes partagées se terminent par une ligne mentionnant Latermark. Désactivée, votre texte part tel quel.';

  @override
  String shareSignature(String platform) {
    return 'Envoyé avec Latermark pour $platform';
  }

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
  String get appColorTitle => 'Couleur de l’app';

  @override
  String get appColorDescription =>
      'Choisissez la couleur d’accentuation des commandes et des éléments mis en avant.';

  @override
  String get accentOrange => 'Orange';

  @override
  String get accentBlue => 'Bleu';

  @override
  String get accentViolet => 'Violet';

  @override
  String get accentPink => 'Rose';

  @override
  String get accentGreen => 'Vert';

  @override
  String get accentGold => 'Or';

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
  String paywallLimitTitle(int limit) {
    return 'Vos $limit emplacements sont occupés';
  }

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
  String get paywallHeadline => 'Ne laissez pas l’essentiel derrière vous.';

  @override
  String get paywallSubtitle =>
      'Latermark Pro fait revenir tout ce que vous voudrez retrouver, au bon moment.';

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
  String get paywallFeatureUnlimited => 'Notes illimitées';

  @override
  String paywallFeatureUnlimitedDetail(int limit) {
    return 'Pas $limit : totalement illimitées.';
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
      'Vous le rappelle exactement quand il le faut.';

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
  String get paywallOwned => 'Latermark Pro est à vous.';

  @override
  String get paywallFeatureNoSubscription => 'Sans abonnement';

  @override
  String get paywallFeatureNoSubscriptionDetail =>
      'Latermark ne demande aucun abonnement. C’est à vous pour toujours.';

  @override
  String get paywallCta => 'Débloquer Pro';

  @override
  String get paywallRestore => 'Restaurer les achats';

  @override
  String get paywallRestoreNotFound =>
      'Aucun achat antérieur de Latermark Pro n’a été trouvé.';

  @override
  String get paywallRestoreFailed =>
      'Impossible de restaurer les achats. Réessayez.';

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
  String get reminderActionDone => 'Terminé';

  @override
  String get reminderActionTomorrow => 'Demain';

  @override
  String get reminderActionNextWeek => 'La semaine prochaine';

  @override
  String get reminderActionTurnOff => 'Désactiver ce rappel';

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

  @override
  String get actionShare => 'Partager';

  @override
  String get shareNoteSemantic => 'Partager la photo et la note';

  @override
  String get reminderSwitchLabel => 'Rappelez-le-moi';

  @override
  String get actionSaveAndRemind => 'Enregistrer et rappeler';

  @override
  String get reminderScheduleSaved => 'Enregistré';

  @override
  String get reminderScheduleQuestion =>
      'Quand cette image doit-elle revenir ?';

  @override
  String get reminderTimeLabel => 'Heure';

  @override
  String get reminderSkip => 'Pas maintenant';

  @override
  String get reminderDeleteAfterLabel => 'Supprimer 1 heure après le rappel';

  @override
  String get reminderAfterExpiry =>
      'Le rappel doit précéder la suppression de cette note.';

  @override
  String get keepOriginalLabel => 'Enregistrer l’original';

  @override
  String get keepOriginalDetail => 'Qualité intacte, occupe plus d’espace.';

  @override
  String get originalMark => 'Original';

  @override
  String get composeLocationFailed => 'Position indisponible';

  @override
  String get locationFixFailed =>
      'L’appareil n’a pas pu déterminer la position. La note sera enregistrée sans lieu.';

  @override
  String get composeTextEntry => 'Écrire un texte';

  @override
  String get addEntry => 'Ajouter une note';

  @override
  String get composeTextHint => 'De quoi voulez-vous vous souvenir ?';
}
