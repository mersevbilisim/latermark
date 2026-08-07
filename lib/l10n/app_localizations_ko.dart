// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class L10nKo extends L10n {
  L10nKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'Latermark';

  @override
  String get actionSave => '저장';

  @override
  String get actionCancel => '취소';

  @override
  String get actionClose => '닫기';

  @override
  String get actionBack => '뒤로';

  @override
  String get actionDelete => '삭제';

  @override
  String get actionEdit => '편집';

  @override
  String get actionRetry => '다시 시도';

  @override
  String get actionGoBack => '돌아가기';

  @override
  String get actionOpen => '열기';

  @override
  String get settingsAction => '설정';

  @override
  String get shutterSemantic => '사진 촬영';

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
  String get notesTitle => '노트';

  @override
  String noteCount(int count) {
    return '노트 $count개';
  }

  @override
  String get noteWithoutBody => '메모 없음';

  @override
  String get inviteTitle => '눌러서 촬영';

  @override
  String get inviteBody => '영수증, 주차 위치, 스쳐 간 장면…\n사진을 찍고, 몇 마디 남기고, 잊으세요.';

  @override
  String get pickFromGallery => '사진에서 선택';

  @override
  String get pickFromGallerySemantic => '사진 보관함에서 사진 선택';

  @override
  String get galleryPickerOpening => '사진 선택기를 여는 중';

  @override
  String get manifestoFirst => '간결하게';

  @override
  String get manifestoSecond => '기기 안에';

  @override
  String get manifestoThird => '안전하게';

  @override
  String get switchToLargeView => '큰 보기로 전환';

  @override
  String get switchToGridView => '격자 보기로 전환';

  @override
  String get toastPhotoPickFailed => '사진을 선택하지 못했습니다. 다시 시도해 주세요.';

  @override
  String get toastPendingPickFailed => '중단된 사진 선택을 복구하지 못했습니다.';

  @override
  String get toastSharedPhotoAdded => '공유한 사진을 추가했습니다.';

  @override
  String get toastSharedPhotoFailed => '공유한 사진을 추가하지 못했습니다. 다시 시도할게요.';

  @override
  String get toastDeleteFailed => '삭제하지 못했습니다. 다시 시도해 주세요.';

  @override
  String get toastSaveFailed => '저장하지 못했습니다. 다시 시도해 주세요.';

  @override
  String get toastEditFailed => '변경 사항을 저장하지 못했습니다.';

  @override
  String get toastPermissionDenied => '알림이 꺼져 있어 리마인더도 울리지 않습니다.';

  @override
  String get deleteConfirmTitle => '이 기록을 삭제할까요?';

  @override
  String get deleteConfirmCaption => '사진과 노트가 함께 삭제됩니다.';

  @override
  String get holdToDelete => '길게 눌러 삭제';

  @override
  String get holdStageAlmost => '거의 다 됐어요';

  @override
  String get holdStageRelease => '조금만 더…';

  @override
  String get holdStageGone => '삭제됨';

  @override
  String get cameraNotFoundTitle => '카메라를 사용할 수 없음';

  @override
  String get cameraNotFoundBody => '이 기기에서 사용할 수 있는 카메라가 없습니다.';

  @override
  String get cameraDeniedTitle => '카메라 접근이 꺼져 있음';

  @override
  String get cameraDeniedBody => '설정 › Latermark에서 카메라 접근을 허용해 주세요.';

  @override
  String get cameraFailedTitle => '카메라를 열지 못했습니다';

  @override
  String get cameraFailedBody => '예기치 않은 문제가 발생했습니다.';

  @override
  String get switchLens => '카메라 전환';

  @override
  String flashSemantic(String state) {
    return '플래시: $state';
  }

  @override
  String get flashOff => '끔';

  @override
  String get flashAuto => '자동';

  @override
  String get flashOn => '켬';

  @override
  String get composeHint => '왜 이 사진을 찍었나요?';

  @override
  String get composeAnotherPhoto => '다른 사진 선택';

  @override
  String get composeRetake => '다시 촬영';

  @override
  String get sourceGallery => '사진';

  @override
  String get sourceShared => '공유';

  @override
  String get reminderLabel => '리마인드';

  @override
  String get reminderSuffixActive => '일 후';

  @override
  String get reminderSuffixOff => '일 — 끔';

  @override
  String get reminderBlocked =>
      '알림이 꺼져 있습니다. 기록은 그대로 저장되며, 알림을 허용하면 리마인더가 작동합니다.';

  @override
  String get editNoteSemantic => '노트 편집';

  @override
  String get editSheetHeader => '노트 편집';

  @override
  String get retentionSelectorTitle => '자동 삭제';

  @override
  String get retentionOffNotice => '자동 삭제가 꺼져 있습니다. 직접 삭제하기 전까지 이 기록은 남아 있습니다.';

  @override
  String get retentionCustom => '직접 설정';

  @override
  String get retentionCustomTitle => '보관 기간 설정';

  @override
  String retentionCustomHours(int count) {
    return '$count시간';
  }

  @override
  String retentionCustomDays(int count) {
    return '$count일';
  }

  @override
  String retentionCustomWeeks(int count) {
    return '$count주';
  }

  @override
  String get retentionUnitHours => '시간';

  @override
  String get retentionUnitDays => '일';

  @override
  String get retentionUnitWeeks => '주';

  @override
  String get retentionCustomDescription => '설정한 시간이 지나면 기록이 자동으로 삭제됩니다.';

  @override
  String get retentionOff => '끔';

  @override
  String get retentionThreeDays => '3일';

  @override
  String get retentionOneWeek => '1주';

  @override
  String get retentionOffDescription => '끔';

  @override
  String get retentionThreeDaysDescription => '3일 후 삭제';

  @override
  String get retentionOneWeekDescription => '1주 후 삭제';

  @override
  String get legalPrivacy => '개인정보 처리방침';

  @override
  String get legalTerms => '이용 약관';

  @override
  String get legalOpenFailed => '링크를 열지 못했습니다.';

  @override
  String get settingsTitle => '설정';

  @override
  String get sectionAppearance => '화면';

  @override
  String get sectionReminder => '리마인더';

  @override
  String get themeTitle => '테마';

  @override
  String get themeDescription => '시스템 설정을 따르거나 원하는 화면으로 고정하세요.';

  @override
  String get themeSystem => '시스템';

  @override
  String get themeLight => '라이트';

  @override
  String get themeDark => '다크';

  @override
  String get retentionTitle => '자동 삭제';

  @override
  String get retentionDescription =>
      '새 기록에는 이 기간이 적용됩니다. 각 기록의 상세 화면에서 따로 바꿀 수 있습니다.';

  @override
  String get feedTitle => '보기 방식';

  @override
  String get feedDescription => '사진을 크게 보거나 격자에서 더 많이 확인하세요.';

  @override
  String get densityLarge => '크게';

  @override
  String get densityGrid => '격자';

  @override
  String get languageTitle => '언어';

  @override
  String get languageDescription => '기기 언어를 따르거나 다른 언어를 선택할 수 있습니다.';

  @override
  String get languageSystem => '시스템';

  @override
  String get remindersTitle => '리마인더';

  @override
  String get remindersDescription =>
      '저장할 때 시간을 정한 기록만 알려드립니다. 나머지는 조용히 남아 있습니다.';

  @override
  String get remindersBlockedDescription =>
      '시스템 설정에서 알림이 꺼져 있습니다. 허용하면 리마인더가 다시 작동합니다.';

  @override
  String get openSystemSettings => '시스템 설정 열기';

  @override
  String get openSettingsShort => '설정 열기';

  @override
  String versionMark(String version, String build) {
    return '버전 $version ($build)';
  }

  @override
  String get dayToday => '오늘';

  @override
  String get dayYesterday => '어제';

  @override
  String get relativeJustNow => '방금';

  @override
  String relativeMinutes(int count) {
    return '$count분';
  }

  @override
  String relativeHours(int count) {
    return '$count시간';
  }

  @override
  String get relativeYesterday => '어제';

  @override
  String relativeDays(int count) {
    return '$count일 전';
  }

  @override
  String get remainingNow => '지금';

  @override
  String remainingShortDays(int count) {
    return '$count일';
  }

  @override
  String remainingShortHours(int count) {
    return '$count시간';
  }

  @override
  String remainingShortMinutes(int count) {
    return '$count분';
  }

  @override
  String get remainingShortLessThanMinute => '1분 미만';

  @override
  String get remainingSoon => '곧 삭제됨';

  @override
  String remainingLongDays(int days) {
    return '$days일 후 삭제';
  }

  @override
  String remainingLongDaysHours(int days, int hours) {
    return '$days일 $hours시간 후 삭제';
  }

  @override
  String remainingLongHours(int hours) {
    return '$hours시간 후 삭제';
  }

  @override
  String remainingLongHoursMinutes(int hours, int minutes) {
    return '$hours시간 $minutes분 후 삭제';
  }

  @override
  String remainingLongMinutes(int minutes) {
    return '$minutes분 후 삭제';
  }

  @override
  String get paywallLimitTitle => '10개의 공간을 모두 사용 중';

  @override
  String paywallLimitBody(int limit) {
    return '무료 버전은 한 번에 $limit개의 기록을 보관합니다. Pro에서는 제한이 사라집니다. 기록 하나를 지우고 계속할 수도 있어요.';
  }

  @override
  String get paywallLimitDelete => '기록 하나 삭제';

  @override
  String paywallCounter(int count, int limit) {
    return '$count/$limit';
  }

  @override
  String get proBadge => 'PRO';

  @override
  String get paywallHeadline => '남겨야 할 장면도 있으니까.';

  @override
  String get paywallSubtitle =>
      'Latermark는 잊기 위해 만들었습니다. Pro는 잊고 싶지 않은 장면을 위해.';

  @override
  String paywallOwnedCount(int count) {
    return '현재 기록이 $count개 있습니다.';
  }

  @override
  String get paywallFeatureUnlimited => '기록 무제한';

  @override
  String paywallFeatureUnlimitedDetail(int limit) {
    return '무료 버전은 $limit개까지 보관합니다.';
  }

  @override
  String get paywallFeatureCustomRetention => '보관 기간 자유 설정';

  @override
  String get paywallFeatureCustomRetentionDetail => '3일과 1주 외에도 원하는 기간으로.';

  @override
  String get paywallFeatureReminders => '리마인더';

  @override
  String get paywallFeatureRemindersDetail => '중요한 순간을 조용히 알려드려요.';

  @override
  String get paywallFeatureWidget => '홈 및 잠금 화면 위젯';

  @override
  String get paywallFeatureWidgetDetail => '최근 기록을 언제든 한눈에.';

  @override
  String paywallPrice(String price) {
    return '$price';
  }

  @override
  String get paywallOneTime => '한 번만 구매';

  @override
  String get paywallNoSubscription => '구독 없이 한 번 구매로 계속 Pro.';

  @override
  String get paywallFeatureNoSubscription => '구독 없음';

  @override
  String get paywallFeatureNoSubscriptionDetail => '매달 결제할 필요 없이 한 번이면 됩니다.';

  @override
  String get paywallCta => 'Pro 잠금 해제';

  @override
  String get paywallRestore => '구매 복원';

  @override
  String get paywallClose => '닫기';

  @override
  String get paywallLifeFree => '무료';

  @override
  String get paywallLifePro => 'Pro';

  @override
  String get notificationTitle => '리마인더';

  @override
  String get notificationTitleNoBody => '기록 하나가 기다리고 있어요';

  @override
  String get notificationBodyNoBody => '이 기록을 다시 알려 달라고 하셨어요.';

  @override
  String get notificationChannelName => '리마인더';

  @override
  String get notificationChannelDescription => '시간을 정한 기록을 알려드립니다.';

  @override
  String get actionOK => '확인';

  @override
  String get widgetDescription => '최근 사진과 노트를 보여줍니다.';

  @override
  String get widgetEmptySubtitle => '첫 노트가 여기에 표시됩니다';

  @override
  String get widgetPhotoDescription => '최근 기록의 사진';

  @override
  String get widgetLeaveTrace => '새로운 흔적 남기기';

  @override
  String get widgetOpenApp => 'Latermark 열기';

  @override
  String get widgetCreateNote => '새 노트 만들기';

  @override
  String get widgetLeaveFirstTrace => '첫 흔적을 남겨보세요';

  @override
  String get widgetProRequired => '위젯은 Latermark Pro에서 사용할 수 있습니다.';

  @override
  String get widgetPreviewNote => '회계팀에 보내기';

  @override
  String get widgetPreviewDay => '오늘';

  @override
  String get shareComposeHint => '이 사진을 남기는 이유는 무엇인가요?';

  @override
  String get shareErrorTitle => '사진을 추가하지 못했습니다';

  @override
  String get shareErrorBody => '사진을 Latermark로 보내지 못했습니다. 다시 시도해 주세요.';

  @override
  String get cameraUsageDescription => '노트에 넣을 사진을 촬영하기 위해 카메라를 사용합니다.';

  @override
  String get photoLibraryUsageDescription => '사진 보관함의 이미지를 노트에 추가하기 위해 사용합니다.';
}
