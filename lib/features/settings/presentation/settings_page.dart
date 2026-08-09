import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_scope.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/icon_orb.dart';
import '../../notes/domain/retention.dart';
import '../../../l10n/enum_labels.dart';
import '../../../l10n/l10n_context.dart';
import '../domain/app_locale.dart';
import '../data/settings_repository.dart';
import '../domain/app_settings.dart';
import 'widgets/pro_callout.dart';
import 'widgets/settings_pieces.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../core/theme/app_shape.dart';
import '../../paywall/presentation/paywall_host.dart';
import '../../notes/presentation/widgets/retention_selector.dart';
import '../../../core/utils/legal_links.dart';
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
/// Ayarlar ekranında dokuz satır yan yana durunca sayfa okunmaz hâle geliyordu.
/// Seçim, iOS'un kendi kalıbındaki gibi ayrı bir yüzeye taşındı: satırda
/// yürürlükteki dil görünür, dokunulduğunda liste açılır.
Future<void> showLanguageSheet(
  BuildContext context, {
  required AppLocale value,
  required ValueChanged<AppLocale> onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.6),
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
    final maxHeight =
        media.size.height - media.padding.top - media.padding.bottom - 12;

    return Padding(
      padding: EdgeInsets.only(bottom: media.padding.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: palette.canvasLift,
            shape: RoundedSuperellipseBorder(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppShape.panel),
              ),
              side: BorderSide(color: palette.hairlineBright, width: 0.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
                child: Text(context.l10n.languageTitle, style: palette.title),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 14),
                  children: [
                    for (final option in AppLocale.values)
                      Pressable(
                        onPressed: () {
                          onChanged(option);
                          Navigator.of(context).pop();
                        },
                        scale: 0.995,
                        semanticLabel: option.label(context.l10n),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 13,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  option.label(context.l10n),
                                  style: option == value
                                      ? palette.bodyStrong
                                      : palette.body.copyWith(
                                          color: palette.inkSoft,
                                        ),
                                ),
                              ),
                              if (option == value)
                                Icon(
                                  Icons.check_rounded,
                                  size: 18,
                                  color: palette.ember,
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
