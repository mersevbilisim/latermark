// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class L10nJa extends L10n {
  L10nJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'Latermark';

  @override
  String get actionSave => '保存';

  @override
  String get composeSaving => '保存中';

  @override
  String get actionCancel => 'キャンセル';

  @override
  String get actionClose => '閉じる';

  @override
  String get actionBack => '戻る';

  @override
  String get actionDelete => '削除';

  @override
  String get actionEdit => '編集';

  @override
  String get actionMore => 'その他';

  @override
  String get openPhotoSemantic => '写真を全画面で開く';

  @override
  String get actionRetry => 'もう一度試す';

  @override
  String get actionGoBack => '戻る';

  @override
  String get actionOpen => '開く';

  @override
  String get settingsAction => '設定';

  @override
  String get shutterSemantic => '写真を撮る';

  @override
  String get searchHint => '検索';

  @override
  String searchResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件',
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
  String get notesTitle => 'ノート';

  @override
  String get dateGroupToday => '今日';

  @override
  String get dateGroupYesterday => '昨日';

  @override
  String get dateGroupPastWeek => '過去7日間';

  @override
  String get dateGroupPastMonth => '過去1か月';

  @override
  String get dateGroupPastThreeMonths => '過去3か月';

  @override
  String get dateGroupPastYear => '過去1年間';

  @override
  String get dateGroupOlder => '1年以上前';

  @override
  String noteCount(int count) {
    return 'ノート $count件';
  }

  @override
  String get noteWithoutBody => 'メモなし';

  @override
  String get inviteTitle => 'タップして撮影';

  @override
  String get inviteBody => 'レシート、駐車場所、ふとしたもの…\n撮って、ひと言添えて、あとは忘れる。';

  @override
  String get pickFromGallery => '写真から選ぶ';

  @override
  String get pickFromGallerySemantic => '写真ライブラリから選ぶ';

  @override
  String get galleryPickerOpening => '写真選択を開いています';

  @override
  String get manifestoFirst => 'シンプル';

  @override
  String get manifestoSecond => '端末内';

  @override
  String get manifestoThird => '安心';

  @override
  String get switchToLargeView => '大きく表示';

  @override
  String get switchToGridView => 'グリッド表示';

  @override
  String get toastPhotoPickFailed => '写真を選択できませんでした。もう一度お試しください。';

  @override
  String get toastPendingPickFailed => '中断された写真選択を再開できませんでした。';

  @override
  String get toastSharedPhotoAdded => '共有された写真を追加しました。';

  @override
  String get toastSharedPhotoFailed => '共有された写真を追加できませんでした。後でもう一度試します。';

  @override
  String get toastDeleteFailed => '削除できませんでした。もう一度お試しください。';

  @override
  String get toastSaveFailed => '保存できませんでした。もう一度お試しください。';

  @override
  String get toastEditFailed => '変更を保存できませんでした。';

  @override
  String get toastPermissionDenied => '通知がオフのため、リマインダーは作動しません。';

  @override
  String get deleteConfirmTitle => 'この記録を削除しますか？';

  @override
  String get deleteConfirmCaption => '写真とノートがまとめて削除されます。';

  @override
  String get holdToDelete => '長押しで削除';

  @override
  String get holdStageAlmost => 'あと少し';

  @override
  String get holdStageRelease => 'そのまま長押し…';

  @override
  String get holdStageGone => '削除しました';

  @override
  String get cameraNotFoundTitle => 'カメラを利用できません';

  @override
  String get cameraNotFoundBody => 'このデバイスで利用できるカメラがありません。';

  @override
  String get cameraDeniedTitle => 'カメラアクセスがオフです';

  @override
  String get cameraDeniedBody => '設定 › Latermarkでカメラへのアクセスを許可してください。';

  @override
  String get cameraFailedTitle => 'カメラを開けませんでした';

  @override
  String get cameraFailedBody => '予期しない問題が発生しました。';

  @override
  String get switchLens => 'カメラを切り替える';

  @override
  String flashSemantic(String state) {
    return 'フラッシュ：$state';
  }

  @override
  String get flashOff => 'オフ';

  @override
  String get flashAuto => '自動';

  @override
  String get flashOn => 'オン';

  @override
  String get composeHint => 'なぜ撮りましたか？';

  @override
  String get composeReminderDescription => '選んだ日に、この記録をもう一度お知らせします。';

  @override
  String get composeLocationDescription => '現在地をこの記録だけに添えます。';

  @override
  String get composeLocationResolving => '現在地を確認しています…';

  @override
  String get composeLocationReady => 'この記録に追加する場所を確認しました。';

  @override
  String get composeLocationPermissionRequired => '位置情報の許可が必要です。';

  @override
  String get composeAnotherPhoto => '別の写真を選ぶ';

  @override
  String get composeRetake => '撮り直す';

  @override
  String get sourceGallery => '写真';

  @override
  String get sourceShared => '共有';

  @override
  String get reminderLabel => 'リマインド';

  @override
  String get addedLabel => '追加日';

  @override
  String get lastUpdatedLabel => '最終更新';

  @override
  String get locationLabel => '場所';

  @override
  String get locationAddLabel => '場所を追加';

  @override
  String get locationBlocked =>
      '場所の追加には許可が必要です。撮影場所を記録するには位置情報へのアクセスを許可してください。';

  @override
  String get compassNorth => 'N';

  @override
  String get compassSouth => 'S';

  @override
  String get compassEast => 'E';

  @override
  String get compassWest => 'W';

  @override
  String get toastMapFailed => 'マップを開けませんでした';

  @override
  String get reminderSuffixActive => '日後';

  @override
  String get reminderSuffixOff => '日 — オフ';

  @override
  String get backupSectionTitle => 'バックアップ';

  @override
  String get backupManageTitle => 'バックアップ管理';

  @override
  String get backupManageDescription => '暗号化したコピーの作成や、既存のバックアップの復元ができます。';

  @override
  String get backupCreateTitle => 'バックアップを作成';

  @override
  String get backupCreateDescription => 'この端末のすべてを、暗号化された1つのファイルに。';

  @override
  String get backupRestoreTitle => 'バックアップから復元';

  @override
  String get backupRestoreDescription => 'ここにあるすべてをバックアップファイルで置き換えます。';

  @override
  String get backupPasswordTitle => 'パスワードを設定';

  @override
  String get backupPasswordSubtitle => 'このパスワードがバックアップを開く唯一の鍵です。';

  @override
  String get backupPasswordLabel => 'パスワード';

  @override
  String get backupPasswordRepeat => 'パスワードを再入力';

  @override
  String get backupPasswordMismatch => '2つのパスワードが一致しません。';

  @override
  String backupPasswordShort(int count) {
    return '$count文字以上にしてください。';
  }

  @override
  String get backupStrengthWeak => '弱い';

  @override
  String get backupStrengthFair => '普通';

  @override
  String get backupStrengthStrong => '強い';

  @override
  String get backupLossWarning => 'このパスワードを忘れると、このバックアップは二度と開けなくなることを理解しました。';

  @override
  String get backupActionCreate => 'バックアップを作成';

  @override
  String get backupPhasePreparing => '準備中';

  @override
  String get backupPhaseKey => '鍵を生成中';

  @override
  String get backupPhaseWriting => '暗号化中';

  @override
  String get backupPhaseReading => '復号中';

  @override
  String get backupPhaseVerifying => '検証中';

  @override
  String get backupPhaseApplying => '復元中';

  @override
  String backupItems(int done, int total) {
    return '$done / $total';
  }

  @override
  String get backupReadyTitle => 'バックアップができました';

  @override
  String backupReadySubtitle(int notes, int photos) {
    return '$notes件のメモと$photos枚の写真を暗号化しました。';
  }

  @override
  String get backupActionSave => '保存または共有';

  @override
  String get backupPickFile => 'ファイルを選択';

  @override
  String get backupUnlockTitle => 'パスワードを入力';

  @override
  String get backupUnlockSubtitle => 'このバックアップを作成したときに設定したパスワード。';

  @override
  String get backupFoundTitle => 'バックアップが見つかりました';

  @override
  String backupFoundCounts(int notes, int photos) {
    return 'メモ$notes件、写真$photos枚';
  }

  @override
  String backupFoundDate(String when) {
    return '$when に作成';
  }

  @override
  String get backupReplaceWarning => '復元すると、この端末のすべてのメモと写真が置き換えられます。元に戻せません。';

  @override
  String get backupReplaceAcknowledge => '現在のデータが削除されることを理解しました。';

  @override
  String get backupActionRestore => '復元';

  @override
  String get backupRestoredTitle => 'すべて戻りました。';

  @override
  String get backupErrorWrongPassword => 'パスワードが違います。';

  @override
  String get backupErrorNotABackup => 'これはLatermarkのバックアップではありません。';

  @override
  String get backupErrorCorrupt => 'このファイルは破損しているか不完全です。';

  @override
  String get backupErrorUnsupported =>
      'このバックアップは、より新しいバージョンのLatermarkで作成されました。';

  @override
  String get backupErrorGeneric => '問題が発生しました。もう一度お試しください。';

  @override
  String get paywallFeatureBackup => '暗号化バックアップ';

  @override
  String get paywallFeatureBackupDetail => 'メモと写真を新しい端末へ。';

  @override
  String get reminderSuffixRepeating => '日ごと';

  @override
  String get reminderRepeatToggle => 'リマインダーを繰り返す';

  @override
  String get reminderRepeatOnce => '1回だけ通知します。';

  @override
  String get reminderRepeatNeedsInterval => '先に日数を入力してください。';

  @override
  String reminderRepeatSummary(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days日ごとに通知します。',
    );
    return '$_temp0';
  }

  @override
  String reminderRepeatingValue(int days, String when) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days日ごと · 次回 $when',
    );
    return '$_temp0';
  }

  @override
  String get reminderBlocked => '通知がオフです。記録は保存され、通知を許可するとリマインダーが作動します。';

  @override
  String get editNoteSemantic => 'ノートを編集';

  @override
  String get editSheetHeader => 'ノートを編集';

  @override
  String get retentionSelectorTitle => '自動削除';

  @override
  String get retentionOffNotice => '自動削除はオフです。この記録は自分で削除するまで残ります。';

  @override
  String get retentionCustom => 'カスタム';

  @override
  String get retentionCustomTitle => '期間を指定';

  @override
  String retentionCustomHours(int count) {
    return '$count時間';
  }

  @override
  String retentionCustomDays(int count) {
    return '$count日';
  }

  @override
  String retentionCustomWeeks(int count) {
    return '$count週間';
  }

  @override
  String get retentionUnitHours => '時間';

  @override
  String get retentionUnitDays => '日';

  @override
  String get retentionUnitWeeks => '週間';

  @override
  String get retentionCustomDescription => '指定した期間が過ぎると自動で削除されます。';

  @override
  String get retentionOff => 'オフ';

  @override
  String get retentionThreeDays => '3日';

  @override
  String get retentionOneWeek => '1週間';

  @override
  String get retentionOffDescription => 'オフ';

  @override
  String get retentionThreeDaysDescription => '3日後に削除';

  @override
  String get retentionOneWeekDescription => '1週間後に削除';

  @override
  String get legalPrivacy => 'プライバシー';

  @override
  String get legalTerms => '利用規約';

  @override
  String get yourDataTitle => 'Latermarkとあなたのデータ';

  @override
  String get yourDataSubtitle => 'あなたのプライバシーを大切にし、尊重します。';

  @override
  String get yourDataSafetyQuestion => 'データは安全ですか？';

  @override
  String get yourDataSafetyAnswer =>
      'Latermarkは、ノートや写真、位置情報をすべて端末内で処理します。自分で共有しない限り、データが端末の外へ出ることはありません。分析、クラッシュレポート、利用統計のために送信されることもありません。';

  @override
  String get yourDataLocationQuestion => 'なぜ位置情報へのアクセスが必要ですか？';

  @override
  String get yourDataLocationAnswer =>
      '記録に場所を添えたいときだけ、一度だけ位置情報を取得します。取得した場所はその記録にだけ保存され、バックグラウンドで追跡することはありません。地図を開いた場合にだけ、座標が地図アプリへ渡されます。';

  @override
  String get yourDataPhotosQuestion => '写真へのアクセスはどのように使われますか？';

  @override
  String get yourDataPhotosAnswer =>
      '写真ライブラリから画像を選び、記録に加えるためだけに使用します。Latermarkが取り込むのは選択した画像だけで、この操作にインターネット接続は必要ありません。';

  @override
  String get yourDataRemindersQuestion => 'リマインダーはどのように届きますか？';

  @override
  String get yourDataRemindersAnswer =>
      'リマインダーは端末内で予約され、端末から直接通知されます。外部サーバーから送られたり、遠隔で作動したりするものではありません。';

  @override
  String get yourDataDeletionQuestion => 'アプリを削除すると、データはどうなりますか？';

  @override
  String get yourDataDeletionAnswer =>
      'Latermarkに保存したノート、取り込んだ画像、位置情報はすべて完全に削除されます。写真ライブラリや、ほかのアプリのデータには影響しません。';

  @override
  String get legalOpenFailed => 'リンクを開けませんでした。';

  @override
  String get settingsTitle => '設定';

  @override
  String get sectionAppearance => '表示';

  @override
  String get sectionReminder => 'リマインダー';

  @override
  String get themeTitle => 'テーマ';

  @override
  String get themeDescription => 'システムに合わせるか、表示を固定できます。';

  @override
  String get themeSystem => 'システム';

  @override
  String get themeLight => 'ライト';

  @override
  String get themeDark => 'ダーク';

  @override
  String get appColorTitle => 'アプリのカラー';

  @override
  String get appColorDescription => '操作項目や強調表示に使うアクセントカラーを選びます。';

  @override
  String get accentOrange => 'オレンジ';

  @override
  String get accentBlue => 'ブルー';

  @override
  String get accentViolet => 'パープル';

  @override
  String get accentPink => 'ピンク';

  @override
  String get accentGreen => 'グリーン';

  @override
  String get accentGold => 'ゴールド';

  @override
  String get retentionTitle => '自動削除';

  @override
  String get retentionDescription => '新しい記録にはこの期間が使われます。記録ごとに詳細画面で変更できます。';

  @override
  String get feedTitle => '表示方法';

  @override
  String get feedDescription => '写真を大きく見るか、グリッドで多く表示するかを選べます。';

  @override
  String get densityLarge => '大';

  @override
  String get densityGrid => 'グリッド';

  @override
  String get languageTitle => '言語';

  @override
  String get languageDescription => '端末の言語に合わせるか、別の言語を選べます。';

  @override
  String get languageSystem => 'システム';

  @override
  String get remindersTitle => 'リマインダー';

  @override
  String get remindersDescription => '保存時に日時を設定した記録だけ通知します。それ以外は静かなままです。';

  @override
  String get remindersBlockedDescription => 'システム設定で通知がオフです。許可するとリマインダーが再開します。';

  @override
  String get openSystemSettings => 'システム設定を開く';

  @override
  String get openSettingsShort => '設定を開く';

  @override
  String versionMark(String version, String build) {
    return 'バージョン $version（$build）';
  }

  @override
  String get dayToday => '今日';

  @override
  String get dayYesterday => '昨日';

  @override
  String get relativeJustNow => 'たった今';

  @override
  String relativeMinutes(int count) {
    return '$count分';
  }

  @override
  String relativeHours(int count) {
    return '$count時間';
  }

  @override
  String get relativeYesterday => '昨日';

  @override
  String relativeDays(int count) {
    return '$count日前';
  }

  @override
  String get remainingNow => '今';

  @override
  String remainingShortDays(int count) {
    return '$count日';
  }

  @override
  String remainingShortHours(int count) {
    return '$count時間';
  }

  @override
  String remainingShortMinutes(int count) {
    return '$count分';
  }

  @override
  String get remainingShortLessThanMinute => '1分未満';

  @override
  String get remainingSoon => 'まもなく削除';

  @override
  String remainingLongDays(int days) {
    return '$days日後に削除';
  }

  @override
  String remainingLongDaysHours(int days, int hours) {
    return '$days日$hours時間後に削除';
  }

  @override
  String remainingLongHours(int hours) {
    return '$hours時間後に削除';
  }

  @override
  String remainingLongHoursMinutes(int hours, int minutes) {
    return '$hours時間$minutes分後に削除';
  }

  @override
  String remainingLongMinutes(int minutes) {
    return '$minutes分後に削除';
  }

  @override
  String get paywallLimitTitle => '10枚すべて使用中';

  @override
  String paywallLimitBody(int limit) {
    return '無料版で保持できるのは同時に$limit枚までです。Proなら上限なし。1枚削除して続けることもできます。';
  }

  @override
  String get paywallLimitDelete => '1枚削除する';

  @override
  String paywallCounter(int count, int limit) {
    return '$count/$limit';
  }

  @override
  String get proBadge => 'PRO';

  @override
  String get paywallHeadline => '残しておきたい一枚もある。';

  @override
  String get paywallSubtitle => 'Latermarkは、忘れるためのアプリ。Proは、忘れたくない一枚のために。';

  @override
  String paywallOwnedCount(int count) {
    return '現在 $count枚あります。';
  }

  @override
  String get paywallFeatureUnlimited => '保存枚数が無制限';

  @override
  String paywallFeatureUnlimitedDetail(int limit) {
    return '無料版は$limit枚まで。';
  }

  @override
  String get paywallFeatureCustomRetention => '期間を自由に設定';

  @override
  String get paywallFeatureCustomRetentionDetail => '3日や1週間以外も選べます。';

  @override
  String get paywallFeatureReminders => 'リマインダー';

  @override
  String get paywallFeatureRemindersDetail => '大切な一枚を、そっとお知らせ。';

  @override
  String get paywallFeatureWidget => 'ホーム・ロック画面ウィジェット';

  @override
  String get paywallFeatureWidgetDetail => '最新の一枚を、いつでもひと目で。';

  @override
  String paywallPrice(String price) {
    return '$price';
  }

  @override
  String get paywallOneTime => '買い切り';

  @override
  String get paywallNoSubscription => 'サブスクリプションなし。一度の購入でずっとPro。';

  @override
  String get paywallOwned => 'Latermark Pro をご利用いただけます。';

  @override
  String get paywallFeatureNoSubscription => 'サブスクリプションなし';

  @override
  String get paywallFeatureNoSubscriptionDetail => '毎月の支払いはありません。購入は一度だけ。';

  @override
  String get paywallCta => 'Proを購入';

  @override
  String get paywallRestore => '購入を復元';

  @override
  String get paywallClose => '閉じる';

  @override
  String get paywallLifeFree => '無料';

  @override
  String get paywallLifePro => 'Pro';

  @override
  String get notificationTitle => 'リマインダー';

  @override
  String get notificationTitleNoBody => '一枚の写真が待っています';

  @override
  String get notificationBodyNoBody => 'この写真を思い出す時間です。';

  @override
  String get notificationChannelName => 'リマインダー';

  @override
  String get notificationChannelDescription => '日時を設定した記録をお知らせします。';

  @override
  String get actionOK => 'OK';

  @override
  String get widgetDescription => '最新の写真とノートを表示します。';

  @override
  String get widgetEmptySubtitle => '最初のノートがここに表示されます';

  @override
  String get widgetPhotoDescription => '最新の記録の写真';

  @override
  String get widgetLeaveTrace => '新しい記録を残す';

  @override
  String get widgetOpenApp => 'Latermarkを開く';

  @override
  String get widgetCreateNote => '新しいノートを作成';

  @override
  String get widgetLeaveFirstTrace => '最初の記録を残す';

  @override
  String get widgetProRequired => 'ウィジェットはLatermark Proで利用できます。';

  @override
  String get widgetPreviewNote => '経理に送る';

  @override
  String get widgetPreviewDay => '今日';

  @override
  String get shareComposeHint => 'この写真を残す理由は？';

  @override
  String get shareErrorTitle => '写真を追加できませんでした';

  @override
  String get shareErrorBody => '写真をLatermarkに送信できませんでした。もう一度お試しください。';

  @override
  String get cameraUsageDescription => 'ノート用の写真を撮るためにカメラを使用します。';

  @override
  String get photoLibraryUsageDescription => '写真ライブラリの画像をノートに追加するために使用します。';

  @override
  String get actionShare => '共有';

  @override
  String get shareNoteSemantic => '写真とメモを共有';
}
