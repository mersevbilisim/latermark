import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_palette.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/icon_orb.dart';
import '../../notes/domain/retention.dart';
import '../../../l10n/enum_labels.dart';
import '../../../l10n/l10n_context.dart';
import '../domain/app_locale.dart';
import '../data/settings_repository.dart';
import '../domain/app_settings.dart';
import 'widgets/settings_pieces.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../core/theme/app_shape.dart';
import '../../paywall/presentation/paywall_host.dart';
import '../../notes/presentation/widgets/retention_selector.dart';
import '../../../core/utils/legal_links.dart';

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
          SliverToBoxAdapter(child: _Header(palette: palette)),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              22,
              0,
              22,
              MediaQuery.paddingOf(context).bottom + 32,
            ),
            sliver: SliverList.list(
              children: [
                SettingsSection(
                  title:
                      '${context.l10n.appTitle.toUpperCase()} ${context.l10n.proBadge}',
                  children: [
                    Pressable(
                      onPressed: () => showPaywall(context),
                      scale: 0.995,
                      semanticLabel: context.l10n.paywallCta,
                      child: SettingsRow(
                        title: context.l10n.paywallHeadline,
                        description: context.l10n.paywallSubtitle,
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: palette.inkFaint,
                        ),
                      ),
                    ),
                  ],
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
                            Text(
                              settings.locale.label(context.l10n),
                              style: palette.body.copyWith(
                                color: palette.inkSoft,
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

class _Header extends StatelessWidget {
  const _Header({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        MediaQuery.paddingOf(context).top + 10,
        22,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconOrb(
            icon: Icons.arrow_back_rounded,
            semanticLabel: context.l10n.actionBack,
            onPressed: () => Navigator.of(context).maybePop(),
            size: 38,
            iconSize: 18,
            tint: palette.ink,
            fill: palette.canvasLift,
          ),
          const SizedBox(height: 26),
          Text(context.l10n.settingsTitle, style: palette.display),
        ],
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
          style: palette.label.copyWith(color: palette.inkSoft),
        ),
      ),
    );

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          link(l10n.legalPrivacy, LegalLinks.privacy(context)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '·',
              style: palette.label.copyWith(color: palette.inkGhost),
            ),
          ),
          link(l10n.legalTerms, LegalLinks.terms),
        ],
      ),
    );
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

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
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
                              : palette.body.copyWith(color: palette.inkSoft),
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
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}
