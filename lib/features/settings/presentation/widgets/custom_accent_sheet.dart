import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/accent_tone.dart';
import '../../../../core/theme/app_accent.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/l10n_context.dart';
import '../../../../shared/widgets/aperture.dart';
import '../../../../shared/widgets/primary_button.dart';

/// Özel vurgu rengi paneli.
///
/// Seçici bilinçli olarak **tek eksenli**: kullanıcı yalnızca tonu çeviriyor.
/// Parlaklık ve renklilik uygulamaya ait (bkz. [AccentTone]) — bu yüzden
/// halkada görünen renkler, uygulamanın gerçekten üretebileceği renklerin ta
/// kendisi. Kullanıcı seçtiği tonun sonradan "düzeltildiğini" görmüyor.
///
/// Önizleme ayrı bir renk kutusu değil, **deklanşörün kendisi**: rengin asıl
/// yaşayacağı nesne o. Böylece panel jenerik bir renk seçici olmaktan çıkıp
/// bu uygulamaya ait bir denetim oluyor.
Future<void> showCustomAccentSheet(
  BuildContext context, {
  required int hue,
  required ValueChanged<int> onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.68),
    isScrollControlled: true,
    builder: (context) => _CustomAccentSheet(hue: hue, onChanged: onChanged),
  );
}

class _CustomAccentSheet extends StatefulWidget {
  const _CustomAccentSheet({required this.hue, required this.onChanged});

  final int hue;
  final ValueChanged<int> onChanged;

  @override
  State<_CustomAccentSheet> createState() => _CustomAccentSheetState();
}

class _CustomAccentSheetState extends State<_CustomAccentSheet> {
  late int _hue = AccentTone.normalizeHue(widget.hue);

  /// Sürüklerken her karede tek tek çözülmesinler diye halkanın renkleri bir
  /// kez üretilip saklanıyor.
  late final List<Color> _darkWheel = [
    for (var h = 0; h < AccentTone.hueCount; h++)
      AccentTone.colorFor(h, Brightness.dark),
  ];
  late final List<Color> _lightWheel = [
    for (var h = 0; h < AccentTone.hueCount; h++)
      AccentTone.colorFor(h, Brightness.light),
  ];

  /// Son geri bildirim verilen ton. Sürükleme sırasında her derecede titremek
  /// bir denetimi değil, bozuk bir motoru andırıyordu.
  int _lastHaptic = -1;

  void _setHue(int value) {
    final next = AccentTone.normalizeHue(value);
    if (next == _hue) return;
    if ((next - _lastHaptic).abs() >= 6) {
      _lastHaptic = next;
      HapticFeedback.selectionClick();
    }
    setState(() => _hue = next);
  }

  @override
  Widget build(BuildContext context) {
    // Panelin tamamı seçilen tonu **yaşıyor**: şerit, diyafram ve onay
    // düğmesi. Yalnızca önizlemeyi boyayıp düğmeyi eski renkte bırakmak,
    // kullanıcıya aynı ekranda iki farklı cevap vermek olurdu.
    final brightness = context.palette.brightness;
    final theme = brightness == Brightness.dark
        ? AppTheme.dark(AppAccent.custom, _hue)
        : AppTheme.light(AppAccent.custom, _hue);

    return Theme(
      data: theme,
      child: Builder(builder: _surface),
    );
  }

  Widget _surface(BuildContext context) {
    final palette = context.palette;
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height - media.padding.top - 12;
    final compact = maxHeight < 640;
    final color = palette.isDark ? _darkWheel[_hue] : _lightWheel[_hue];

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: DecoratedBox(
        key: const Key('custom-accent-sheet-surface'),
        decoration: BoxDecoration(
          color: palette.canvasLift,
          border: Border(
            top: BorderSide(color: palette.hairlineBright, width: 0.5),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Dil panelindeki kalibrasyon izinin aynısı; iki panel aynı
                // aileden okunuyor. Bu şerit seçilen tonu anında gösteriyor.
                SizedBox(
                  height: 2,
                  child: Stack(
                    children: [
                      PositionedDirectional(
                        start: 22,
                        top: 0,
                        bottom: 0,
                        width: 38,
                        child: ColoredBox(color: color),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(22, compact ? 16 : 20, 22, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('LATERMARK', style: palette.overline),
                      const SizedBox(height: 6),
                      Text(
                        context.l10n.accentCustomTitle,
                        style: palette.title,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.accentCustomHint,
                        style: palette.caption.copyWith(
                          color: palette.inkFaint,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: compact ? 12 : 20,
                  ),
                  child: Center(
                    child: _HueDial(
                      hue: _hue,
                      wheel: palette.isDark ? _darkWheel : _lightWheel,
                      onHue: _setHue,
                      // Panel dar telefonda da taşmasın: kadran eldeki
                      // genişliğe göre küçülüyor, tavanı sabit.
                      maxDiameter: compact ? 208 : 248,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(22, 0, 22, compact ? 16 : 22),
                  child: PrimaryButton(
                    label: context.l10n.accentCustomApply,
                    onPressed: () {
                      widget.onChanged(_hue);
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Diyaframın etrafındaki ton halkası.
class _HueDial extends StatelessWidget {
  const _HueDial({
    required this.hue,
    required this.wheel,
    required this.onHue,
    required this.maxDiameter,
  });

  final int hue;
  final List<Color> wheel;
  final ValueChanged<int> onHue;
  final double maxDiameter;

  /// Halkanın kalınlığı ve içeriye bıraktığı pay.
  static const _ring = 16.0;
  static const _gap = 18.0;

  /// Ekran okuyucunun tek adımı. Bir derece, dokunmadan çeviren için
  /// anlamsız derecede ince; 10° çemberi 36 durakta dolaşıyor.
  static const _semanticStep = 10;

  void _emit(Offset local, Size size) {
    final center = size.center(Offset.zero);
    final delta = local - center;
    if (delta.distance < 8) return;
    // Sıfır derece saat 12'de: kadranın üstü, elin doğal başlangıcı.
    final angle = math.atan2(delta.dx, -delta.dy);
    onHue((angle * 180 / math.pi).round());
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return LayoutBuilder(
      builder: (context, constraints) {
        final diameter = math.min(
          maxDiameter,
          constraints.maxWidth.isFinite ? constraints.maxWidth : maxDiameter,
        );
        final size = Size.square(diameter);
        final inner = diameter - (_ring + _gap) * 2;

        return Semantics(
          slider: true,
          // Adı olmadan ekran okuyucuda yalnız "36 derece" diye duruyordu:
          // neyin derecesi olduğu kayıptı.
          label: context.l10n.accentCustomTitle,
          value: '$hue°',
          increasedValue: '${AccentTone.normalizeHue(hue + _semanticStep)}°',
          decreasedValue: '${AccentTone.normalizeHue(hue - _semanticStep)}°',
          onIncrease: () => onHue(hue + _semanticStep),
          onDecrease: () => onHue(hue - _semanticStep),
          child: RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            // Semantiği yukarıdaki katman yazıyor; işaretçinin kendi
            // kaydırma eylemlerini de eklemesi kadranı iki kere anlatırdı.
            excludeFromSemantics: true,
            gestures: <Type, GestureRecognizerFactory>{
              _DialDragRecognizer:
                  GestureRecognizerFactoryWithHandlers<_DialDragRecognizer>(
                    _DialDragRecognizer.new,
                    (recognizer) {
                      recognizer
                        ..center = size.center(Offset.zero)
                        // Ortadaki deklanşör bir denetim değil, önizleme:
                        // dokunma bandı onun dışında başlıyor. Bant çizilen
                        // halkadan kalın, parmak kıl payı ıskalamasın.
                        ..deadZone = inner / 2
                        ..onStart = (d) {
                          _emit(d.localPosition, size);
                        }
                        ..onUpdate = (d) {
                          _emit(d.localPosition, size);
                        };
                    },
                  ),
            },
            child: SizedBox.square(
              key: const Key('custom-accent-dial'),
              dimension: diameter,
              child: CustomPaint(
                painter: _HueRingPainter(
                  hue: hue,
                  wheel: wheel,
                  ring: _ring,
                  track: palette.hairline,
                  handleEdge: palette.canvasLift,
                ),
                child: Center(
                  child: SizedBox.square(
                    dimension: inner,
                    child: Aperture(
                      // Ana ekrandaki deklanşörün dinlenme açıklığı. Önizleme
                      // "renge benzeyen bir şey" değil, kullanıcının birazdan
                      // göreceği nesnenin ta kendisi olmalı.
                      openness: 1,
                      bladeBase: palette.isDark
                          ? palette.canvas
                          : OnPhoto.canvasDeep,
                      edgeTint: AccentTone.onPhoto(hue),
                      accent: AccentTone.onPhoto(hue),
                      barrel: palette.isDark
                          ? palette.canvas
                          : OnPhoto.canvasDeep,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Kadranın kendi sürükleme işaretçisi.
///
/// Panel iki jest daha taşıyor: kendi aşağı çekip kapatması ve içindeki
/// kaydırma. İkisinin de eşiği [kTouchSlop], sürüklemeninki [kPanSlop] —
/// yani iki katı. Dikey bileşeni olan her el hareketinde arenayı onlar
/// kazanıyordu: kullanıcı halkanın solunu ya da sağını çevirmeye kalkınca
/// tutamak yerinde kalıyor, bunun yerine panel kayıp kapanıyordu.
///
/// Halkaya dokunmak tek bir şey demek olduğu için işaretçi parmak daha
/// kımıldamadan arenayı alıyor. Ortadaki deklanşör bandın dışında: oradan
/// başlayan sürükleme hâlâ paneli kapatabiliyor.
class _DialDragRecognizer extends PanGestureRecognizer {
  /// Kadranın merkezi ve el hareketinin sahiplenilmediği orta bölgenin
  /// yarıçapı — ikisi de her yerleşimde tazeleniyor.
  Offset center = Offset.zero;
  double deadZone = 0;

  @override
  bool isPointerAllowed(PointerEvent event) =>
      (event.localPosition - center).distance >= deadZone &&
      super.isPointerAllowed(event);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

class _HueRingPainter extends CustomPainter {
  _HueRingPainter({
    required this.hue,
    required this.wheel,
    required this.ring,
    required this.track,
    required this.handleEdge,
  });

  final int hue;
  final List<Color> wheel;
  final double ring;
  final Color track;
  final Color handleEdge;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - ring / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Halka, uygulamanın **gerçekten üretebileceği** tonlardan oluşuyor.
    // Doymuş bir HSV çemberi çizmek, seçilen rengin sonradan değiştirildiği
    // izlenimini verirdi.
    final step = 2 * math.pi / wheel.length;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ring;
    for (var i = 0; i < wheel.length; i++) {
      arc.color = wheel[i];
      canvas.drawArc(
        rect,
        -math.pi / 2 + i * step,
        // Dilimler arasında kıl payı bindirme: aksi hâlde kenarlarda zemin
        // sızan ince çizgiler kalıyor.
        step * 1.35,
        false,
        arc,
      );
    }

    canvas.drawCircle(
      center,
      radius + ring / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = track,
    );

    // Tutamak ayrı bir renk lekesi değil: halkanın o noktasını **açan** bir
    // çentik. Renk zaten altında duruyor.
    final angle = -math.pi / 2 + hue * step;
    final knob = center + Offset(math.cos(angle), math.sin(angle)) * radius;
    canvas.drawCircle(knob, ring / 2 + 3, Paint()..color = handleEdge);
    canvas.drawCircle(knob, ring / 2, Paint()..color = wheel[hue]);
    canvas.drawCircle(
      knob,
      ring / 2 + 3,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = wheel[hue],
    );
  }

  @override
  bool shouldRepaint(_HueRingPainter old) =>
      old.hue != hue ||
      old.ring != ring ||
      old.track != track ||
      old.handleEdge != handleEdge ||
      !identical(old.wheel, wheel);
}
