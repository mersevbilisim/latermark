import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

/// `context.l10n` kısayolu.
///
/// `L10n.of(context)` her çağrı yerinde uzun kalıyor; metin okuma bu kadar sık
/// yapılan bir iş olunca kısayol okunabilirliği belirgin biçimde artırıyor.
extension L10nContext on BuildContext {
  L10n get l10n => L10n.of(this);

  /// Cihazın "24 Saat" anahtarı.
  ///
  /// Saat biçimi yalnız dilin işi değil: Türkçe zaten `14:32` yazar ama
  /// ayarlardan bu anahtarı açmış bir ABD kullanıcısı da `14:32` görmek ister.
  /// Yerelin varsayılanı bunu bilmiyor; sistem tercihi biliyor.
  bool get use24Hour => MediaQuery.alwaysUse24HourFormatOf(this);
}
