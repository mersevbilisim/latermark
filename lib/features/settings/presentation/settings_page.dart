import 'dart:ui';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_scope.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/icon_orb.dart';
import '../../../shared/widgets/pro_badge.dart';
import '../../backup/presentation/backup_page.dart';
import '../../notes/domain/retention.dart';
import '../../../l10n/enum_labels.dart';
import '../../../l10n/l10n_context.dart';
import '../domain/app_locale.dart';
import '../data/settings_repository.dart';
import '../domain/app_settings.dart';
import 'widgets/pro_callout.dart';
import 'widgets/settings_pieces.dart';
import '../../../shared/widgets/pressable.dart';
import '../../paywall/presentation/paywall_host.dart';
import '../../notes/presentation/widgets/retention_selector.dart';
import '../../../core/utils/legal_links.dart';
import '../../paywall/data/debug_entitlement.dart';
import 'your_data_page.dart';

/// Ayarlar.
///
/// Kartlara bölünmüş bir liste yerine, bölümleri yalnızca tipografiyle ayrılan
/// tek bir sayfa. Her ayar ne yaptığını bir cümleyle söylüyor, böylece
/// açıklama için ayrı bir yardım metnine gerek kalmıyor.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with WidgetsBindingObserver {
  bool? _notificationPermission;
  bool _enableWhenPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshPermission());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshPermission();
  }

  Future<void> _refreshPermission() async {
    final repository = AppScope.settingsOf(context);
    final granted = await context.reminders.hasPermission();
    if (!mounted) return;

    if (granted && _enableWhenPermissionGranted) {
      _enableWhenPermissionGranted = false;
      await repository.setReminderEnabled(true);
      if (!mounted) return;
    }

    if (granted == _notificationPermission) return;
    setState(() => _notificationPermission = granted);
  }

  void _openSettingsForEnable() {
    _enableWhenPermissionGranted = true;
    context.reminders.openSystemSettings();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final settings = AppScope.preferences(context);
    final repository = AppScope.settingsOf(context);
    final remindersBlocked =
        settings.reminderEnabled && _notificationPermission == false;
    final remindersActive = settings.reminderEnabled && !remindersBlocked;

    return Scaffold(
      backgroundColor: palette.canvas,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _Header(
              palette: palette,
              topPadding: MediaQuery.paddingOf(context).top,
              title: context.l10n.settingsTitle,
              backLabel: context.l10n.actionBack,
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              22,
              0,
              22,
              MediaQuery.paddingOf(context).bottom + 32,
            ),
            sliver: SliverList.list(
              children: [
                // Kendi başlık çizgisini taşıyor; üst boşluk bölümlerinkiyle
                // aynı ritimde olsun diye burada veriliyor.
                const Padding(
                  padding: EdgeInsets.only(top: 34),
                  child: ProCallout(),
                ),

                SettingsSection(
                  title: context.l10n.sectionAppearance,
                  children: [
                    SettingsRow(
                      title: context.l10n.themeTitle,
                      description: context.l10n.themeDescription,
                      below: Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: ChoiceRail<AppThemeMode>(
                          options: AppThemeMode.values,
                          value: settings.themeMode,
                          labelOf: (mode) => mode.label(context.l10n),
                          onChanged: repository.setThemeMode,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    SettingsRow(
                      title: context.l10n.appColorTitle,
                      description: context.l10n.appColorDescription,
                      trailing: Text(
                        settings.accent.label(context.l10n),
                        style: palette.label.copyWith(color: palette.inkSoft),
                      ),
                      below: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: AccentRail(
                          value: settings.accent,
                          labelOf: (accent) => accent.label(context.l10n),
                          onChanged: repository.setAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    SettingsRow(
                      title: context.l10n.retentionTitle,
                      description: context.l10n.retentionDescription,
                      below: Padding(
                        padding: const EdgeInsets.only(top: 14),
                        // ChoiceRail yerine RetentionSelector: "Özel" seçeneği
                        // burada da olmalı, yoksa park için 6 saat isteyen
                        // kullanıcı her kayıtta tek tek ayarlamak zorunda kalır.
                        child: RetentionSelector(
                          value: RetentionChoice(
                            settings.defaultRetention,
                            customMinutes: settings.defaultCustomMinutes,
                          ),
                          showTitle: false,
                          isPro: settings.proUnlocked,
                          onLockedTap: () => showPaywall(
                            context,
                            reason: PaywallReason.customRetention,
                          ),
                          onChanged: repository.setDefaultRetention,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    SettingsRow(
                      title: context.l10n.feedTitle,
                      description: context.l10n.feedDescription,
                      below: Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: ChoiceRail<FeedDensity>(
                          options: FeedDensity.values,
                          value: settings.density,
                          labelOf: (density) => density.label(context.l10n),
                          onChanged: repository.setDensity,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    // Dokuz dil Ayarlar'ın ortasında upuzun bir liste
                    // oluyordu; seçim kendi paneline taşındı ve burada
                    // yalnızca yürürlükteki dil görünüyor.
                    Pressable(
                      onPressed: () => showLanguageSheet(
                        context,
                        value: settings.locale,
                        onChanged: repository.setLocale,
                      ),
                      scale: 0.995,
                      semanticLabel: context.l10n.languageTitle,
                      child: SettingsRow(
                        title: context.l10n.languageTitle,
                        description: context.l10n.languageDescription,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                settings.locale.label(context.l10n),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                                style: palette.body.copyWith(
                                  color: palette.inkSoft,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: palette.inkFaint,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                SettingsSection(
                  title: context.l10n.sectionReminder,
                  children: [
                    SettingsRow(
                      title: context.l10n.remindersTitle,
                      description: remindersBlocked
                          ? context.l10n.remindersBlockedDescription
                          : context.l10n.remindersDescription,
                      trailing: InkSwitch(
                        value: remindersActive,
                        semanticLabel: context.l10n.remindersTitle,
                        onChanged: (value) =>
                            _toggleReminders(repository, value),
                      ),
                      below: remindersBlocked
                          ? Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: _openSettingsForEnable,
                                icon: const Icon(Icons.open_in_new_rounded),
                                label: Text(context.l10n.openSystemSettings),
                              ),
                            )
                          : null,
                    ),
                  ],
                ),

                SettingsSection(
                  title: context.l10n.backupSectionTitle,
                  children: [
                    Pressable(
                      key: const Key('settings-backup'),
                      onPressed: _openBackupHub,
                      scale: .995,
                      semanticLabel: context.l10n.backupManageTitle,
                      child: SettingsRow(
                        title: context.l10n.backupManageTitle,
                        description: context.l10n.backupManageDescription,
                        trailing: settings.proUnlocked
                            ? Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                                color: palette.inkFaint,
                              )
                            : const ProGateMark(),
                      ),
                    ),
                  ],
                ),

                // `kDebugMode` release'de derleme zamanı sabiti `false`; koşul
                // ölü kod olduğu için _DebugSection ikiliye hiç girmiyor.
                // Sürüm çıkarken elle kaldırılacak bir şey yok.
                if (kDebugMode && DebugEntitlement.available)
                  const _DebugSection(),

                const SizedBox(height: 48),
                const _YourDataLink(),
                const SizedBox(height: 10),
                const _LegalLinks(),
                const SizedBox(height: 26),
                const _VersionMark(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Hatırlatıcı açılırken bildirim izni istenir.
  ///
  /// Tercih yalnızca işletim sistemi gerçekten izin verirse açık kaydedilir;
  /// böylece anahtar açık görünürken bildirimlerin çalışmadığı yanıltıcı bir
  /// durum oluşmaz.
  Future<void> _toggleReminders(
    SettingsRepository repository,
    bool value,
  ) async {
    if (!value) {
      await repository.setReminderEnabled(false);
      return;
    }

    final reminders = context.reminders;
    final granted = await reminders.requestPermission();
    await repository.setReminderEnabled(granted);

    if (!mounted) return;
    setState(() => _notificationPermission = granted);
    if (granted) return;
    showToast(
      context,
      context.l10n.toastPermissionDenied,
      error: true,
      actionLabel: context.l10n.openSettingsShort,
      onAction: _openSettingsForEnable,
    );
  }

  Future<void> _openBackupHub() async {
    if (!AppScope.preferences(context).proUnlocked) {
      await showPaywall(context, reason: PaywallReason.backup);
      return;
    }

    // Kayıt sayısı tek bir COUNT(*) ile geliyor; boş bir arşivden yedek almak
    // içi boş bir dosya üretirdi ve bunu kullanıcıya seçim anında söylemek
    // gerekiyor.
    final noteCount = await AppScope.of(context).watchNoteCount().first;
    if (!mounted) return;

    final mode = await showBackupActionsSheet(context, hasData: noteCount > 0);
    if (mode == null || !mounted) return;
    await _openBackup(mode);
  }

  Future<void> _openBackup(BackupMode mode) async {
    if (mode == BackupMode.create) {
      await Navigator.of(
        context,
      ).push(AppRoutes.lift(const BackupPage.create()));
      return;
    }

    try {
      final file = await pickLatermarkBackup();
      if (file == null || !mounted) return;
      await Navigator.of(
        context,
      ).push(AppRoutes.lift(BackupPage.restore(file: file)));
    } catch (error, stackTrace) {
      // Native eklenti/UTI değişikliklerinden sonra yalnız hot restart yapan
      // geliştirme kurulumlarında gerçek sebebi konsolda görünür tutar.
      // Release kullanıcıya platform ayrıntısı sızdırmaz.
      debugPrint('Backup file picker failed: $error\n$stackTrace');
      if (!mounted) return;
      showToast(context, context.l10n.backupErrorGeneric, error: true);
    }
  }
}

/// Yalnızca debug derlemesinde görünen geliştirme bölümü.
///
/// Metinleri çevrilmiyor: dokuz dile bir geliştirme anahtarı için anahtar
/// eklemek sözlüğü kullanıcının hiç görmeyeceği satırlarla şişirirdi.
class _DebugSection extends StatefulWidget {
  const _DebugSection();

  @override
  State<_DebugSection> createState() => _DebugSectionState();
}

class _DebugSectionState extends State<_DebugSection> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'Debug',
      children: [
        SettingsRow(
          title: 'Pro (debug)',
          description:
              'Mağazayı atlar; hak elle açılır. '
              'Kapatmak gerçek downgrade temizliğini çalıştırır.',
          trailing: InkSwitch(
            value: DebugEntitlement.forced,
            semanticLabel: 'Pro (debug)',
            onChanged: _busy ? (_) {} : _toggle,
          ),
        ),
      ],
    );
  }

  /// Sıra önemli: önce anahtar, sonra veritabanı.
  ///
  /// Kapatırken [PurchaseService.setDebugPro] son mağaza cevabını da unutuyor;
  /// bunu yapmadan yazılan `proUnlocked = false`, AppScope'un önbelleği bir
  /// sonraki ayar yayınında eski `true` değeriyle hakkı geri açardı.
  Future<void> _toggle(bool value) async {
    if (_busy) return;
    setState(() => _busy = true);

    final purchases = context.purchases;
    final settings = AppScope.settingsOf(context);
    await purchases.setDebugPro(value);
    await settings.setProUnlocked(value);

    if (!mounted) return;
    setState(() => _busy = false);
  }
}

class _Header extends SliverPersistentHeaderDelegate {
  const _Header({
    required this.palette,
    required this.topPadding,
    required this.title,
    required this.backLabel,
  });

  final AppPalette palette;
  final double topPadding;
  final String title;
  final String backLabel;

  static const _expandedHeight = 122.0;
  static const _collapsedHeight = 58.0;

  @override
  double get maxExtent => topPadding + _expandedHeight;

  @override
  double get minExtent => topPadding + _collapsedHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final t = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final eased = Curves.easeOutCubic.transform(t);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayFor(palette.brightness),
      child: ColoredBox(
        // Başlığın opak tuvali, kayan içeriği sistem çubuğundan ayırır.
        // Küçülme ve saç çizgisi yeterli hiyerarşiyi kurduğu için blur yok.
        color: palette.canvas,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: 22,
              top: topPadding + 10,
              child: IconOrb(
                icon: Icons.arrow_back_rounded,
                semanticLabel: backLabel,
                onPressed: () => Navigator.of(context).maybePop(),
                size: 38,
                iconSize: 18,
                tint: palette.ink,
                fill: palette.canvasLift,
              ),
            ),
            Positioned(
              left: lerpDouble(22, 72, eased)!,
              right: 22,
              bottom: lerpDouble(13, 17, eased)!,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: palette.display.copyWith(
                  fontSize: lerpDouble(34, 19, eased),
                  letterSpacing: lerpDouble(-0.9, -0.3, eased),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Opacity(
                opacity: eased,
                child: ColoredBox(
                  color: palette.hairline,
                  child: const SizedBox(height: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_Header old) =>
      old.palette != palette ||
      old.topPadding != topPadding ||
      old.title != title ||
      old.backLabel != backLabel;
}

/// Yasal metinlerden önce duran kısa güven kapısı.
///
/// Tek bağlantının iki yasal bağlantının üstünde ortalanması, istenen üçgensel
/// hiyerarşiyi kurar. Bu bir yasal belge değil; Latermark'ın veriye nasıl
/// davrandığını birkaç saniyede anlaşılır kılan ürün anlatısıdır.
class _YourDataLink extends StatelessWidget {
  const _YourDataLink();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final title = context.l10n.yourDataTitle;

    return Center(
      child: Pressable(
        onPressed: () =>
            Navigator.of(context).push(AppRoutes.lift(const YourDataPage())),
        scale: 0.97,
        semanticLabel: title,
        child: ExcludeSemantics(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300, minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: palette.label.copyWith(
                        color: palette.ember,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: palette.ember,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sayfanın dibindeki sürüm işareti.
///
/// Bir ayar değil, bir imza: ekranın en altında, sessiz.
class _VersionMark extends StatelessWidget {
  const _VersionMark();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        final version = info == null
            ? ''
            : context.l10n.versionMark(info.version, info.buildNumber);

        return Center(
          child: Column(
            children: [
              Text(
                'LATERMARK',
                style: palette.overline.copyWith(
                  color: palette.inkFaint,
                  letterSpacing: 3.4,
                ),
              ),
              const SizedBox(height: 8),
              AnimatedOpacity(
                opacity: version.isEmpty ? 0 : 1,
                duration: const Duration(milliseconds: 260),
                child: Text(
                  version.isEmpty ? ' ' : version,
                  style: palette.caption.copyWith(color: palette.inkFaint),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Ayarların altındaki yasal bağlantılar.
///
/// Gizlilik metni kullanıcının **gördüğü** dilde açılır; adres dil koduyla
/// biter. App Store listelemesi zaten bir gizlilik bağlantısı istiyor, ama
/// uygulamanın içinde de bulunması kullanıcının onu araması gereken bir şey
/// olmaktan çıkarıyor.
class _LegalLinks extends StatelessWidget {
  const _LegalLinks();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;

    Widget link(String label, Uri url) => Pressable(
      onPressed: () => _open(context, url),
      scale: 0.97,
      semanticLabel: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: palette.label.copyWith(color: palette.inkSoft),
        ),
      ),
    );

    final privacy = link(l10n.legalPrivacy, LegalLinks.privacy(context));
    final terms = link(l10n.legalTerms, LegalLinks.terms);
    final style = palette.label.copyWith(color: palette.inkSoft);
    final textScaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final requiredWidth =
        _textWidth(l10n.legalPrivacy, style, textScaler, direction) +
        _textWidth(l10n.legalTerms, style, textScaler, direction) +
        28;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < requiredWidth) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [privacy, terms],
          );
        }

        return Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              privacy,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '·',
                  style: palette.label.copyWith(color: palette.inkGhost),
                ),
              ),
              terms,
            ],
          ),
        );
      },
    );
  }

  double _textWidth(
    String text,
    TextStyle style,
    TextScaler textScaler,
    TextDirection direction,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textScaler: textScaler,
      textDirection: direction,
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  Future<void> _open(BuildContext context, Uri url) async {
    final opened = await LegalLinks.open(url);
    if (!opened && context.mounted) {
      showToast(context, context.l10n.legalOpenFailed, error: true);
    }
  }
}

/// Dil seçimi paneli.
///
/// Ayarlar ekranında on satır yan yana durunca sayfa okunmaz hâle geliyordu.
/// Seçim ayrı bir yüzeye taşındı; fakat yüzey, standart bir Material seçim
/// listesi yerine Latermark'ın baskı/editoryal dilini sürdüren bir indeks gibi
/// davranıyor.
Future<void> showLanguageSheet(
  BuildContext context, {
  required AppLocale value,
  required ValueChanged<AppLocale> onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.68),
    isScrollControlled: true,
    builder: (context) => _LanguageSheet(value: value, onChanged: onChanged),
  );
}

class _LanguageSheet extends StatelessWidget {
  const _LanguageSheet({required this.value, required this.onChanged});

  final AppLocale value;
  final ValueChanged<AppLocale> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height - media.padding.top - 12;
    final compact = maxHeight < 520;
    final current = AppLocale.values.indexOf(value) + 1;
    final total = AppLocale.values.length;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: DecoratedBox(
        key: const Key('language-sheet-surface'),
        decoration: BoxDecoration(
          color: palette.canvasLift,
          border: Border(
            top: BorderSide(color: palette.hairlineBright, width: 0.5),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tam genişlikte renk bandı yerine kısa bir kalibrasyon izi:
            // vurgu rengi imza olarak kalır, dekorasyona dönüşmez.
            SizedBox(
              height: 2,
              child: Stack(
                children: [
                  PositionedDirectional(
                    start: 22,
                    top: 0,
                    bottom: 0,
                    width: 38,
                    child: ColoredBox(color: palette.ember),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                22,
                compact ? 16 : 20,
                14,
                compact ? 15 : 20,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ExcludeSemantics(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'LATERMARK',
                                  maxLines: 1,
                                  overflow: TextOverflow.fade,
                                  softWrap: false,
                                  style: palette.overline,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ColoredBox(
                                  color: palette.hairline,
                                  child: const SizedBox(height: 0.5),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${_twoDigits(current)} / '
                                '${_twoDigits(total)}',
                                style: palette.overline.copyWith(
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: compact ? 11 : 15),
                        Text(
                          context.l10n.languageTitle,
                          style: palette.display.copyWith(fontSize: 30),
                        ),
                        if (!compact) ...[
                          const SizedBox(height: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 360),
                            child: Text(
                              context.l10n.languageDescription,
                              style: palette.label.copyWith(
                                color: palette.inkSoft,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Pressable(
                    onPressed: () => Navigator.of(context).pop(),
                    scale: 0.88,
                    semanticLabel: context.l10n.actionClose,
                    child: ExcludeSemantics(
                      child: SizedBox.square(
                        dimension: 44,
                        child: Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: palette.inkSoft,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ColoredBox(
              color: palette.hairlineBright,
              child: const SizedBox(height: 0.5),
            ),
            Flexible(
              child: ListView(
                key: const Key('language-options'),
                shrinkWrap: true,
                padding: EdgeInsets.only(bottom: media.padding.bottom + 8),
                children: [
                  for (var index = 0; index < AppLocale.values.length; index++)
                    _LanguageOption(
                      option: AppLocale.values[index],
                      selected: AppLocale.values[index] == value,
                      isLast: index == AppLocale.values.length - 1,
                      onPressed: () {
                        onChanged(AppLocale.values[index]);
                        Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');
}

/// Dil satırı bir kart değil, katalog girdisi: dil kodu taramayı
/// kolaylaştırır; ince cetvel ritmi kurar; seçim yalnızca kısa bir kor
/// çizgisi ve küçük kareyle belirtilir.
class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.option,
    required this.selected,
    required this.isLast,
    required this.onPressed,
  });

  final AppLocale option;
  final bool selected;
  final bool isLast;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Semantics(
      selected: selected,
      child: Pressable(
        key: ValueKey('language-option-${option.name}'),
        onPressed: onPressed,
        scale: 0.995,
        semanticLabel: option.label(context.l10n),
        child: Stack(
          children: [
            if (selected)
              PositionedDirectional(
                start: 0,
                top: 15,
                bottom: 15,
                width: 2,
                child: ColoredBox(
                  key: const Key('language-selected-rule'),
                  color: palette.ember,
                ),
              ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(22, 15, 22, 15),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: SizedBox(
                      width: 58,
                      child: Text(
                        _code,
                        style: palette.overline.copyWith(
                          color: selected ? palette.ember : palette.inkFaint,
                          letterSpacing: 1.35,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      option.label(context.l10n),
                      style: palette.body.copyWith(
                        color: palette.ink,
                        fontSize: 17,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        letterSpacing: selected ? -0.25 : -0.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox.square(
                    dimension: 16,
                    child: selected
                        ? DecoratedBox(
                            key: const Key('language-selected-mark'),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: palette.ember,
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: ColoredBox(
                                color: palette.ember,
                                child: const SizedBox.square(dimension: 6),
                              ),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
            if (!isLast)
              PositionedDirectional(
                start: 22,
                end: 0,
                bottom: 0,
                child: ColoredBox(
                  color: palette.hairline,
                  child: const SizedBox(height: 0.5),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String get _code {
    if (option == AppLocale.system) return 'AUTO';
    final locale = option.locale!;
    final language = locale.languageCode.toUpperCase();
    final country = locale.countryCode;
    return country == null ? language : '$language·$country';
  }
}
