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
  String get composeSaving => '저장 중';

  @override
  String get composeWaitingForLocation => '위치를 기다리는 중';

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
  String get actionMore => '더 보기';

  @override
  String get openPhotoSemantic => '사진을 전체 화면으로 열기';

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
  String get searchHint => '검색';

  @override
  String searchResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개 결과',
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
  String get dateGroupToday => '오늘';

  @override
  String get dateGroupYesterday => '어제';

  @override
  String get dateGroupPastWeek => '최근 7일';

  @override
  String get dateGroupPastMonth => '최근 1개월';

  @override
  String get dateGroupPastThreeMonths => '최근 3개월';

  @override
  String get dateGroupPastYear => '최근 1년';

  @override
  String get dateGroupOlder => '1년 이전';

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
  String get toastQueuedNoteAdded => '메모를 추가했습니다.';

  @override
  String get toastQueuedNoteReminderDropped =>
      '메모를 추가했지만 알림 시각이 메모 삭제 시각보다 늦었습니다.';

  @override
  String get toastQueuedNoteFailed => '메모를 추가하지 못했습니다. 다시 시도할게요.';

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
  String get selectionStart => '삭제할 기록 선택';

  @override
  String get selectionExit => '선택 종료';

  @override
  String get selectionTitle => '선택';

  @override
  String selectionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개 선택됨',
      zero: '선택 없음',
    );
    return '$_temp0';
  }

  @override
  String get selectionHint => '삭제할 기록을 탭하세요';

  @override
  String deleteManyConfirmTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개를 삭제할까요?',
    );
    return '$_temp0';
  }

  @override
  String get deleteManyConfirmCaption => '사진과 노트가 함께 삭제됩니다.';

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
  String get composeReminderDescription => '선택한 날에 이 기록을 다시 알려드려요.';

  @override
  String get composeLocationDescription => '현재 위치를 이 기록에만 연결합니다.';

  @override
  String get composeLocationResolving => '현재 위치를 확인하는 중…';

  @override
  String get composeLocationReady => '이 기록에 추가할 위치를 확인했어요.';

  @override
  String get composeLocationPermissionRequired => '위치 권한이 필요합니다.';

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
  String get addedLabel => '추가한 날짜';

  @override
  String get lastUpdatedLabel => '마지막 업데이트';

  @override
  String get locationLabel => '위치';

  @override
  String get locationAddLabel => '위치 추가';

  @override
  String get locationBlocked =>
      '위치 추가는 권한 허용에 따라 결정됩니다. 촬영 장소를 기록하려면 위치 접근을 허용하세요.';

  @override
  String get compassNorth => 'N';

  @override
  String get compassSouth => 'S';

  @override
  String get compassEast => 'E';

  @override
  String get compassWest => 'W';

  @override
  String get toastMapFailed => '지도를 열 수 없습니다';

  @override
  String get reminderSuffixActive => '일 후';

  @override
  String get reminderSuffixOff => '일 — 끔';

  @override
  String get backupSectionTitle => '백업';

  @override
  String get backupManageTitle => '백업 관리';

  @override
  String get backupManageDescription => '암호화된 사본을 만들거나 기존 백업을 복원합니다.';

  @override
  String get backupCreateTitle => '백업 만들기';

  @override
  String get backupNothingToSave => '아직 백업할 것이 없습니다.';

  @override
  String get backupCreateDescription => 'Latermark에 담긴 모든 것을 암호화된 파일 하나에.';

  @override
  String get backupRestoreTitle => '백업 복원';

  @override
  String get backupRestoreDescription => '백업을 복원해 모든 메모를 되찾으세요.';

  @override
  String get backupPasswordTitle => '비밀번호 설정';

  @override
  String get backupPasswordSubtitle => '이 비밀번호가 백업을 여는 유일한 열쇠입니다.';

  @override
  String get backupPasswordLabel => '비밀번호';

  @override
  String get backupPasswordRepeat => '비밀번호 다시 입력';

  @override
  String get backupPasswordMismatch => '두 비밀번호가 일치하지 않습니다.';

  @override
  String backupPasswordShort(int count) {
    return '$count자 이상 사용하세요.';
  }

  @override
  String get backupStrengthWeak => '약함';

  @override
  String get backupStrengthFair => '보통';

  @override
  String get backupStrengthStrong => '강함';

  @override
  String get backupLossWarning => '이 비밀번호를 잃어버리면 이 백업을 다시는 열 수 없다는 것을 이해합니다.';

  @override
  String get backupActionCreate => '백업 만들기';

  @override
  String get backupPhasePreparing => '준비 중';

  @override
  String get backupPhaseKey => '키 생성 중';

  @override
  String get backupPhaseWriting => '암호화 중';

  @override
  String get backupPhaseReading => '복호화 중';

  @override
  String get backupPhaseVerifying => '확인 중';

  @override
  String get backupPhaseApplying => '복원 중';

  @override
  String backupItems(int done, int total) {
    return '$done / $total';
  }

  @override
  String get backupReadyTitle => '백업이 준비되었습니다';

  @override
  String backupReadySubtitle(int notes, int photos) {
    return '메모 $notes개와 사진 $photos장을 암호화했습니다.';
  }

  @override
  String get backupActionSave => '이 기기에 저장';

  @override
  String get backupSavedToDevice => '저장했습니다.';

  @override
  String get backupPickFile => '파일 선택';

  @override
  String get backupUnlockTitle => '비밀번호 입력';

  @override
  String get backupUnlockSubtitle => '이 백업을 만들 때 설정한 비밀번호입니다.';

  @override
  String get backupFoundTitle => '백업을 찾았습니다';

  @override
  String backupFoundCounts(int notes, int photos) {
    return '메모 $notes개, 사진 $photos장';
  }

  @override
  String backupFoundDate(String when) {
    return '$when에 생성됨';
  }

  @override
  String get backupReplaceWarning => '복원하면 이 기기의 모든 메모와 사진이 대체됩니다. 되돌릴 수 없습니다.';

  @override
  String get backupReplaceAcknowledge => '현재 데이터가 삭제된다는 것을 이해합니다.';

  @override
  String get backupActionRestore => '복원';

  @override
  String get backupRestoredTitle => '모두 돌아왔습니다.';

  @override
  String get backupErrorWrongPassword => '비밀번호가 틀렸습니다.';

  @override
  String get backupErrorNotABackup => 'Latermark 백업이 아닙니다.';

  @override
  String get backupErrorCorrupt => '이 파일은 손상되었거나 불완전합니다.';

  @override
  String get backupErrorUnsupported => '이 백업은 더 새로운 버전의 Latermark로 만들어졌습니다.';

  @override
  String get backupErrorGeneric => '문제가 발생했습니다. 다시 시도하세요.';

  @override
  String get paywallFeatureBackup => '안전한 백업';

  @override
  String get paywallFeatureBackupDetail => '메모와 사진을 새 휴대폰으로 옮기세요.';

  @override
  String get reminderSuffixRepeating => '일마다';

  @override
  String get reminderRepeatToggle => '알림 반복';

  @override
  String get reminderRepeatOnce => '한 번만 알려줘요.';

  @override
  String get reminderRepeatNeedsInterval => '먼저 일수를 입력하세요.';

  @override
  String reminderRepeatSummary(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days일마다 알려줘요.',
    );
    return '$_temp0';
  }

  @override
  String reminderDailyValue(String when) {
    return '매일 · 다음 $when';
  }

  @override
  String reminderWeeklyValue(String when) {
    return '매주 · 다음 $when';
  }

  @override
  String reminderMonthlyValue(String when) {
    return '매월 · 다음 $when';
  }

  @override
  String reminderYearlyValue(String when) {
    return '매년 · 다음 $when';
  }

  @override
  String get reminderCadenceOnce => '한 번';

  @override
  String get reminderCadenceDaily => '일';

  @override
  String get reminderCadenceWeekly => '주';

  @override
  String get reminderCadenceMonthly => '월';

  @override
  String get reminderCadenceYearly => '년';

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
  String get yourDataTitle => 'Latermark와 내 데이터';

  @override
  String get yourDataSubtitle => '개인정보를 소중히 여기고 존중합니다.';

  @override
  String get yourDataSafetyQuestion => '내 데이터는 안전한가요?';

  @override
  String get yourDataSafetyAnswer =>
      'Latermark는 노트, 사진, 위치 정보를 모두 기기 안에서 처리합니다. 직접 공유하지 않는 한 데이터는 기기 밖으로 나가지 않으며, 분석·오류 보고·사용 통계·광고 어느 목적으로도 전송되지 않습니다. 서드파티 추적 또는 광고 SDK가 전혀 포함되어 있지 않습니다. 유일한 네트워크 통신은 구매를 처리하는 앱 스토어입니다.';

  @override
  String get yourDataLocationQuestion => '위치 권한은 왜 필요한가요?';

  @override
  String get yourDataLocationAnswer =>
      '기록에 장소를 추가하고 싶을 때만 위치를 한 번 확인합니다. 위치는 해당 기록에만 저장되며 백그라운드에서 추적하지 않습니다. 지도를 열 때만 좌표가 지도 앱으로 전달됩니다.';

  @override
  String get yourDataPhotosQuestion => '사진 접근 권한은 어떻게 사용되나요?';

  @override
  String get yourDataPhotosAnswer =>
      '사진 보관함에서 이미지를 골라 기록에 추가할 때만 사용합니다. Latermark는 선택한 이미지만 가져오며 이 과정에 인터넷 연결은 필요하지 않습니다.';

  @override
  String get yourDataRemindersQuestion => '리마인더는 어떻게 작동하나요?';

  @override
  String get yourDataRemindersAnswer =>
      '리마인더는 기기 안에서 예약되고 기기가 직접 알려드립니다. 외부 서버에서 보내거나 원격으로 실행하지 않습니다.';

  @override
  String get yourDataDeletionQuestion => '앱을 삭제하면 어떻게 되나요?';

  @override
  String get yourDataDeletionAnswer =>
      'Latermark에 저장한 노트, 가져온 이미지, 위치 정보는 모두 영구적으로 삭제됩니다. 사진 보관함이나 다른 앱의 데이터에는 영향을 주지 않습니다.';

  @override
  String get legalOpenFailed => '링크를 열지 못했습니다.';

  @override
  String get settingsTitle => '설정';

  @override
  String get accessibilityTitle => '손쉬운 사용';

  @override
  String get accessibilityDescription => 'Latermark에서만 대비를 높이거나 동작을 줄일 수 있습니다.';

  @override
  String get accessibilityIntro =>
      'Latermark는 기기의 손쉬운 사용 설정을 항상 따릅니다. 이 옵션은 앱 안에서 해당 설정을 더 강화할 수만 있습니다.';

  @override
  String get accessibilityContrastTitle => '항상 대비 증가';

  @override
  String get accessibilityContrastDescription =>
      '보조 텍스트, 컨트롤, 사진 위 표시를 더 선명하게 만듭니다.';

  @override
  String get accessibilityMotionTitle => '항상 동작 줄이기';

  @override
  String get accessibilityMotionDescription =>
      '장식 동작을 멈추고 깊이 전환을 부드러운 페이드로 바꿉니다.';

  @override
  String get accessibilitySystemNote =>
      '기기 설정이 우선합니다. 시스템에서 대비 증가 또는 동작 줄이기가 켜져 있으면 이 스위치가 꺼져 있어도 Latermark가 따릅니다.';

  @override
  String get accessibilityTextSizeTitle => '글자 크기';

  @override
  String get accessibilityTextSizeBody =>
      '글자 크기는 기기 설정이며 Latermark는 두 배까지 따릅니다. 설정 › 손쉬운 사용 › 디스플레이 및 텍스트 크기 › 더 큰 텍스트. Latermark에서만 키우려면 설정 › 손쉬운 사용 › 앱별 설정.';

  @override
  String get sectionAppearance => '화면';

  @override
  String get sectionReminder => '리마인더';

  @override
  String get sectionSharing => '공유';

  @override
  String get shareSignatureTitle => '공유 서명';

  @override
  String get shareSignatureDescription =>
      '공유하는 메모 끝에 Latermark 한 줄이 붙습니다. 끄면 작성한 문장만 그대로 전송됩니다.';

  @override
  String shareSignature(String platform) {
    return 'Latermark for $platform에서 보냄';
  }

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
  String get appColorTitle => '앱 색상';

  @override
  String get appColorDescription => '컨트롤과 강조 표시에 사용할 포인트 색상을 선택하세요.';

  @override
  String get accentOrange => '주황';

  @override
  String get accentBlue => '파랑';

  @override
  String get accentViolet => '보라';

  @override
  String get accentPink => '분홍';

  @override
  String get accentGreen => '초록';

  @override
  String get accentGold => '골드';

  @override
  String get accentSilver => '실버';

  @override
  String get accentCustom => '사용자 지정';

  @override
  String get accentCustomTitle => '사용자 지정 색상';

  @override
  String get accentCustomHint =>
      '링을 돌려 색조를 고르세요. 밝기는 Latermark가 정합니다. 밝은 배경, 어두운 배경, 사진 위에서도 잘 읽히도록.';

  @override
  String get accentCustomApply => '이 색 사용';

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
  String paywallLimitTitle(int limit) {
    return '$limit개의 공간을 모두 사용 중';
  }

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
  String get paywallHeadline => '소중한 건 그냥 흘려보내지 마세요.';

  @override
  String get paywallSubtitle =>
      'Latermark Pro는 다시 보고 싶은 모든 것을 꼭 맞는 순간에 다시 눈앞에 가져다줍니다.';

  @override
  String paywallOwnedCount(int count) {
    return '현재 기록이 $count개 있습니다.';
  }

  @override
  String get paywallFeatureUnlimited => '무제한 메모';

  @override
  String paywallFeatureUnlimitedDetail(int limit) {
    return '$limit개가 아니라 완전히 무제한.';
  }

  @override
  String get paywallFeatureCustomRetention => '보관 기간 자유 설정';

  @override
  String get paywallFeatureCustomRetentionDetail => '3일과 1주 외에도 원하는 기간으로.';

  @override
  String get paywallFeatureReminders => '리마인더';

  @override
  String get paywallFeatureRemindersDetail => '필요한 바로 그때 알려줍니다.';

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
  String get paywallOwned => 'Latermark Pro를 사용할 수 있습니다.';

  @override
  String get paywallFeatureNoSubscription => '구독 없음';

  @override
  String get paywallFeatureNoSubscriptionDetail =>
      'Latermark은 구독이 필요 없습니다. 한 번 사면 평생 그대로입니다.';

  @override
  String get paywallCta => 'Pro 잠금 해제';

  @override
  String get paywallRestore => '구매 복원';

  @override
  String get paywallRestoreNotFound => '이전에 구매한 Latermark Pro를 찾지 못했습니다.';

  @override
  String get paywallRestoreFailed => '구매를 복원하지 못했습니다. 다시 시도해 주세요.';

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
  String get notificationBodyNoFrame => '이 메모를 알려 달라고 설정했어요.';

  @override
  String reminderFreeRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '무료 플랜: 알림 $count개 남음',
    );
    return '$_temp0';
  }

  @override
  String get reminderFreeSpent => '무료 알림을 모두 사용했어요';

  @override
  String get notificationChannelName => '리마인더';

  @override
  String get notificationChannelDescription => '시간을 정한 기록을 알려드립니다.';

  @override
  String get reminderActionDone => '완료';

  @override
  String get reminderActionTomorrow => '내일';

  @override
  String get reminderActionNextWeek => '다음 주';

  @override
  String get reminderActionTurnOff => '이 알림 끄기';

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

  @override
  String get actionShare => '공유';

  @override
  String get shareNoteSemantic => '사진과 메모 공유';

  @override
  String get reminderSwitchLabel => '이 사진 알려주기';

  @override
  String get actionSaveAndRemind => '저장하고 알림 설정';

  @override
  String get reminderScheduleSaved => '저장됨';

  @override
  String get reminderScheduleQuestion => '이 사진을 언제 다시 볼까요?';

  @override
  String get reminderTimeLabel => '시각';

  @override
  String get reminderSkip => '나중에';

  @override
  String get reminderDeleteAfterLabel => '알림 30분 뒤에 삭제';

  @override
  String reminderDeleteAfterValue(String when) {
    return '$when · 이후 삭제';
  }

  @override
  String get reminderDeleteAfterOverride => '이 메모의 자체 보관 기간을 대체합니다.';

  @override
  String get reminderAfterExpiry => '미리 알림은 이 노트가 삭제되기 전이어야 합니다.';

  @override
  String get keepOriginalLabel => '원본 그대로 저장';

  @override
  String get composeOptionsLabel => '옵션';

  @override
  String get keepOriginalDetail => '화질 그대로, 용량은 늘어납니다.';

  @override
  String get originalMark => '원본';

  @override
  String get composeLocationFailed => '위치를 가져오지 못했습니다';

  @override
  String get archiveUnavailableTitle => '보관함을 열지 못했습니다';

  @override
  String get archiveUnavailableBody =>
      '사진은 이 기기에 그대로 있습니다. 앱을 삭제하지 마세요 — 함께 지워집니다.';

  @override
  String get archiveRepairAction => '복구';

  @override
  String archiveRepairCount(int count) {
    return '복구할 수 있는 사진: $count';
  }

  @override
  String get archiveRepairCost =>
      '메모, 미리 알림, 보관 기간은 복구할 수 없습니다 — 기록에만 있던 정보입니다. 손상된 파일은 삭제하지 않고 옆으로 옮깁니다.';

  @override
  String archiveRepairDone(int count) {
    return '사진 $count장을 되찾았습니다';
  }

  @override
  String get locationFixFailed => '지금은 위치를 확인하지 못했습니다. 장소 없이 저장됩니다.';

  @override
  String get composeTextEntry => '텍스트 쓰기';

  @override
  String get addEntry => '노트 추가';

  @override
  String get composeTextHint => '무엇을 기억하고 싶나요?';
}
