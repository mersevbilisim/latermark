import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latermark/core/utils/app_format.dart';
import 'package:latermark/l10n/app_localizations.dart';

void main() {
  setUpAll(() => initializeDateFormatting());

  test('dosya boyutu yerele göre biçimleniyor', () async {
    final tr = await L10n.delegate.load(const Locale('tr'));
    final en = await L10n.delegate.load(const Locale('en'));

    expect(tr.fileSize(512), '512 B');
    expect(tr.fileSize(820 * 1024), '820 KB');
    // Türkçede ondalık ayracı virgül.
    expect(tr.fileSize((4.2 * 1024 * 1024).round()), '4,2 MB');
    expect(en.fileSize((4.2 * 1024 * 1024).round()), '4.2 MB');
  });
}
