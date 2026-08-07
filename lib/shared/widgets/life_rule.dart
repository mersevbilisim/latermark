import 'package:flutter/widgets.dart';

import '../../core/theme/app_palette.dart';

/// Kalan ömrü gösteren ince iz.
///
/// Uygulamada süre tek bir biçimde anlatılır: künyenin devamı olarak uzanan ve
/// kısalan bir çizgi. Akıştaki kart da, fotoğrafın altındaki panel de aynı izi
/// kullanır — böylece kullanıcı iki ayrı gösterge öğrenmek zorunda kalmaz.
class LifeRule extends StatelessWidget {
  const LifeRule({
    super.key,
    required this.left,
    this.track,
    this.fill,
    this.height = 2,
  });

  /// Ömrün kalan oranı: 1 = yeni, 0 = süresi doldu.
  final double left;

  /// Boş kısım. Verilmezse paletten alınır — fotoğraf üstünde [OnPhoto]
  /// değerleri açıkça geçilmeli.
  final Color? track;

  /// Dolu kısım.
  final Color? fill;

  final double height;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: track ?? palette.hairline),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: left.clamp(0.0, 1.0),
            child: ColoredBox(color: fill ?? palette.ember),
          ),
        ],
      ),
    );
  }
}

/// Ömrün kalan oranı: 1 = yeni, 0 = süresi doldu.
double lifeFraction(DateTime createdAt, DateTime expiresAt, DateTime now) {
  final total = expiresAt.difference(createdAt).inSeconds;
  if (total <= 0) return 0;
  return (expiresAt.difference(now).inSeconds / total).clamp(0.0, 1.0);
}
