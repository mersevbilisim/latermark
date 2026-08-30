// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class L10nIt extends L10n {
  L10nIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'Latermark';

  @override
  String get actionSave => 'Salva';

  @override
  String get composeSaving => 'Salvataggio';

  @override
  String get composeWaitingForLocation => 'Attendo la posizione';

  @override
  String get actionCancel => 'Annulla';

  @override
  String get actionClose => 'Chiudi';

  @override
  String get actionBack => 'Indietro';

  @override
  String get actionDelete => 'Elimina';

  @override
  String get actionEdit => 'Modifica';

  @override
  String get actionMore => 'Altro';

  @override
  String get openPhotoSemantic => 'Apri la foto a schermo intero';

  @override
  String get actionRetry => 'Riprova';

  @override
  String get actionGoBack => 'Torna indietro';

  @override
  String get actionOpen => 'Apri';

  @override
  String get settingsAction => 'Impostazioni';

  @override
  String get shutterSemantic => 'Scatta una foto';

  @override
  String get searchHint => 'Cerca';

  @override
  String searchResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count risultati',
      one: '$count risultato',
    );
    return '$_temp0';
  }

  @override
  String get searchEmpty => 'Nessun risultato';

  @override
  String get searchCancel => 'Annulla';

  @override
  String get searchInPhoto => 'nello scatto';

  @override
  String get notesTitle => 'Note';

  @override
  String get dateGroupToday => 'Oggi';

  @override
  String get dateGroupYesterday => 'Ieri';

  @override
  String get dateGroupPastWeek => 'Ultimi 7 giorni';

  @override
  String get dateGroupPastMonth => 'Ultimo mese';

  @override
  String get dateGroupPastThreeMonths => 'Ultimi 3 mesi';

  @override
  String get dateGroupPastYear => 'Ultimo anno';

  @override
  String get dateGroupOlder => 'Più di un anno fa';

  @override
  String noteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count note',
      one: '1 nota',
      zero: 'Nessuna nota',
    );
    return '$_temp0';
  }

  @override
  String get noteWithoutBody => 'Senza nota';

  @override
  String get inviteTitle => 'Tocca per scattare';

  @override
  String get inviteBody =>
      'Uno scontrino, un parcheggio, un dettaglio…\nScatta, aggiungi due parole e vai avanti.';

  @override
  String get pickFromGallery => 'Scegli da Foto';

  @override
  String get pickFromGallerySemantic => 'Scegli una foto dalla libreria';

  @override
  String get galleryPickerOpening => 'Apertura di Foto…';

  @override
  String get manifestoFirst => 'Semplice';

  @override
  String get manifestoSecond => 'Privato';

  @override
  String get manifestoThird => 'Tuo';

  @override
  String get switchToLargeView => 'Passa alla vista grande';

  @override
  String get switchToGridView => 'Passa alla griglia';

  @override
  String get toastPhotoPickFailed =>
      'Impossibile selezionare la foto. Riprova.';

  @override
  String get toastPendingPickFailed =>
      'Impossibile recuperare la selezione interrotta.';

  @override
  String get toastSharedPhotoAdded => 'Foto condivisa aggiunta.';

  @override
  String get toastSharedPhotoFailed =>
      'Impossibile aggiungere la foto condivisa. Riproveremo.';

  @override
  String get toastDeleteFailed => 'Impossibile eliminarlo. Riprova.';

  @override
  String get toastSaveFailed => 'Impossibile salvare. Riprova.';

  @override
  String get toastEditFailed => 'Impossibile salvare le modifiche.';

  @override
  String get toastPermissionDenied =>
      'Le notifiche sono disattivate: i promemoria resteranno in silenzio.';

  @override
  String get deleteConfirmTitle => 'Eliminare questo scatto?';

  @override
  String get deleteConfirmCaption =>
      'La foto e la nota verranno eliminate insieme.';

  @override
  String get holdToDelete => 'Tieni premuto per eliminare';

  @override
  String get holdStageAlmost => 'Ci siamo quasi';

  @override
  String get holdStageRelease => 'Continua a tenere premuto…';

  @override
  String get holdStageGone => 'Eliminato';

  @override
  String get selectionStart => 'Scegli gli scatti da eliminare';

  @override
  String get selectionExit => 'Esci dalla selezione';

  @override
  String get selectionTitle => 'Selezione';

  @override
  String selectionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selezionati',
      one: '1 selezionato',
      zero: 'Nessuna selezione',
    );
    return '$_temp0';
  }

  @override
  String get selectionHint => 'Tocca gli scatti che vuoi eliminare';

  @override
  String deleteManyConfirmTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Eliminare $count scatti?',
      one: 'Eliminare questo scatto?',
    );
    return '$_temp0';
  }

  @override
  String get deleteManyConfirmCaption =>
      'Le foto e le note verranno eliminate insieme.';

  @override
  String get cameraNotFoundTitle => 'Fotocamera non disponibile';

  @override
  String get cameraNotFoundBody =>
      'Questo dispositivo non dispone di una fotocamera.';

  @override
  String get cameraDeniedTitle => 'Accesso alla fotocamera disattivato';

  @override
  String get cameraDeniedBody =>
      'Consenti l’accesso in Impostazioni › Latermark per scattare foto.';

  @override
  String get cameraFailedTitle => 'Impossibile aprire la fotocamera';

  @override
  String get cameraFailedBody => 'Si è verificato un problema imprevisto.';

  @override
  String get switchLens => 'Cambia fotocamera';

  @override
  String flashSemantic(String state) {
    return 'Flash: $state';
  }

  @override
  String get flashOff => 'disattivato';

  @override
  String get flashAuto => 'automatico';

  @override
  String get flashOn => 'attivato';

  @override
  String get composeHint => 'Perché hai scattato questa foto?';

  @override
  String get composeReminderDescription =>
      'Ritrova questo scatto nel giorno che scegli.';

  @override
  String get composeLocationDescription =>
      'Associa la tua posizione attuale solo a questo scatto.';

  @override
  String get composeLocationResolving => 'Rilevamento della posizione…';

  @override
  String get composeLocationReady => 'La posizione è pronta per questo scatto.';

  @override
  String get composeLocationPermissionRequired =>
      'È richiesto il permesso per la posizione.';

  @override
  String get composeAnotherPhoto => 'Scegli un’altra foto';

  @override
  String get composeRetake => 'Scatta di nuovo';

  @override
  String get sourceGallery => 'FOTO';

  @override
  String get sourceShared => 'CONDIVISA';

  @override
  String get reminderLabel => 'Ricordamelo';

  @override
  String get addedLabel => 'Data di aggiunta';

  @override
  String get lastUpdatedLabel => 'Ultima modifica';

  @override
  String get locationLabel => 'Posizione';

  @override
  String get locationAddLabel => 'Aggiungi posizione';

  @override
  String get locationBlocked =>
      'L\'aggiunta della posizione dipende dal tuo permesso. Consenti l\'accesso alla posizione per registrare dove è stata scattata la foto.';

  @override
  String get compassNorth => 'N';

  @override
  String get compassSouth => 'S';

  @override
  String get compassEast => 'E';

  @override
  String get compassWest => 'O';

  @override
  String get toastMapFailed => 'Impossibile aprire Mappe';

  @override
  String get reminderSuffixActive => 'giorni da oggi';

  @override
  String get reminderSuffixOff => 'giorni — disattivato';

  @override
  String get backupSectionTitle => 'Backup';

  @override
  String get backupManageTitle => 'Gestisci backup';

  @override
  String get backupManageDescription =>
      'Crea una copia crittografata o ripristina un backup esistente.';

  @override
  String get backupCreateTitle => 'Crea un backup';

  @override
  String get backupNothingToSave => 'Non c’è ancora nulla da salvare.';

  @override
  String get backupCreateDescription =>
      'Tutto quello che hai in Latermark, in un unico file cifrato.';

  @override
  String get backupRestoreTitle => 'Ripristina un backup';

  @override
  String get backupRestoreDescription =>
      'Ripristina il tuo backup e riprendi tutte le note.';

  @override
  String get backupPasswordTitle => 'Scegli una password';

  @override
  String get backupPasswordSubtitle =>
      'Questa password è l’unica chiave del tuo backup.';

  @override
  String get backupPasswordLabel => 'Password';

  @override
  String get backupPasswordRepeat => 'Ripeti la password';

  @override
  String get backupPasswordMismatch => 'Le due password non coincidono.';

  @override
  String backupPasswordShort(int count) {
    return 'Usa almeno $count caratteri.';
  }

  @override
  String get backupStrengthWeak => 'Debole';

  @override
  String get backupStrengthFair => 'Media';

  @override
  String get backupStrengthStrong => 'Forte';

  @override
  String get backupLossWarning =>
      'Capisco che se perdo questa password, questo backup non potrà mai più essere aperto.';

  @override
  String get backupActionCreate => 'Crea backup';

  @override
  String get backupPhasePreparing => 'Preparazione';

  @override
  String get backupPhaseKey => 'Derivazione della chiave';

  @override
  String get backupPhaseWriting => 'Cifratura';

  @override
  String get backupPhaseReading => 'Decifratura';

  @override
  String get backupPhaseVerifying => 'Verifica';

  @override
  String get backupPhaseApplying => 'Ripristino';

  @override
  String backupItems(int done, int total) {
    return '$done di $total';
  }

  @override
  String get backupReadyTitle => 'Il tuo backup è pronto';

  @override
  String backupReadySubtitle(int notes, int photos) {
    return '$notes note e $photos foto, cifrate.';
  }

  @override
  String get backupActionSave => 'Salva su questo dispositivo';

  @override
  String get backupSavedToDevice => 'Salvato.';

  @override
  String get backupPickFile => 'Scegli un file';

  @override
  String get backupUnlockTitle => 'Inserisci la password';

  @override
  String get backupUnlockSubtitle =>
      'La password scelta quando hai creato questo backup.';

  @override
  String get backupFoundTitle => 'Backup trovato';

  @override
  String backupFoundCounts(int notes, int photos) {
    return '$notes note, $photos foto';
  }

  @override
  String backupFoundDate(String when) {
    return 'Creato il $when';
  }

  @override
  String get backupReplaceWarning =>
      'Il ripristino sostituisce tutte le note e le foto su questo dispositivo. Non è reversibile.';

  @override
  String get backupReplaceAcknowledge =>
      'Capisco che i miei dati attuali verranno eliminati.';

  @override
  String get backupActionRestore => 'Ripristina';

  @override
  String get backupRestoredTitle => 'È tornato tutto.';

  @override
  String get backupErrorWrongPassword => 'Password errata.';

  @override
  String get backupErrorNotABackup => 'Questo non è un backup di Latermark.';

  @override
  String get backupErrorCorrupt => 'Questo file è danneggiato o incompleto.';

  @override
  String get backupErrorUnsupported =>
      'Questo backup è stato creato da una versione più recente di Latermark.';

  @override
  String get backupErrorGeneric => 'Qualcosa è andato storto. Riprova.';

  @override
  String get paywallFeatureBackup => 'Backup sicuro';

  @override
  String get paywallFeatureBackupDetail =>
      'Porta note e foto su un nuovo telefono.';

  @override
  String get reminderSuffixRepeating => 'giorni · si ripete';

  @override
  String get reminderRepeatToggle => 'Ripeti promemoria';

  @override
  String get reminderRepeatOnce => 'Promemoria singolo.';

  @override
  String get reminderRepeatNeedsInterval =>
      'Inserisci prima il numero di giorni.';

  @override
  String reminderRepeatSummary(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Promemoria ogni $days giorni.',
      one: 'Promemoria ogni giorno.',
    );
    return '$_temp0';
  }

  @override
  String reminderDailyValue(String when) {
    return 'Ogni giorno · prossimo $when';
  }

  @override
  String reminderWeeklyValue(String when) {
    return 'Ogni settimana · prossimo $when';
  }

  @override
  String reminderMonthlyValue(String when) {
    return 'Ogni mese · prossimo $when';
  }

  @override
  String reminderYearlyValue(String when) {
    return 'Ogni anno · prossimo $when';
  }

  @override
  String get reminderCadenceOnce => 'Una volta';

  @override
  String get reminderCadenceDaily => 'Giorno';

  @override
  String get reminderCadenceWeekly => 'Settimana';

  @override
  String get reminderCadenceMonthly => 'Mese';

  @override
  String get reminderCadenceYearly => 'Anno';

  @override
  String get reminderBlocked =>
      'Le notifiche sono disattivate. Lo scatto verrà comunque salvato; il promemoria funzionerà non appena le riattiverai.';

  @override
  String get editNoteSemantic => 'Modifica nota';

  @override
  String get editSheetHeader => 'MODIFICA NOTA';

  @override
  String get retentionSelectorTitle => 'Eliminazione automatica';

  @override
  String get retentionOffNotice =>
      'L’eliminazione automatica è disattivata: lo scatto resterà finché non lo elimini.';

  @override
  String get retentionCustom => 'Personalizzata';

  @override
  String get retentionCustomTitle => 'Durata personalizzata';

  @override
  String retentionCustomHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ore',
      one: '1 ora',
    );
    return '$_temp0';
  }

  @override
  String retentionCustomDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count giorni',
      one: '1 giorno',
    );
    return '$_temp0';
  }

  @override
  String retentionCustomWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count settimane',
      one: '1 settimana',
    );
    return '$_temp0';
  }

  @override
  String get retentionUnitHours => 'Ore';

  @override
  String get retentionUnitDays => 'Giorni';

  @override
  String get retentionUnitWeeks => 'Settimane';

  @override
  String get retentionCustomDescription =>
      'Lo scatto verrà eliminato allo scadere del tempo.';

  @override
  String get retentionOff => 'Disattivata';

  @override
  String get retentionThreeDays => '3 giorni';

  @override
  String get retentionOneWeek => '1 settimana';

  @override
  String get retentionOffDescription => 'Disattivata';

  @override
  String get retentionThreeDaysDescription => 'Elimina dopo 3 giorni';

  @override
  String get retentionOneWeekDescription => 'Elimina dopo 1 settimana';

  @override
  String get legalPrivacy => 'Privacy';

  @override
  String get legalTerms => 'Condizioni d’uso';

  @override
  String get yourDataTitle => 'Latermark e i tuoi dati';

  @override
  String get yourDataSubtitle =>
      'La tua privacy conta. E la trattiamo con il rispetto che merita.';

  @override
  String get yourDataSafetyQuestion => 'I miei dati sono al sicuro?';

  @override
  String get yourDataSafetyAnswer =>
      'Latermark funziona interamente sul tuo dispositivo. Note e ricordi non vengono inviati per analisi, segnalazioni di errori o statistiche. Lasciano il dispositivo solo quando scegli tu di condividerli.';

  @override
  String get yourDataLocationQuestion =>
      'Perché Latermark richiede l’accesso alla posizione?';

  @override
  String get yourDataLocationAnswer =>
      'L’autorizzazione viene richiesta solo se scegli di aggiungere un luogo a una nota o a un ricordo. La posizione resta associata solo a quell’elemento, senza tracciamento in background. Passa all’app Mappe solo se decidi di aprire la mappa.';

  @override
  String get yourDataPhotosQuestion => 'Come viene usato l’accesso alle foto?';

  @override
  String get yourDataPhotosAnswer =>
      'Serve solo a permetterti di scegliere un’immagine dalla libreria invece di scattarne una nuova. Latermark importa unicamente l’immagine selezionata e non richiede una connessione a internet.';

  @override
  String get yourDataRemindersQuestion => 'Come funzionano i promemoria?';

  @override
  String get yourDataRemindersAnswer =>
      'Vengono programmati e mostrati localmente sul tuo dispositivo. Nessun server esterno li invia o li attiva.';

  @override
  String get yourDataDeletionQuestion => 'Cosa succede se elimino l’app?';

  @override
  String get yourDataDeletionAnswer =>
      'Note, immagini importate e posizioni salvate in Latermark vengono eliminate definitivamente. Le foto nella tua libreria e i dati delle altre app restano intatti.';

  @override
  String get legalOpenFailed => 'Impossibile aprire il link.';

  @override
  String get settingsTitle => 'Impostazioni';

  @override
  String get sectionAppearance => 'Aspetto';

  @override
  String get sectionReminder => 'Promemoria';

  @override
  String get sectionSharing => 'Condivisione';

  @override
  String get shareSignatureTitle => 'Firma di condivisione';

  @override
  String get shareSignatureDescription =>
      'Le note che condividi finiscono con una riga che nomina Latermark. Se la disattivi, il tuo testo parte così com’è.';

  @override
  String shareSignature(String platform) {
    return 'Inviato con Latermark per $platform';
  }

  @override
  String get themeTitle => 'Tema';

  @override
  String get themeDescription =>
      'Segui l’aspetto del sistema oppure scegline uno fisso.';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Chiaro';

  @override
  String get themeDark => 'Scuro';

  @override
  String get appColorTitle => 'Colore dell’app';

  @override
  String get appColorDescription =>
      'Scegli il colore principale per controlli ed elementi in evidenza.';

  @override
  String get accentOrange => 'Arancione';

  @override
  String get accentBlue => 'Blu';

  @override
  String get accentViolet => 'Viola';

  @override
  String get accentPink => 'Rosa';

  @override
  String get accentGreen => 'Verde';

  @override
  String get accentGold => 'Oro';

  @override
  String get retentionTitle => 'Eliminazione automatica';

  @override
  String get retentionDescription =>
      'I nuovi scatti useranno questa durata. Puoi cambiarla per ogni scatto dalla vista di dettaglio.';

  @override
  String get feedTitle => 'Raccolta';

  @override
  String get feedDescription =>
      'Mostra scatti più grandi oppure più elementi in una griglia.';

  @override
  String get densityLarge => 'Grande';

  @override
  String get densityGrid => 'Griglia';

  @override
  String get languageTitle => 'Lingua';

  @override
  String get languageDescription =>
      'Latermark segue la lingua del dispositivo, oppure puoi sceglierne un’altra.';

  @override
  String get languageSystem => 'Sistema';

  @override
  String get remindersTitle => 'Promemoria';

  @override
  String get remindersDescription =>
      'Riceverai una notifica solo per gli scatti programmati durante il salvataggio. Tutto il resto resta in silenzio.';

  @override
  String get remindersBlockedDescription =>
      'Le notifiche sono disattivate nelle impostazioni di sistema. I promemoria riprenderanno quando le riattiverai.';

  @override
  String get openSystemSettings => 'Apri le impostazioni di sistema';

  @override
  String get openSettingsShort => 'Apri Impostazioni';

  @override
  String versionMark(String version, String build) {
    return 'Versione $version ($build)';
  }

  @override
  String get dayToday => 'Oggi';

  @override
  String get dayYesterday => 'Ieri';

  @override
  String get relativeJustNow => 'ora';

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
      other: '$count ore',
      one: '1 ora',
    );
    return '$_temp0';
  }

  @override
  String get relativeYesterday => 'ieri';

  @override
  String relativeDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count giorni',
      one: '1 giorno',
    );
    return '$_temp0';
  }

  @override
  String get remainingNow => 'ora';

  @override
  String remainingShortDays(int count) {
    return '$count g';
  }

  @override
  String remainingShortHours(int count) {
    return '$count h';
  }

  @override
  String remainingShortMinutes(int count) {
    return '$count min';
  }

  @override
  String get remainingShortLessThanMinute => '<1 min';

  @override
  String get remainingSoon => 'Eliminazione a breve';

  @override
  String remainingLongDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Eliminazione tra $days giorni',
      one: 'Eliminazione tra 1 giorno',
    );
    return '$_temp0';
  }

  @override
  String remainingLongDaysHours(int days, int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days giorni',
      one: '1 giorno',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours ore',
      one: '1 ora',
    );
    return 'Eliminazione tra $_temp0 e $_temp1';
  }

  @override
  String remainingLongHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'Eliminazione tra $hours ore',
      one: 'Eliminazione tra 1 ora',
    );
    return '$_temp0';
  }

  @override
  String remainingLongHoursMinutes(int hours, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours ore',
      one: '1 ora',
    );
    String _temp1 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minuti',
      one: '1 minuto',
    );
    return 'Eliminazione tra $_temp0 e $_temp1';
  }

  @override
  String remainingLongMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Eliminazione tra $minutes minuti',
      one: 'Eliminazione tra 1 minuto',
    );
    return '$_temp0';
  }

  @override
  String paywallLimitTitle(int limit) {
    return 'Hai riempito tutti e $limit gli spazi';
  }

  @override
  String paywallLimitBody(int limit) {
    return 'La versione gratuita conserva fino a $limit scatti alla volta. Pro rimuove il limite — oppure elimina uno scatto per continuare.';
  }

  @override
  String get paywallLimitDelete => 'Elimina uno scatto';

  @override
  String paywallCounter(int count, int limit) {
    return '$count/$limit';
  }

  @override
  String get proBadge => 'PRO';

  @override
  String get paywallHeadline => 'Non lasciare indietro ciò che conta.';

  @override
  String get paywallSubtitle =>
      'Latermark Pro ti riporta davanti tutto quello a cui vorrai tornare, al momento giusto.';

  @override
  String paywallOwnedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Al momento hai $count scatti.',
      one: 'Al momento hai 1 scatto.',
    );
    return '$_temp0';
  }

  @override
  String get paywallFeatureUnlimited => 'Note illimitate';

  @override
  String paywallFeatureUnlimitedDetail(int limit) {
    return 'Non $limit: davvero illimitate.';
  }

  @override
  String get paywallFeatureCustomRetention => 'Scegli qualsiasi durata';

  @override
  String get paywallFeatureCustomRetentionDetail =>
      'Non fermarti a 3 giorni o 1 settimana.';

  @override
  String get paywallFeatureReminders => 'Promemoria';

  @override
  String get paywallFeatureRemindersDetail =>
      'Te lo ricorda esattamente quando serve.';

  @override
  String get paywallFeatureWidget => 'Widget per Home e schermata di blocco';

  @override
  String get paywallFeatureWidgetDetail =>
      'Il tuo ultimo scatto, sempre a colpo d’occhio.';

  @override
  String paywallPrice(String price) {
    return '$price';
  }

  @override
  String get paywallOneTime => 'Acquisto una tantum';

  @override
  String get paywallNoSubscription =>
      'Nessun abbonamento. Paghi una volta, Pro resta tuo.';

  @override
  String get paywallOwned => 'Latermark Pro è tuo.';

  @override
  String get paywallFeatureNoSubscription => 'Nessun abbonamento';

  @override
  String get paywallFeatureNoSubscriptionDetail =>
      'Latermark non richiede abbonamenti. È tuo per sempre.';

  @override
  String get paywallCta => 'Sblocca Pro';

  @override
  String get paywallRestore => 'Ripristina acquisti';

  @override
  String get paywallRestoreNotFound =>
      'Non è stato trovato alcun acquisto precedente di Latermark Pro.';

  @override
  String get paywallRestoreFailed =>
      'Impossibile ripristinare gli acquisti. Riprova.';

  @override
  String get paywallClose => 'Chiudi';

  @override
  String get paywallLifeFree => 'Gratis';

  @override
  String get paywallLifePro => 'Pro';

  @override
  String get notificationTitle => 'Promemoria';

  @override
  String get notificationTitleNoBody => 'C’è uno scatto che ti aspetta';

  @override
  String get notificationBodyNoBody =>
      'Hai chiesto a Latermark di ricordarti questo scatto.';

  @override
  String get notificationChannelName => 'Promemoria';

  @override
  String get notificationChannelDescription =>
      'Promemoria per gli scatti che hai programmato.';

  @override
  String get reminderActionDone => 'Fatto';

  @override
  String get reminderActionTomorrow => 'Domani';

  @override
  String get reminderActionNextWeek => 'La prossima settimana';

  @override
  String get reminderActionTurnOff => 'Disattiva questo promemoria';

  @override
  String get actionOK => 'OK';

  @override
  String get widgetDescription =>
      'Mostra il tuo ultimo scatto e la relativa nota.';

  @override
  String get widgetEmptySubtitle => 'La tua prima nota apparirà qui';

  @override
  String get widgetPhotoDescription => 'Foto del tuo ultimo scatto';

  @override
  String get widgetLeaveTrace => 'Lascia una nuova traccia';

  @override
  String get widgetOpenApp => 'Apri Latermark';

  @override
  String get widgetCreateNote => 'Crea una nuova nota';

  @override
  String get widgetLeaveFirstTrace => 'Lascia la tua prima traccia';

  @override
  String get widgetProRequired =>
      'I widget sono disponibili con Latermark Pro.';

  @override
  String get widgetPreviewNote => 'Da inviare in contabilità';

  @override
  String get widgetPreviewDay => 'OGGI';

  @override
  String get shareComposeHint => 'Perché vuoi conservare questa foto?';

  @override
  String get shareErrorTitle => 'Impossibile aggiungere la foto';

  @override
  String get shareErrorBody =>
      'Impossibile inviare la foto a Latermark. Riprova.';

  @override
  String get cameraUsageDescription =>
      'Latermark usa la fotocamera per scattare foto da aggiungere alle tue note.';

  @override
  String get photoLibraryUsageDescription =>
      'L’accesso a Foto serve per aggiungere alle note le immagini della tua libreria.';

  @override
  String get actionShare => 'Condividi';

  @override
  String get shareNoteSemantic => 'Condividi foto e nota';

  @override
  String get reminderSwitchLabel => 'Ricordamelo';

  @override
  String get actionSaveAndRemind => 'Salva e ricorda';

  @override
  String get reminderScheduleSaved => 'Salvato';

  @override
  String get reminderScheduleQuestion => 'Quando deve tornare questo scatto?';

  @override
  String get reminderTimeLabel => 'Ora';

  @override
  String get reminderSkip => 'Non ora';

  @override
  String get reminderDeleteAfterLabel => 'Elimina 1 ora dopo il promemoria';

  @override
  String get reminderAfterExpiry =>
      'Il promemoria deve precedere l’eliminazione di questa nota.';
}
