import 'package:flutter/painting.dart';

/// Köşe ölçeği.
///
/// İki karar var, ikisi de bilinçli.
///
/// **Değerler küçük.** Her yüzeyi cömertçe yuvarlatmak onları birbirine
/// benzetiyor ve arayüzü şablon gibi gösteriyor. Özellikle fotoğraf: baskının
/// köşesi neredeyse dik olmalı, aksi halde kare bir "kart bileşeni"ne dönüşüyor.
///
/// **Köşeler dairesel yay değil, süperelips.** Apple'ın şekillerini yumuşak
/// gösteren şey yarıçapın büyüklüğü değil, eğriliğin kenardan köşeye doğru
/// *sürekli* değişmesi. Dairesel yayda kenarla yayın birleştiği yerde eğrilik
/// sıçrar; göz bunu bir kırılma olarak okur. `BorderRadius.circular` tam da o
/// sıçramayı üretir — bu yüzden yüzeyler [RoundedSuperellipseBorder] ya da
/// `ClipRSuperellipse` ile çizilir.
abstract final class AppShape {
  /// Baskı: fotoğrafın kendi köşesi.
  static const print = 10.0;

  /// Panel, sheet, tam genişlikte yüzey.
  static const panel = 18.0;

  /// Düğme ve seçim kontrolü.
  static const control = 11.0;

  /// Küçük işaret, rozet, alan.
  static const chip = 8.0;

  static BorderRadius all(double value) => BorderRadius.circular(value);

  /// Kenarlığı olan yüzeyler için hazır süperelips şekli.
  static RoundedSuperellipseBorder border(double value, {BorderSide? side}) =>
      RoundedSuperellipseBorder(
        borderRadius: BorderRadius.circular(value),
        side: side ?? BorderSide.none,
      );
}
