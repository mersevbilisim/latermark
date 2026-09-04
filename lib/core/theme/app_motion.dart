import 'package:flutter/widgets.dart';

/// Hareket dili. Tüm animasyonlar bu üç süre ve iki eğriden türer; böylece
/// uygulama tek bir ritimde nefes alır.
abstract final class AppMotion {
  /// Dokunma geri bildirimi — göz kırpma hızında.
  static const fast = Duration(milliseconds: 180);

  /// Standart geçiş — panel açılması, seçim kayması.
  static const medium = Duration(milliseconds: 340);

  /// Sahne değişimi — sayfa geçişleri, düzen morflaması.
  static const slow = Duration(milliseconds: 620);

  /// Diyaframın boşta nefes alma döngüsü.
  static const breath = Duration(milliseconds: 4200);

  /// Yavaşlayarak yerine oturan hareketler (varsayılan).
  static const ease = Curves.easeOutCubic;

  /// Fiziksel his gereken yerlerde (kayan seçim pili, deklanşör).
  static const spring = Curves.easeOutBack;

  /// Kaybolan öğeler.
  static const exit = Curves.easeInCubic;

  /// Yer değiştiren, ölçeklenen ya da büyüyen bir hareketin süresi.
  ///
  /// "Hareketi azalt" açıkken sıfır: sahne kurulmaz, kurulmuş olarak gelir.
  /// Ölçüldü — diyafram ilk kayıtta ekranın ortasından şeride **362 pt** yol
  /// alıyordu ve tercih açıkken de alıyordu; uygulamanın en büyük hareketi
  /// tam da hareketten rahatsız olan kullanıcıya gidiyordu.
  ///
  /// Solmalar bu kapıdan **geçmiyor**. Erişilebilirlik sayfası "derinlik
  /// geçişlerini yumuşak solmalarla değiştirir" diyor: kalkan hareket, kalan
  /// solma. Dokunma geri bildirimi (basılınca içeri çöken düğme) da kalıyor —
  /// o dekoratif değil, parmağın altındaki doğrudan karşılık.
  static Duration travel(BuildContext context, Duration base) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : base;
}
