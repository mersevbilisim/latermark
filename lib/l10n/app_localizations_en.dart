// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class L10nEn extends L10n {
  L10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Latermark';

  @override
  String get actionSave => 'Save';

  @override
  String get composeSaving => 'Saving';

  @override
  String get composeWaitingForLocation => 'Waiting for location';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionClose => 'Close';

  @override
  String get actionBack => 'Back';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionMore => 'More';

  @override
  String get openPhotoSemantic => 'Open photo full screen';

  @override
  String get actionRetry => 'Try again';

  @override
  String get actionGoBack => 'Go Back';

  @override
  String get actionOpen => 'Open';

  @override
  String get settingsAction => 'Settings';

  @override
  String get shutterSemantic => 'Take a photo';

  @override
  String get searchHint => 'Search';

  @override
  String searchResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '$count result',
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
  String get dateGroupToday => 'Today';

  @override
  String get dateGroupYesterday => 'Yesterday';

  @override
  String get dateGroupPastWeek => 'Past week';

  @override
  String get dateGroupPastMonth => 'Past month';

  @override
  String get dateGroupPastThreeMonths => 'Past 3 months';

  @override
  String get dateGroupPastYear => 'Past year';

  @override
  String get dateGroupOlder => 'More than a year ago';

  @override
  String noteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes',
      one: '1 note',
      zero: 'No notes',
    );
    return '$_temp0';
  }

  @override
  String get noteWithoutBody => 'Untitled note';

  @override
  String get inviteTitle => 'Tap to capture';

  @override
  String get inviteBody =>
      'A receipt, a parking spot, a detail…\nTake a photo, add a few words, move on.';

  @override
  String get pickFromGallery => 'Choose from Photos';

  @override
  String get pickFromGallerySemantic => 'Choose a photo from your library';

  @override
  String get galleryPickerOpening => 'Opening photo picker';

  @override
  String get manifestoFirst => 'Simple';

  @override
  String get manifestoSecond => 'Private';

  @override
  String get manifestoThird => 'Yours';

  @override
  String get switchToLargeView => 'Switch to large view';

  @override
  String get switchToGridView => 'Switch to grid view';

  @override
  String get toastPhotoPickFailed =>
      'That photo couldn’t be selected. Try again.';

  @override
  String get toastPendingPickFailed =>
      'The interrupted photo selection couldn’t be recovered.';

  @override
  String get toastSharedPhotoAdded => 'Shared photo added.';

  @override
  String get toastSharedPhotoFailed =>
      'The shared photo couldn’t be added. We’ll try again.';

  @override
  String get toastQueuedNoteAdded => 'Note added.';

  @override
  String get toastQueuedNoteReminderDropped =>
      'Note added, but its reminder fell after the note’s deletion time.';

  @override
  String get toastQueuedNoteFailed =>
      'The note couldn’t be added. We’ll try again.';

  @override
  String get toastDeleteFailed => 'Couldn’t delete it. Try again.';

  @override
  String get toastSaveFailed => 'Couldn’t save it. Try again.';

  @override
  String get toastEditFailed => 'Your changes couldn’t be saved.';

  @override
  String get toastPermissionDenied =>
      'Notifications are off, so reminders will stay silent.';

  @override
  String get deleteConfirmTitle => 'Delete this frame?';

  @override
  String get deleteConfirmCaption =>
      'The photo and note will be deleted together.';

  @override
  String get holdToDelete => 'Press and hold to delete';

  @override
  String get holdStageAlmost => 'Almost there';

  @override
  String get holdStageRelease => 'Keep holding…';

  @override
  String get holdStageGone => 'Gone';

  @override
  String get selectionStart => 'Select frames to delete';

  @override
  String get selectionExit => 'Leave selection';

  @override
  String get selectionTitle => 'Select';

  @override
  String selectionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
      zero: 'None selected',
    );
    return '$_temp0';
  }

  @override
  String get selectionHint => 'Tap the frames you want to delete';

  @override
  String deleteManyConfirmTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count frames?',
      one: 'Delete this frame?',
    );
    return '$_temp0';
  }

  @override
  String get deleteManyConfirmCaption =>
      'The photos and notes will be deleted together.';

  @override
  String get cameraNotFoundTitle => 'Camera unavailable';

  @override
  String get cameraNotFoundBody => 'No camera is available on this device.';

  @override
  String get cameraDeniedTitle => 'Camera access is off';

  @override
  String get cameraDeniedBody =>
      'Allow camera access in Settings › Latermark to take photos here.';

  @override
  String get cameraFailedTitle => 'Couldn’t open the camera';

  @override
  String get cameraFailedBody => 'Something unexpected happened.';

  @override
  String get switchLens => 'Switch camera';

  @override
  String flashSemantic(String state) {
    return 'Flash: $state';
  }

  @override
  String get flashOff => 'off';

  @override
  String get flashAuto => 'auto';

  @override
  String get flashOn => 'on';

  @override
  String get composeHint => 'Why did you capture this?';

  @override
  String get composeReminderDescription =>
      'Bring this frame back on the day you choose.';

  @override
  String get composeLocationDescription =>
      'Attach your current location only to this frame.';

  @override
  String get composeLocationResolving => 'Finding your location…';

  @override
  String get composeLocationReady => 'Location is ready for this frame.';

  @override
  String get composeLocationPermissionRequired =>
      'Location permission is required.';

  @override
  String get composeAnotherPhoto => 'Choose another photo';

  @override
  String get composeRetake => 'Retake';

  @override
  String get sourceGallery => 'PHOTOS';

  @override
  String get sourceShared => 'SHARED';

  @override
  String get reminderLabel => 'Remind me';

  @override
  String get addedLabel => 'Date added';

  @override
  String get lastUpdatedLabel => 'Last updated';

  @override
  String get locationLabel => 'Location';

  @override
  String get locationAddLabel => 'Add location';

  @override
  String get locationBlocked =>
      'Adding the location depends on your permission. Allow location access to tag where a photo was taken.';

  @override
  String get compassNorth => 'N';

  @override
  String get compassSouth => 'S';

  @override
  String get compassEast => 'E';

  @override
  String get compassWest => 'W';

  @override
  String get toastMapFailed => 'Could not open Maps';

  @override
  String get reminderSuffixActive => 'days from now';

  @override
  String get reminderSuffixOff => 'days — off';

  @override
  String get backupSectionTitle => 'Backup';

  @override
  String get backupManageTitle => 'Backup operations';

  @override
  String get backupManageDescription =>
      'Create an encrypted copy or bring an existing backup back.';

  @override
  String get backupCreateTitle => 'Create a backup';

  @override
  String get backupNothingToSave => 'There’s nothing to back up yet.';

  @override
  String get backupCreateDescription =>
      'Everything in your Latermark, in one encrypted file.';

  @override
  String get backupRestoreTitle => 'Restore a backup';

  @override
  String get backupRestoreDescription =>
      'Restore your backup and get every note back.';

  @override
  String get backupPasswordTitle => 'Choose a password';

  @override
  String get backupPasswordSubtitle =>
      'This password is the only key to your backup.';

  @override
  String get backupPasswordLabel => 'Password';

  @override
  String get backupPasswordRepeat => 'Repeat password';

  @override
  String get backupPasswordMismatch => 'The two passwords don’t match.';

  @override
  String backupPasswordShort(int count) {
    return 'Use at least $count characters.';
  }

  @override
  String get backupStrengthWeak => 'Weak';

  @override
  String get backupStrengthFair => 'Fair';

  @override
  String get backupStrengthStrong => 'Strong';

  @override
  String get backupLossWarning =>
      'I understand that if I lose this password, this backup can never be opened.';

  @override
  String get backupActionCreate => 'Create backup';

  @override
  String get backupPhasePreparing => 'Preparing';

  @override
  String get backupPhaseKey => 'Deriving key';

  @override
  String get backupPhaseWriting => 'Encrypting';

  @override
  String get backupPhaseReading => 'Decrypting';

  @override
  String get backupPhaseVerifying => 'Verifying';

  @override
  String get backupPhaseApplying => 'Restoring';

  @override
  String backupItems(int done, int total) {
    return '$done of $total';
  }

  @override
  String get backupReadyTitle => 'Your backup is ready';

  @override
  String backupReadySubtitle(int notes, int photos) {
    return '$notes notes and $photos photos, encrypted.';
  }

  @override
  String get backupActionSave => 'Save to this device';

  @override
  String get backupSavedToDevice => 'Saved.';

  @override
  String get backupPickFile => 'Choose a file';

  @override
  String get backupUnlockTitle => 'Enter the password';

  @override
  String get backupUnlockSubtitle =>
      'The password you chose when this backup was created.';

  @override
  String get backupFoundTitle => 'Backup found';

  @override
  String backupFoundCounts(int notes, int photos) {
    return '$notes notes, $photos photos';
  }

  @override
  String backupFoundDate(String when) {
    return 'Created $when';
  }

  @override
  String get backupReplaceWarning =>
      'Restoring replaces every note and frame on this device. This cannot be undone.';

  @override
  String get backupReplaceAcknowledge =>
      'I understand my current data will be deleted.';

  @override
  String get backupActionRestore => 'Restore';

  @override
  String get backupRestoredTitle => 'Everything is back.';

  @override
  String get backupErrorWrongPassword => 'Wrong password.';

  @override
  String get backupErrorNotABackup => 'This isn’t a Latermark backup.';

  @override
  String get backupErrorCorrupt => 'This file is damaged or incomplete.';

  @override
  String get backupErrorUnsupported =>
      'This backup was made by a newer version of Latermark.';

  @override
  String get backupErrorGeneric => 'Something went wrong. Try again.';

  @override
  String get paywallFeatureBackup => 'Secure backup';

  @override
  String get paywallFeatureBackupDetail =>
      'Take your notes and frames to a new phone.';

  @override
  String get reminderSuffixRepeating => 'days · repeating';

  @override
  String get reminderRepeatToggle => 'Repeat reminder';

  @override
  String get reminderRepeatOnce => 'Reminds once.';

  @override
  String get reminderRepeatNeedsInterval => 'Enter the number of days first.';

  @override
  String reminderRepeatSummary(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Reminds every $days days.',
      one: 'Reminds every day.',
    );
    return '$_temp0';
  }

  @override
  String reminderDailyValue(String when) {
    return 'Every day · next $when';
  }

  @override
  String reminderWeeklyValue(String when) {
    return 'Every week · next $when';
  }

  @override
  String reminderMonthlyValue(String when) {
    return 'Every month · next $when';
  }

  @override
  String reminderYearlyValue(String when) {
    return 'Every year · next $when';
  }

  @override
  String get reminderCadenceOnce => 'Once';

  @override
  String get reminderCadenceDaily => 'Day';

  @override
  String get reminderCadenceWeekly => 'Week';

  @override
  String get reminderCadenceMonthly => 'Month';

  @override
  String get reminderCadenceYearly => 'Year';

  @override
  String get reminderBlocked =>
      'Notifications are off. This frame will still be saved; its reminder will begin working once you allow notifications.';

  @override
  String get editNoteSemantic => 'Edit note';

  @override
  String get editSheetHeader => 'EDIT NOTE';

  @override
  String get retentionSelectorTitle => 'Auto-Delete';

  @override
  String get retentionOffNotice =>
      'Auto-delete is off — this frame stays until you remove it.';

  @override
  String get retentionCustom => 'Custom';

  @override
  String get retentionCustomTitle => 'Custom duration';

  @override
  String retentionCustomHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String retentionCustomDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String retentionCustomWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks',
      one: '1 week',
    );
    return '$_temp0';
  }

  @override
  String get retentionUnitHours => 'Hours';

  @override
  String get retentionUnitDays => 'Days';

  @override
  String get retentionUnitWeeks => 'Weeks';

  @override
  String get retentionCustomDescription =>
      'This frame will delete itself when the time is up.';

  @override
  String get retentionOff => 'Off';

  @override
  String get retentionThreeDays => '3 Days';

  @override
  String get retentionOneWeek => '1 Week';

  @override
  String get retentionOffDescription => 'Off';

  @override
  String get retentionThreeDaysDescription => 'Deletes after 3 days';

  @override
  String get retentionOneWeekDescription => 'Deletes after 1 week';

  @override
  String get legalPrivacy => 'Privacy';

  @override
  String get legalTerms => 'Terms of Use';

  @override
  String get yourDataTitle => 'Latermark & Your Data';

  @override
  String get yourDataSubtitle =>
      'We care about your privacy, and treat it with respect.';

  @override
  String get yourDataSafetyQuestion => 'Is my data safe?';

  @override
  String get yourDataSafetyAnswer =>
      'Latermark processes your notes, photos, and location tags entirely on your device. Unless you choose to share them, your content never leaves it—not for analytics, crash reports, usage statistics, or advertising. The app contains no third-party tracking or advertising SDK. The only network traffic is the App Store handling your purchase.';

  @override
  String get yourDataLocationQuestion =>
      'Why does Latermark ask for location access?';

  @override
  String get yourDataLocationAnswer =>
      'Latermark asks for a one-time location only when you choose to tag where a photo was taken. The coordinates are saved only with that entry; there is no background tracking. They are passed to another app only if you choose to open the map.';

  @override
  String get yourDataPhotosQuestion => 'How is photo access used?';

  @override
  String get yourDataPhotosAnswer =>
      'It is used only when you choose an image from your photo library instead of taking a new one. Latermark imports only the image you select, and the process does not require an internet connection.';

  @override
  String get yourDataRemindersQuestion => 'How do reminders work?';

  @override
  String get yourDataRemindersAnswer =>
      'Reminders are scheduled on your device and shown by your device. No external server sends or triggers them.';

  @override
  String get yourDataDeletionQuestion => 'What happens if I delete the app?';

  @override
  String get yourDataDeletionAnswer =>
      'Notes, imported images, and location tags stored in Latermark are permanently deleted. Your photo library and data in other apps are not affected.';

  @override
  String get legalOpenFailed => 'Couldn’t open the link.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get accessibilityTitle => 'Accessibility';

  @override
  String get accessibilityDescription =>
      'Make contrast stronger or reduce motion just for Latermark.';

  @override
  String get accessibilityIntro =>
      'Latermark always follows your device accessibility settings. These controls can make them stricter only inside the app.';

  @override
  String get accessibilityContrastTitle => 'Always increase contrast';

  @override
  String get accessibilityContrastDescription =>
      'Strengthens secondary text, controls, and overlays on photos.';

  @override
  String get accessibilityMotionTitle => 'Always reduce motion';

  @override
  String get accessibilityMotionDescription =>
      'Stops decorative movement and replaces depth transitions with gentle fades.';

  @override
  String get accessibilitySystemNote =>
      'Your device stays in control. If Increase Contrast or Reduce Motion is enabled in system settings, Latermark follows it even when these switches are off.';

  @override
  String get accessibilityTextSizeTitle => 'Text size';

  @override
  String get accessibilityTextSizeBody =>
      'Text size is a device setting, and Latermark follows it up to twice the default. Settings › Accessibility › Display & Text Size › Larger Text. To enlarge it only inside Latermark, use Settings › Accessibility › Per-App Settings.';

  @override
  String get sectionAppearance => 'Appearance';

  @override
  String get sectionReminder => 'Reminders';

  @override
  String get sectionSharing => 'Sharing';

  @override
  String get shareSignatureTitle => 'Share signature';

  @override
  String get shareSignatureDescription =>
      'Notes you share end with a line naming Latermark. Turn it off and your words go exactly as you wrote them.';

  @override
  String shareSignature(String platform) {
    return 'Sent with Latermark for $platform';
  }

  @override
  String get themeTitle => 'Theme';

  @override
  String get themeDescription =>
      'Follow your system appearance or choose one to keep.';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get appColorTitle => 'App Color';

  @override
  String get appColorDescription =>
      'Choose the accent Latermark uses for controls and highlights.';

  @override
  String get accentOrange => 'Orange';

  @override
  String get accentBlue => 'Blue';

  @override
  String get accentViolet => 'Violet';

  @override
  String get accentPink => 'Pink';

  @override
  String get accentGreen => 'Green';

  @override
  String get accentGold => 'Gold';

  @override
  String get accentSilver => 'Silver';

  @override
  String get accentCustom => 'Custom';

  @override
  String get accentCustomTitle => 'Custom color';

  @override
  String get accentCustomHint =>
      'Drag the ring to choose a tone. Brightness is set by Latermark so the colour stays readable on light, dark and photo backgrounds.';

  @override
  String get accentCustomApply => 'Use this colour';

  @override
  String get retentionTitle => 'Auto-Delete';

  @override
  String get retentionDescription =>
      'New frames start with this duration. You can change it for any frame from its detail view.';

  @override
  String get feedTitle => 'Feed';

  @override
  String get feedDescription => 'Show larger frames or fit more into a grid.';

  @override
  String get densityLarge => 'Large';

  @override
  String get densityGrid => 'Grid';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageDescription =>
      'Latermark follows your device language, or you can choose another.';

  @override
  String get languageSystem => 'System';

  @override
  String get remindersTitle => 'Reminders';

  @override
  String get remindersDescription =>
      'Only frames you schedule while saving will notify you. Everything else stays quiet.';

  @override
  String get remindersBlockedDescription =>
      'Notifications are disabled in system settings. Reminders will resume once you allow them.';

  @override
  String get openSystemSettings => 'Open System Settings';

  @override
  String get openSettingsShort => 'Open Settings';

  @override
  String versionMark(String version, String build) {
    return 'Version $version ($build)';
  }

  @override
  String get dayToday => 'Today';

  @override
  String get dayYesterday => 'Yesterday';

  @override
  String get relativeJustNow => 'just now';

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
      other: '$count hr',
      one: '1 hr',
    );
    return '$_temp0';
  }

  @override
  String get relativeYesterday => 'yesterday';

  @override
  String relativeDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get remainingNow => 'now';

  @override
  String remainingShortDays(int count) {
    return '${count}d';
  }

  @override
  String remainingShortHours(int count) {
    return '${count}h';
  }

  @override
  String remainingShortMinutes(int count) {
    return '${count}m';
  }

  @override
  String get remainingShortLessThanMinute => '<1m';

  @override
  String get remainingSoon => 'Deleting shortly';

  @override
  String remainingLongDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Deletes in $days days',
      one: 'Deletes in 1 day',
    );
    return '$_temp0';
  }

  @override
  String remainingLongDaysHours(int days, int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours hours',
      one: '1 hour',
    );
    return '$_temp0 $_temp1 until deletion';
  }

  @override
  String remainingLongHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'Deletes in $hours hours',
      one: 'Deletes in 1 hour',
    );
    return '$_temp0';
  }

  @override
  String remainingLongHoursMinutes(int hours, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours hours',
      one: '1 hour',
    );
    String _temp1 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
    );
    return '$_temp0 $_temp1 until deletion';
  }

  @override
  String remainingLongMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Deletes in $minutes minutes',
      one: 'Deletes in 1 minute',
    );
    return '$_temp0';
  }

  @override
  String paywallLimitTitle(int limit) {
    return 'Your $limit frames are full';
  }

  @override
  String paywallLimitBody(int limit) {
    return 'The free tier keeps up to $limit frames at a time. Pro removes the limit — or delete one frame to continue.';
  }

  @override
  String get paywallLimitDelete => 'Delete a frame';

  @override
  String paywallCounter(int count, int limit) {
    return '$count/$limit';
  }

  @override
  String get proBadge => 'PRO';

  @override
  String get paywallHeadline => 'Don’t leave what matters behind.';

  @override
  String get paywallSubtitle =>
      'Latermark Pro brings back everything you’ll want to return to — at exactly the right time.';

  @override
  String paywallOwnedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You have $count frames right now.',
      one: 'You have 1 frame right now.',
    );
    return '$_temp0';
  }

  @override
  String get paywallFeatureUnlimited => 'Unlimited notes';

  @override
  String paywallFeatureUnlimitedDetail(int limit) {
    return 'Not $limit — completely unlimited.';
  }

  @override
  String get paywallFeatureCustomRetention => 'Choose any duration';

  @override
  String get paywallFeatureCustomRetentionDetail =>
      'Go beyond 3 days and 1 week.';

  @override
  String get paywallFeatureReminders => 'Reminders';

  @override
  String get paywallFeatureRemindersDetail =>
      'Reminds you exactly when you need it.';

  @override
  String get paywallFeatureWidget => 'Home & Lock Screen widgets';

  @override
  String get paywallFeatureWidgetDetail =>
      'Your latest frame, always a glance away.';

  @override
  String paywallPrice(String price) {
    return '$price';
  }

  @override
  String get paywallOneTime => 'One-time purchase';

  @override
  String get paywallNoSubscription => 'No subscription. Pay once, keep Pro.';

  @override
  String get paywallOwned => 'Latermark Pro is yours.';

  @override
  String get paywallFeatureNoSubscription => 'No subscription';

  @override
  String get paywallFeatureNoSubscriptionDetail =>
      'No subscription in Latermark — it’s yours for life.';

  @override
  String get paywallCta => 'Unlock Pro';

  @override
  String get paywallRestore => 'Restore Purchases';

  @override
  String get paywallRestoreNotFound =>
      'No previous Latermark Pro purchase was found.';

  @override
  String get paywallRestoreFailed =>
      'Purchases couldn’t be restored. Please try again.';

  @override
  String get paywallClose => 'Close';

  @override
  String get paywallLifeFree => 'Free';

  @override
  String get paywallLifePro => 'Pro';

  @override
  String get notificationTitle => 'Reminder';

  @override
  String get notificationTitleNoBody => 'A frame is waiting';

  @override
  String get notificationBodyNoBody =>
      'You asked Latermark to remind you about this frame.';

  @override
  String get notificationBodyNoFrame =>
      'You asked Latermark to remind you about this note.';

  @override
  String reminderFreeRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Free plan: $count reminders left',
      one: 'Free plan: 1 reminder left',
    );
    return '$_temp0';
  }

  @override
  String get reminderFreeSpent => 'Free reminders used up';

  @override
  String get notificationChannelName => 'Reminders';

  @override
  String get notificationChannelDescription =>
      'Reminds you about frames you’ve scheduled.';

  @override
  String get reminderActionDone => 'Done';

  @override
  String get reminderActionTomorrow => 'Tomorrow';

  @override
  String get reminderActionNextWeek => 'Next week';

  @override
  String get reminderActionTurnOff => 'Turn off this reminder';

  @override
  String get actionOK => 'OK';

  @override
  String get widgetDescription => 'Shows your latest frame and note.';

  @override
  String get widgetEmptySubtitle => 'Your first note will appear here';

  @override
  String get widgetPhotoDescription => 'Photo from your latest frame';

  @override
  String get widgetLeaveTrace => 'Leave a new trace';

  @override
  String get widgetOpenApp => 'Open Latermark';

  @override
  String get widgetCreateNote => 'Create a new note';

  @override
  String get widgetLeaveFirstTrace => 'Leave your first trace';

  @override
  String get widgetProRequired => 'Widgets are available with Latermark Pro.';

  @override
  String get widgetPreviewNote => 'Send this to Accounting';

  @override
  String get widgetPreviewDay => 'TODAY';

  @override
  String get shareComposeHint => 'Why are you keeping this photo?';

  @override
  String get shareErrorTitle => 'Couldn’t add the photo';

  @override
  String get shareErrorBody =>
      'The photo couldn’t be sent to Latermark. Please try again.';

  @override
  String get cameraUsageDescription =>
      'Camera access lets you capture photos for your notes.';

  @override
  String get photoLibraryUsageDescription =>
      'Photo access lets you add images from your library to your notes.';

  @override
  String get actionShare => 'Share';

  @override
  String get shareNoteSemantic => 'Share photo and note';

  @override
  String get reminderSwitchLabel => 'Remind me about this';

  @override
  String get actionSaveAndRemind => 'Save and set reminder';

  @override
  String get reminderScheduleSaved => 'Saved';

  @override
  String get reminderScheduleQuestion => 'When should this frame come back?';

  @override
  String get reminderTimeLabel => 'Time';

  @override
  String get reminderSkip => 'Not now';

  @override
  String get reminderDeleteAfterLabel => 'Delete 30 minutes after reminding';

  @override
  String reminderDeleteAfterValue(String when) {
    return '$when · then deleted';
  }

  @override
  String get reminderDeleteAfterOverride =>
      'Replaces this note\'s own retention.';

  @override
  String get reminderAfterExpiry =>
      'The reminder must be before this note is deleted.';

  @override
  String get keepOriginalLabel => 'Save the original';

  @override
  String get composeOptionsLabel => 'Options';

  @override
  String get keepOriginalDetail => 'Quality stays untouched, storage grows.';

  @override
  String get originalMark => 'Original';

  @override
  String get composeLocationFailed => 'Location unavailable';

  @override
  String get archiveUnavailableTitle => 'Couldn\'t open your archive';

  @override
  String get archiveUnavailableBody =>
      'Your frames are still on this phone. Don\'t delete the app — that would take them with it.';

  @override
  String get archiveRepairAction => 'Repair';

  @override
  String archiveRepairCount(int count) {
    return 'Frames that can be recovered: $count';
  }

  @override
  String get archiveRepairCost =>
      'Your notes, reminders and retention settings can\'t be recovered — those lived only in the record. The damaged file isn\'t deleted, just set aside.';

  @override
  String archiveRepairDone(int count) {
    return 'Recovered $count frames';
  }

  @override
  String get locationFixFailed =>
      'The device could not fix a position right now. The note will be saved without a place.';

  @override
  String get composeTextEntry => 'Write text';

  @override
  String get addEntry => 'Add a note';

  @override
  String get composeTextHint => 'What do you want to remember?';
}
