import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L10n
/// returned by `L10n.of(context)`.
///
/// Applications need to include `L10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L10n.localizationsDelegates,
///   supportedLocales: L10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L10n.supportedLocales
/// property.
abstract class L10n {
  L10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L10n of(BuildContext context) {
    return Localizations.of<L10n>(context, L10n)!;
  }

  static const LocalizationsDelegate<L10n> delegate = _L10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('it'),
    Locale('ja'),
    Locale('ko'),
    Locale('pt'),
    Locale('pt', 'BR'),
    Locale('tr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Latermark'**
  String get appTitle;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @composeSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get composeSaving;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @actionBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get actionBack;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// No description provided for @actionMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get actionMore;

  /// No description provided for @openPhotoSemantic.
  ///
  /// In en, this message translates to:
  /// **'Open photo full screen'**
  String get openPhotoSemantic;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get actionRetry;

  /// No description provided for @actionGoBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get actionGoBack;

  /// No description provided for @actionOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get actionOpen;

  /// No description provided for @settingsAction.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsAction;

  /// No description provided for @shutterSemantic.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get shutterSemantic;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchHint;

  /// No description provided for @searchResults.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} result} other{{count} results}}'**
  String searchResults(int count);

  /// No description provided for @searchEmpty.
  ///
  /// In en, this message translates to:
  /// **'Eşleşen kayıt yok'**
  String get searchEmpty;

  /// No description provided for @searchCancel.
  ///
  /// In en, this message translates to:
  /// **'Vazgeç'**
  String get searchCancel;

  /// No description provided for @searchInPhoto.
  ///
  /// In en, this message translates to:
  /// **'karede'**
  String get searchInPhoto;

  /// No description provided for @notesTitle.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notesTitle;

  /// Heading for notes captured today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dateGroupToday;

  /// No description provided for @dateGroupYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get dateGroupYesterday;

  /// Heading for notes older than yesterday but within the previous seven calendar days.
  ///
  /// In en, this message translates to:
  /// **'Past week'**
  String get dateGroupPastWeek;

  /// No description provided for @dateGroupPastMonth.
  ///
  /// In en, this message translates to:
  /// **'Past month'**
  String get dateGroupPastMonth;

  /// No description provided for @dateGroupPastThreeMonths.
  ///
  /// In en, this message translates to:
  /// **'Past 3 months'**
  String get dateGroupPastThreeMonths;

  /// No description provided for @dateGroupPastYear.
  ///
  /// In en, this message translates to:
  /// **'Past year'**
  String get dateGroupPastYear;

  /// Heading for notes older than one year.
  ///
  /// In en, this message translates to:
  /// **'More than a year ago'**
  String get dateGroupOlder;

  /// No description provided for @noteCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No notes} one{1 note} other{{count} notes}}'**
  String noteCount(int count);

  /// No description provided for @noteWithoutBody.
  ///
  /// In en, this message translates to:
  /// **'Untitled note'**
  String get noteWithoutBody;

  /// No description provided for @inviteTitle.
  ///
  /// In en, this message translates to:
  /// **'Tap to capture'**
  String get inviteTitle;

  /// No description provided for @inviteBody.
  ///
  /// In en, this message translates to:
  /// **'A receipt, a parking spot, a detail…\nTake a photo, add a few words, move on.'**
  String get inviteBody;

  /// No description provided for @pickFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Photos'**
  String get pickFromGallery;

  /// No description provided for @pickFromGallerySemantic.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo from your library'**
  String get pickFromGallerySemantic;

  /// No description provided for @galleryPickerOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening photo picker'**
  String get galleryPickerOpening;

  /// First word of the empty-state brand signature.
  ///
  /// In en, this message translates to:
  /// **'Simple'**
  String get manifestoFirst;

  /// Second word of the empty-state brand signature.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get manifestoSecond;

  /// Third word of the empty-state brand signature.
  ///
  /// In en, this message translates to:
  /// **'Yours'**
  String get manifestoThird;

  /// No description provided for @switchToLargeView.
  ///
  /// In en, this message translates to:
  /// **'Switch to large view'**
  String get switchToLargeView;

  /// No description provided for @switchToGridView.
  ///
  /// In en, this message translates to:
  /// **'Switch to grid view'**
  String get switchToGridView;

  /// No description provided for @toastPhotoPickFailed.
  ///
  /// In en, this message translates to:
  /// **'That photo couldn’t be selected. Try again.'**
  String get toastPhotoPickFailed;

  /// No description provided for @toastPendingPickFailed.
  ///
  /// In en, this message translates to:
  /// **'The interrupted photo selection couldn’t be recovered.'**
  String get toastPendingPickFailed;

  /// No description provided for @toastSharedPhotoAdded.
  ///
  /// In en, this message translates to:
  /// **'Shared photo added.'**
  String get toastSharedPhotoAdded;

  /// No description provided for @toastSharedPhotoFailed.
  ///
  /// In en, this message translates to:
  /// **'The shared photo couldn’t be added. We’ll try again.'**
  String get toastSharedPhotoFailed;

  /// No description provided for @toastDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t delete it. Try again.'**
  String get toastDeleteFailed;

  /// No description provided for @toastSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t save it. Try again.'**
  String get toastSaveFailed;

  /// No description provided for @toastEditFailed.
  ///
  /// In en, this message translates to:
  /// **'Your changes couldn’t be saved.'**
  String get toastEditFailed;

  /// No description provided for @toastPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off, so reminders will stay silent.'**
  String get toastPermissionDenied;

  /// No description provided for @deleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this frame?'**
  String get deleteConfirmTitle;

  /// No description provided for @deleteConfirmCaption.
  ///
  /// In en, this message translates to:
  /// **'The photo and note will be deleted together.'**
  String get deleteConfirmCaption;

  /// No description provided for @holdToDelete.
  ///
  /// In en, this message translates to:
  /// **'Press and hold to delete'**
  String get holdToDelete;

  /// No description provided for @holdStageAlmost.
  ///
  /// In en, this message translates to:
  /// **'Almost there'**
  String get holdStageAlmost;

  /// No description provided for @holdStageRelease.
  ///
  /// In en, this message translates to:
  /// **'Keep holding…'**
  String get holdStageRelease;

  /// No description provided for @holdStageGone.
  ///
  /// In en, this message translates to:
  /// **'Gone'**
  String get holdStageGone;

  /// No description provided for @cameraNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera unavailable'**
  String get cameraNotFoundTitle;

  /// No description provided for @cameraNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'No camera is available on this device.'**
  String get cameraNotFoundBody;

  /// No description provided for @cameraDeniedTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera access is off'**
  String get cameraDeniedTitle;

  /// No description provided for @cameraDeniedBody.
  ///
  /// In en, this message translates to:
  /// **'Allow camera access in Settings › Latermark to take photos here.'**
  String get cameraDeniedBody;

  /// No description provided for @cameraFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t open the camera'**
  String get cameraFailedTitle;

  /// No description provided for @cameraFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Something unexpected happened.'**
  String get cameraFailedBody;

  /// No description provided for @switchLens.
  ///
  /// In en, this message translates to:
  /// **'Switch camera'**
  String get switchLens;

  /// No description provided for @flashSemantic.
  ///
  /// In en, this message translates to:
  /// **'Flash: {state}'**
  String flashSemantic(String state);

  /// No description provided for @flashOff.
  ///
  /// In en, this message translates to:
  /// **'off'**
  String get flashOff;

  /// No description provided for @flashAuto.
  ///
  /// In en, this message translates to:
  /// **'auto'**
  String get flashAuto;

  /// No description provided for @flashOn.
  ///
  /// In en, this message translates to:
  /// **'on'**
  String get flashOn;

  /// No description provided for @composeHint.
  ///
  /// In en, this message translates to:
  /// **'Why did you capture this?'**
  String get composeHint;

  /// No description provided for @composeReminderDescription.
  ///
  /// In en, this message translates to:
  /// **'Bring this frame back on the day you choose.'**
  String get composeReminderDescription;

  /// No description provided for @composeLocationDescription.
  ///
  /// In en, this message translates to:
  /// **'Attach your current location only to this frame.'**
  String get composeLocationDescription;

  /// No description provided for @composeLocationResolving.
  ///
  /// In en, this message translates to:
  /// **'Finding your location…'**
  String get composeLocationResolving;

  /// No description provided for @composeLocationReady.
  ///
  /// In en, this message translates to:
  /// **'Location is ready for this frame.'**
  String get composeLocationReady;

  /// No description provided for @composeLocationPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Location permission is required.'**
  String get composeLocationPermissionRequired;

  /// No description provided for @composeAnotherPhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose another photo'**
  String get composeAnotherPhoto;

  /// No description provided for @composeRetake.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get composeRetake;

  /// No description provided for @sourceGallery.
  ///
  /// In en, this message translates to:
  /// **'PHOTOS'**
  String get sourceGallery;

  /// No description provided for @sourceShared.
  ///
  /// In en, this message translates to:
  /// **'SHARED'**
  String get sourceShared;

  /// No description provided for @reminderLabel.
  ///
  /// In en, this message translates to:
  /// **'Remind me'**
  String get reminderLabel;

  /// No description provided for @addedLabel.
  ///
  /// In en, this message translates to:
  /// **'Date added'**
  String get addedLabel;

  /// No description provided for @lastUpdatedLabel.
  ///
  /// In en, this message translates to:
  /// **'Last updated'**
  String get lastUpdatedLabel;

  /// No description provided for @locationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get locationLabel;

  /// No description provided for @locationAddLabel.
  ///
  /// In en, this message translates to:
  /// **'Add location'**
  String get locationAddLabel;

  /// No description provided for @locationBlocked.
  ///
  /// In en, this message translates to:
  /// **'Adding the location depends on your permission. Allow location access to tag where a photo was taken.'**
  String get locationBlocked;

  /// No description provided for @compassNorth.
  ///
  /// In en, this message translates to:
  /// **'N'**
  String get compassNorth;

  /// No description provided for @compassSouth.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get compassSouth;

  /// No description provided for @compassEast.
  ///
  /// In en, this message translates to:
  /// **'E'**
  String get compassEast;

  /// No description provided for @compassWest.
  ///
  /// In en, this message translates to:
  /// **'W'**
  String get compassWest;

  /// No description provided for @toastMapFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open Maps'**
  String get toastMapFailed;

  /// No description provided for @reminderSuffixActive.
  ///
  /// In en, this message translates to:
  /// **'days from now'**
  String get reminderSuffixActive;

  /// No description provided for @reminderSuffixOff.
  ///
  /// In en, this message translates to:
  /// **'days — off'**
  String get reminderSuffixOff;

  /// No description provided for @reminderBlocked.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off. This frame will still be saved; its reminder will begin working once you allow notifications.'**
  String get reminderBlocked;

  /// No description provided for @editNoteSemantic.
  ///
  /// In en, this message translates to:
  /// **'Edit note'**
  String get editNoteSemantic;

  /// No description provided for @editSheetHeader.
  ///
  /// In en, this message translates to:
  /// **'EDIT NOTE'**
  String get editSheetHeader;

  /// No description provided for @retentionSelectorTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-Delete'**
  String get retentionSelectorTitle;

  /// No description provided for @retentionOffNotice.
  ///
  /// In en, this message translates to:
  /// **'Auto-delete is off — this frame stays until you remove it.'**
  String get retentionOffNotice;

  /// No description provided for @retentionCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get retentionCustom;

  /// No description provided for @retentionCustomTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom duration'**
  String get retentionCustomTitle;

  /// No description provided for @retentionCustomHours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 hour} other{{count} hours}}'**
  String retentionCustomHours(int count);

  /// No description provided for @retentionCustomDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 day} other{{count} days}}'**
  String retentionCustomDays(int count);

  /// No description provided for @retentionCustomWeeks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 week} other{{count} weeks}}'**
  String retentionCustomWeeks(int count);

  /// No description provided for @retentionUnitHours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get retentionUnitHours;

  /// No description provided for @retentionUnitDays.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get retentionUnitDays;

  /// No description provided for @retentionUnitWeeks.
  ///
  /// In en, this message translates to:
  /// **'Weeks'**
  String get retentionUnitWeeks;

  /// No description provided for @retentionCustomDescription.
  ///
  /// In en, this message translates to:
  /// **'This frame will delete itself when the time is up.'**
  String get retentionCustomDescription;

  /// No description provided for @retentionOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get retentionOff;

  /// No description provided for @retentionThreeDays.
  ///
  /// In en, this message translates to:
  /// **'3 Days'**
  String get retentionThreeDays;

  /// No description provided for @retentionOneWeek.
  ///
  /// In en, this message translates to:
  /// **'1 Week'**
  String get retentionOneWeek;

  /// No description provided for @retentionOffDescription.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get retentionOffDescription;

  /// No description provided for @retentionThreeDaysDescription.
  ///
  /// In en, this message translates to:
  /// **'Deletes after 3 days'**
  String get retentionThreeDaysDescription;

  /// No description provided for @retentionOneWeekDescription.
  ///
  /// In en, this message translates to:
  /// **'Deletes after 1 week'**
  String get retentionOneWeekDescription;

  /// No description provided for @legalPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get legalPrivacy;

  /// No description provided for @legalTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get legalTerms;

  /// No description provided for @yourDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Latermark & Your Data'**
  String get yourDataTitle;

  /// No description provided for @yourDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We care about your privacy, and treat it with respect.'**
  String get yourDataSubtitle;

  /// No description provided for @yourDataSafetyQuestion.
  ///
  /// In en, this message translates to:
  /// **'Is my data safe?'**
  String get yourDataSafetyQuestion;

  /// No description provided for @yourDataSafetyAnswer.
  ///
  /// In en, this message translates to:
  /// **'Latermark processes your notes, photos, and location tags entirely on your device. Unless you choose to share them, your content never leaves it—not for analytics, crash reports, or usage statistics.'**
  String get yourDataSafetyAnswer;

  /// No description provided for @yourDataLocationQuestion.
  ///
  /// In en, this message translates to:
  /// **'Why does Latermark ask for location access?'**
  String get yourDataLocationQuestion;

  /// No description provided for @yourDataLocationAnswer.
  ///
  /// In en, this message translates to:
  /// **'Latermark asks for a one-time location only when you choose to tag where a photo was taken. The coordinates are saved only with that entry; there is no background tracking. They are passed to another app only if you choose to open the map.'**
  String get yourDataLocationAnswer;

  /// No description provided for @yourDataPhotosQuestion.
  ///
  /// In en, this message translates to:
  /// **'How is photo access used?'**
  String get yourDataPhotosQuestion;

  /// No description provided for @yourDataPhotosAnswer.
  ///
  /// In en, this message translates to:
  /// **'It is used only when you choose an image from your photo library instead of taking a new one. Latermark imports only the image you select, and the process does not require an internet connection.'**
  String get yourDataPhotosAnswer;

  /// No description provided for @yourDataRemindersQuestion.
  ///
  /// In en, this message translates to:
  /// **'How do reminders work?'**
  String get yourDataRemindersQuestion;

  /// No description provided for @yourDataRemindersAnswer.
  ///
  /// In en, this message translates to:
  /// **'Reminders are scheduled on your device and shown by your device. No external server sends or triggers them.'**
  String get yourDataRemindersAnswer;

  /// No description provided for @yourDataDeletionQuestion.
  ///
  /// In en, this message translates to:
  /// **'What happens if I delete the app?'**
  String get yourDataDeletionQuestion;

  /// No description provided for @yourDataDeletionAnswer.
  ///
  /// In en, this message translates to:
  /// **'Notes, imported images, and location tags stored in Latermark are permanently deleted. Your photo library and data in other apps are not affected.'**
  String get yourDataDeletionAnswer;

  /// No description provided for @legalOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t open the link.'**
  String get legalOpenFailed;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @sectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get sectionAppearance;

  /// No description provided for @sectionReminder.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get sectionReminder;

  /// No description provided for @themeTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeTitle;

  /// No description provided for @themeDescription.
  ///
  /// In en, this message translates to:
  /// **'Follow your system appearance or choose one to keep.'**
  String get themeDescription;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @appColorTitle.
  ///
  /// In en, this message translates to:
  /// **'App Color'**
  String get appColorTitle;

  /// No description provided for @appColorDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose the accent Latermark uses for controls and highlights.'**
  String get appColorDescription;

  /// No description provided for @accentOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get accentOrange;

  /// No description provided for @accentBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get accentBlue;

  /// No description provided for @accentViolet.
  ///
  /// In en, this message translates to:
  /// **'Violet'**
  String get accentViolet;

  /// No description provided for @accentPink.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get accentPink;

  /// No description provided for @accentGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get accentGreen;

  /// No description provided for @accentGold.
  ///
  /// In en, this message translates to:
  /// **'Gold'**
  String get accentGold;

  /// No description provided for @retentionTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-Delete'**
  String get retentionTitle;

  /// No description provided for @retentionDescription.
  ///
  /// In en, this message translates to:
  /// **'New frames start with this duration. You can change it for any frame from its detail view.'**
  String get retentionDescription;

  /// No description provided for @feedTitle.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get feedTitle;

  /// No description provided for @feedDescription.
  ///
  /// In en, this message translates to:
  /// **'Show larger frames or fit more into a grid.'**
  String get feedDescription;

  /// No description provided for @densityLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get densityLarge;

  /// No description provided for @densityGrid.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get densityGrid;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// No description provided for @languageDescription.
  ///
  /// In en, this message translates to:
  /// **'Latermark follows your device language, or you can choose another.'**
  String get languageDescription;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @remindersTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get remindersTitle;

  /// No description provided for @remindersDescription.
  ///
  /// In en, this message translates to:
  /// **'Only frames you schedule while saving will notify you. Everything else stays quiet.'**
  String get remindersDescription;

  /// No description provided for @remindersBlockedDescription.
  ///
  /// In en, this message translates to:
  /// **'Notifications are disabled in system settings. Reminders will resume once you allow them.'**
  String get remindersBlockedDescription;

  /// No description provided for @openSystemSettings.
  ///
  /// In en, this message translates to:
  /// **'Open System Settings'**
  String get openSystemSettings;

  /// No description provided for @openSettingsShort.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettingsShort;

  /// No description provided for @versionMark.
  ///
  /// In en, this message translates to:
  /// **'Version {version} ({build})'**
  String versionMark(String version, String build);

  /// No description provided for @dayToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dayToday;

  /// No description provided for @dayYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get dayYesterday;

  /// No description provided for @relativeJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get relativeJustNow;

  /// No description provided for @relativeMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 min} other{{count} min}}'**
  String relativeMinutes(int count);

  /// No description provided for @relativeHours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 hr} other{{count} hr}}'**
  String relativeHours(int count);

  /// No description provided for @relativeYesterday.
  ///
  /// In en, this message translates to:
  /// **'yesterday'**
  String get relativeYesterday;

  /// No description provided for @relativeDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 day} other{{count} days}}'**
  String relativeDays(int count);

  /// No description provided for @remainingNow.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get remainingNow;

  /// No description provided for @remainingShortDays.
  ///
  /// In en, this message translates to:
  /// **'{count}d'**
  String remainingShortDays(int count);

  /// No description provided for @remainingShortHours.
  ///
  /// In en, this message translates to:
  /// **'{count}h'**
  String remainingShortHours(int count);

  /// No description provided for @remainingShortMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count}m'**
  String remainingShortMinutes(int count);

  /// No description provided for @remainingShortLessThanMinute.
  ///
  /// In en, this message translates to:
  /// **'<1m'**
  String get remainingShortLessThanMinute;

  /// No description provided for @remainingSoon.
  ///
  /// In en, this message translates to:
  /// **'Deleting shortly'**
  String get remainingSoon;

  /// No description provided for @remainingLongDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, one{Deletes in 1 day} other{Deletes in {days} days}}'**
  String remainingLongDays(int days);

  /// No description provided for @remainingLongDaysHours.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, one{1 day} other{{days} days}} {hours, plural, one{1 hour} other{{hours} hours}} until deletion'**
  String remainingLongDaysHours(int days, int hours);

  /// No description provided for @remainingLongHours.
  ///
  /// In en, this message translates to:
  /// **'{hours, plural, one{Deletes in 1 hour} other{Deletes in {hours} hours}}'**
  String remainingLongHours(int hours);

  /// No description provided for @remainingLongHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours, plural, one{1 hour} other{{hours} hours}} {minutes, plural, one{1 minute} other{{minutes} minutes}} until deletion'**
  String remainingLongHoursMinutes(int hours, int minutes);

  /// No description provided for @remainingLongMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, one{Deletes in 1 minute} other{Deletes in {minutes} minutes}}'**
  String remainingLongMinutes(int minutes);

  /// No description provided for @paywallLimitTitle.
  ///
  /// In en, this message translates to:
  /// **'Your 10 frames are full'**
  String get paywallLimitTitle;

  /// No description provided for @paywallLimitBody.
  ///
  /// In en, this message translates to:
  /// **'The free tier keeps up to {limit} frames at a time. Pro removes the limit — or delete one frame to continue.'**
  String paywallLimitBody(int limit);

  /// No description provided for @paywallLimitDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete a frame'**
  String get paywallLimitDelete;

  /// No description provided for @paywallCounter.
  ///
  /// In en, this message translates to:
  /// **'{count}/{limit}'**
  String paywallCounter(int count, int limit);

  /// No description provided for @proBadge.
  ///
  /// In en, this message translates to:
  /// **'PRO'**
  String get proBadge;

  /// No description provided for @paywallHeadline.
  ///
  /// In en, this message translates to:
  /// **'Some frames should stay.'**
  String get paywallHeadline;

  /// No description provided for @paywallSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Latermark is made for letting go. Pro is for what you want to keep.'**
  String get paywallSubtitle;

  /// No description provided for @paywallOwnedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{You have 1 frame right now.} other{You have {count} frames right now.}}'**
  String paywallOwnedCount(int count);

  /// No description provided for @paywallFeatureUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited frames'**
  String get paywallFeatureUnlimited;

  /// No description provided for @paywallFeatureUnlimitedDetail.
  ///
  /// In en, this message translates to:
  /// **'Free keeps up to {limit} frames.'**
  String paywallFeatureUnlimitedDetail(int limit);

  /// No description provided for @paywallFeatureCustomRetention.
  ///
  /// In en, this message translates to:
  /// **'Choose any duration'**
  String get paywallFeatureCustomRetention;

  /// No description provided for @paywallFeatureCustomRetentionDetail.
  ///
  /// In en, this message translates to:
  /// **'Go beyond 3 days and 1 week.'**
  String get paywallFeatureCustomRetentionDetail;

  /// No description provided for @paywallFeatureReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get paywallFeatureReminders;

  /// No description provided for @paywallFeatureRemindersDetail.
  ///
  /// In en, this message translates to:
  /// **'A quiet nudge for what matters.'**
  String get paywallFeatureRemindersDetail;

  /// No description provided for @paywallFeatureWidget.
  ///
  /// In en, this message translates to:
  /// **'Home & Lock Screen widgets'**
  String get paywallFeatureWidget;

  /// No description provided for @paywallFeatureWidgetDetail.
  ///
  /// In en, this message translates to:
  /// **'Your latest frame, always a glance away.'**
  String get paywallFeatureWidgetDetail;

  /// No description provided for @paywallPrice.
  ///
  /// In en, this message translates to:
  /// **'{price}'**
  String paywallPrice(String price);

  /// No description provided for @paywallOneTime.
  ///
  /// In en, this message translates to:
  /// **'One-time purchase'**
  String get paywallOneTime;

  /// No description provided for @paywallNoSubscription.
  ///
  /// In en, this message translates to:
  /// **'No subscription. Pay once, keep Pro.'**
  String get paywallNoSubscription;

  /// No description provided for @paywallOwned.
  ///
  /// In en, this message translates to:
  /// **'Latermark Pro is yours.'**
  String get paywallOwned;

  /// No description provided for @paywallFeatureNoSubscription.
  ///
  /// In en, this message translates to:
  /// **'No subscription'**
  String get paywallFeatureNoSubscription;

  /// No description provided for @paywallFeatureNoSubscriptionDetail.
  ///
  /// In en, this message translates to:
  /// **'Most apps charge monthly. Latermark doesn’t.'**
  String get paywallFeatureNoSubscriptionDetail;

  /// No description provided for @paywallCta.
  ///
  /// In en, this message translates to:
  /// **'Unlock Pro'**
  String get paywallCta;

  /// No description provided for @paywallRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore Purchases'**
  String get paywallRestore;

  /// No description provided for @paywallClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get paywallClose;

  /// No description provided for @paywallLifeFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get paywallLifeFree;

  /// No description provided for @paywallLifePro.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get paywallLifePro;

  /// No description provided for @notificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get notificationTitle;

  /// No description provided for @notificationTitleNoBody.
  ///
  /// In en, this message translates to:
  /// **'A frame is waiting'**
  String get notificationTitleNoBody;

  /// No description provided for @notificationBodyNoBody.
  ///
  /// In en, this message translates to:
  /// **'You asked Latermark to remind you about this frame.'**
  String get notificationBodyNoBody;

  /// No description provided for @notificationChannelName.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get notificationChannelName;

  /// No description provided for @notificationChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Reminds you about frames you’ve scheduled.'**
  String get notificationChannelDescription;

  /// No description provided for @actionOK.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get actionOK;

  /// No description provided for @widgetDescription.
  ///
  /// In en, this message translates to:
  /// **'Shows your latest frame and note.'**
  String get widgetDescription;

  /// No description provided for @widgetEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your first note will appear here'**
  String get widgetEmptySubtitle;

  /// No description provided for @widgetPhotoDescription.
  ///
  /// In en, this message translates to:
  /// **'Photo from your latest frame'**
  String get widgetPhotoDescription;

  /// No description provided for @widgetLeaveTrace.
  ///
  /// In en, this message translates to:
  /// **'Leave a new trace'**
  String get widgetLeaveTrace;

  /// No description provided for @widgetOpenApp.
  ///
  /// In en, this message translates to:
  /// **'Open Latermark'**
  String get widgetOpenApp;

  /// No description provided for @widgetCreateNote.
  ///
  /// In en, this message translates to:
  /// **'Create a new note'**
  String get widgetCreateNote;

  /// No description provided for @widgetLeaveFirstTrace.
  ///
  /// In en, this message translates to:
  /// **'Leave your first trace'**
  String get widgetLeaveFirstTrace;

  /// No description provided for @widgetProRequired.
  ///
  /// In en, this message translates to:
  /// **'Widgets are available with Latermark Pro.'**
  String get widgetProRequired;

  /// No description provided for @widgetPreviewNote.
  ///
  /// In en, this message translates to:
  /// **'Send this to Accounting'**
  String get widgetPreviewNote;

  /// No description provided for @widgetPreviewDay.
  ///
  /// In en, this message translates to:
  /// **'TODAY'**
  String get widgetPreviewDay;

  /// No description provided for @shareComposeHint.
  ///
  /// In en, this message translates to:
  /// **'Why are you keeping this photo?'**
  String get shareComposeHint;

  /// No description provided for @shareErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t add the photo'**
  String get shareErrorTitle;

  /// No description provided for @shareErrorBody.
  ///
  /// In en, this message translates to:
  /// **'The photo couldn’t be sent to Latermark. Please try again.'**
  String get shareErrorBody;

  /// No description provided for @cameraUsageDescription.
  ///
  /// In en, this message translates to:
  /// **'Camera access lets you capture photos for your notes.'**
  String get cameraUsageDescription;

  /// No description provided for @photoLibraryUsageDescription.
  ///
  /// In en, this message translates to:
  /// **'Photo access lets you add images from your library to your notes.'**
  String get photoLibraryUsageDescription;

  /// No description provided for @actionShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get actionShare;

  /// No description provided for @shareNoteSemantic.
  ///
  /// In en, this message translates to:
  /// **'Share photo and note'**
  String get shareNoteSemantic;
}

class _L10nDelegate extends LocalizationsDelegate<L10n> {
  const _L10nDelegate();

  @override
  Future<L10n> load(Locale locale) {
    return SynchronousFuture<L10n>(lookupL10n(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'de',
    'en',
    'es',
    'fr',
    'it',
    'ja',
    'ko',
    'pt',
    'tr',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_L10nDelegate old) => false;
}

L10n lookupL10n(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'pt':
      {
        switch (locale.countryCode) {
          case 'BR':
            return L10nPtBr();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return L10nDe();
    case 'en':
      return L10nEn();
    case 'es':
      return L10nEs();
    case 'fr':
      return L10nFr();
    case 'it':
      return L10nIt();
    case 'ja':
      return L10nJa();
    case 'ko':
      return L10nKo();
    case 'pt':
      return L10nPt();
    case 'tr':
      return L10nTr();
  }

  throw FlutterError(
    'L10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
