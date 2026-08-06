import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_palette.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/icon_orb.dart';
import '../data/settings_repository.dart';
import '../domain/app_settings.dart';
import 'widgets/settings_pieces.dart';

/// Ayarlar.
///
/// Kartlara bölünmüş bir liste yerine, bölümleri yalnızca tipografiyle ayrılan
/// tek bir sayfa. Her ayar ne yaptığını bir cümleyle söylüyor, böylece
/// açıklama için ayrı bir yardım metnine gerek kalmıyor.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final settings = AppScope.preferences(context);
    final repository = AppScope.settingsOf(context);

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
                  title: 'Görünüm',
                  children: [
                    SettingsRow(
                      title: 'Tema',
                      description:
                          'Sistemi izleyebilir ya da tek bir tarafta '
                          'kalabilirsin.',
                      below: Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: ChoiceRail<AppThemeMode>(
                          options: AppThemeMode.values,
                          value: settings.themeMode,
                          labelOf: (mode) => mode.label,
                          onChanged: repository.setThemeMode,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    SettingsRow(
                      title: 'Akış',
                      description:
                          'Kareler büyük dursun ya da ızgarada daha çok kayıt '
                          'görünsün.',
                      below: Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: ChoiceRail<FeedDensity>(
                          options: FeedDensity.values,
                          value: settings.density,
                          labelOf: (density) => density.label,
                          onChanged: repository.setDensity,
                        ),
                      ),
                    ),
                  ],
                ),

                SettingsSection(
                  title: 'Hatırlatma',
                  children: [
                    SettingsRow(
                      title: 'Unutulanları hatırlat',
                      description:
                          'Bir kayda uzun süre bakmazsan sana seslenir. '
                          'Kaydı her açtığında sayaç sıfırlanır.',
                      trailing: InkSwitch(
                        value: settings.reminderEnabled,
                        semanticLabel: 'Hatırlatmalar',
                        onChanged: (value) =>
                            _toggleReminders(context, repository, value),
                      ),
                    ),
                    const SizedBox(height: 18),
                    ChoiceRail<ReminderDelay>(
                      options: ReminderDelay.values,
                      value: settings.reminderDelay,
                      labelOf: (delay) => delay.label,
                      enabled: settings.reminderEnabled,
                      onChanged: repository.setReminderDelay,
                    ),
                  ],
                ),

                const SizedBox(height: 48),
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
  /// İzin reddedilse bile ayar açık kalır: kullanıcı sistem ayarlarından izin
  /// verdiği anda hatırlatmalar kendiliğinden çalışmaya başlasın diye.
  Future<void> _toggleReminders(
    BuildContext context,
    SettingsRepository repository,
    bool value,
  ) async {
    final reminders = context.reminders;
    await repository.setReminderEnabled(value);
    if (!value) return;

    final granted = await reminders.requestPermission();
    if (!context.mounted || granted) return;
    showToast(
      context,
      'Bildirim izni verilmedi. Ayarlar’dan açabilirsin.',
      error: true,
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
            semanticLabel: 'Geri',
            onPressed: () => Navigator.of(context).maybePop(),
            size: 38,
            iconSize: 18,
            tint: palette.ink,
            fill: palette.glass,
          ),
          const SizedBox(height: 26),
          Text('Ayarlar', style: palette.display),
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
            : 'Sürüm ${info.version} (${info.buildNumber})';

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
