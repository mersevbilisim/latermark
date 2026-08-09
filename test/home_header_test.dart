import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/core/theme/app_palette.dart';
import 'package:latermark/core/theme/app_theme.dart';
import 'package:latermark/features/notes/presentation/home/widgets/home_header.dart';
import 'package:latermark/l10n/app_localizations.dart';
import 'package:latermark/shared/widgets/icon_orb.dart';

void main() {
  testWidgets(
    'arama ve ayarlar ayni cam yuzeyi ve dokunma davranisini kullanir',
    (tester) async {
      final searchController = TextEditingController();
      final searchFocus = FocusNode();
      addTearDown(searchController.dispose);
      addTearDown(searchFocus.dispose);

      var searchTaps = 0;
      var settingsTaps = 0;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('tr'),
          supportedLocales: L10n.supportedLocales,
          localizationsDelegates: L10n.localizationsDelegates,
          theme: AppTheme.dark(),
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: HomeHeader(
                    palette: AppPalette.dark,
                    topPadding: 0,
                    noteCount: 0,
                    onOpenSettings: () => settingsTaps++,
                    searching: false,
                    resultCount: 0,
                    searchController: searchController,
                    searchFocus: searchFocus,
                    onSearchChanged: (_) {},
                    onToggleSearch: () => searchTaps++,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 800)),
              ],
            ),
          ),
        ),
      );

      final searchOrb = tester.widget<IconOrb>(
        find.byWidgetPredicate(
          (widget) => widget is IconOrb && widget.icon == Icons.search_rounded,
        ),
      );
      final settingsOrb = tester.widget<IconOrb>(
        find.byWidgetPredicate(
          (widget) => widget is IconOrb && widget.icon == Icons.tune_rounded,
        ),
      );

      expect(searchOrb.fill, AppPalette.dark.glass);
      expect(settingsOrb.fill, searchOrb.fill);

      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.tap(find.byIcon(Icons.tune_rounded));

      expect(searchTaps, 1);
      expect(settingsTaps, 1);
    },
  );
}
