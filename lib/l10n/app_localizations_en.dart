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
  String get actionRetry => 'Try Again';

  @override
  String get actionGoBack => 'Go Back';

  @override
  String get actionOpen => 'Open';

  @override
  String get settingsAction => 'Settings';

  @override
  String get shutterSemantic => 'Take a photo';

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
  String get reminderSuffixActive => 'days from now';

  @override
  String get reminderSuffixOff => 'days — off';

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
  String get legalOpenFailed => 'Couldn’t open the link.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get sectionAppearance => 'Appearance';

  @override
  String get sectionReminder => 'Reminders';

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
  String get paywallLimitTitle => 'Your 10 frames are full';

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
  String get paywallHeadline => 'Some frames should stay.';

  @override
  String get paywallSubtitle =>
      'Latermark is made for letting go. Pro is for what you want to keep.';

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
  String get paywallFeatureUnlimited => 'Unlimited frames';

  @override
  String paywallFeatureUnlimitedDetail(int limit) {
    return 'Free keeps up to $limit frames.';
  }

  @override
  String get paywallFeatureCustomRetention => 'Choose any duration';

  @override
  String get paywallFeatureCustomRetentionDetail =>
      'Go beyond 3 days and 1 week.';

  @override
  String get paywallFeatureReminders => 'Reminders';

  @override
  String get paywallFeatureRemindersDetail => 'A quiet nudge for what matters.';

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
  String get paywallFeatureNoSubscription => 'No subscription';

  @override
  String get paywallFeatureNoSubscriptionDetail =>
      'Most apps charge monthly. Latermark doesn’t.';

  @override
  String get paywallCta => 'Unlock Pro';

  @override
  String get paywallRestore => 'Restore Purchases';

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
  String get notificationChannelName => 'Reminders';

  @override
  String get notificationChannelDescription =>
      'Reminds you about frames you’ve scheduled.';

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
}
