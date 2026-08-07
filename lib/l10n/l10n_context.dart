import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

/// `context.l10n` kısayolu.
///
/// `L10n.of(context)` her çağrı yerinde uzun kalıyor; metin okuma bu kadar sık
/// yapılan bir iş olunca kısayol okunabilirliği belirgin biçimde artırıyor.
extension L10nContext on BuildContext {
  L10n get l10n => L10n.of(this);
}
