import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/app_palette.dart';
import '../../l10n/l10n_context.dart';
import '../../core/utils/app_format.dart';

/// Sayfanın dibindeki eylem şeridi — künye dili.
///
/// Uygulamanın sesi tipografik: not detayının tepesindeki tarih de, boş
/// ekrandaki manifesto da geniş harf aralıklı büyük harf. Alt şeritler bir
/// zamanlar Material sekme çubuğu konuşuyordu; sekme çubuğu *eşitler arasında
/// gezinmek* için bir kalıp, oysa bunlar gezinme değil, sayfada yapılan işler.
///
/// Bu yüzden kutu yok. Kabın yalnızca işe yarayan kenarı var: üstteki güverte
/// çizgisi, "içerik burada bitti" diyen sınır. Kelimeler tam mürekkeple
/// duruyor — soluk metin göze *açıklama* diye okunur, kabı ve ikonu olmayan
/// bir şeritte "dokunulur" bilgisi yalnızca ağırlıktan gelir. Aralarındaki kor
/// çizgiler künyedekiyle aynı [ColophonTick].
class ColophonBar extends StatelessWidget {
  const ColophonBar({
    super.key,
    required this.actions,
    this.height = 52,
    this.rule = true,
  });

  final List<ColophonAction> actions;

  /// Güverte çizgisi dâhil şeridin yüksekliği.
  final double height;

  /// Şeridi zaten sınırlayan bir yüzeyin içindeyse kapatılır: iki çizgi
  /// birkaç puan arayla üst üste gelince sınır değil, kusur okunuyor.
  final bool rule;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final cells = <Widget>[];

    for (var i = 0; i < actions.length; i++) {
      if (i > 0) cells.add(ColophonTick(color: palette.ember));
      cells.add(
        Expanded(
          child: _ColophonWord(key: actions[i].key, action: actions[i]),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: Column(
        children: [
          if (rule)
            SizedBox(
              width: double.infinity,
              height: 0.5,
              child: ColoredBox(color: palette.hairlineBright),
            ),
          Expanded(child: Row(children: cells)),
        ],
      ),
    );
  }
}

/// Künyenin noktalama işareti: 10×1 kor çizgi.
class ColophonTick extends StatelessWidget {
  const ColophonTick({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 10,
      height: 1,
      child: ColoredBox(color: color.withValues(alpha: 0.75)),
    );
  }
}

/// Şeritteki tek eylem.
///
/// [pressColor] yalnızca basılı hâlde görünür; yıkıcı eylem için tehlike
/// rengi, diğerleri için kor verilir.
///
/// [color] ise **dinlenirken** de görünüyor. Bir süre bütün kelimeler aynı
/// mürekkepte durdu ve sinyal yalnızca kararın verildiği anda beliriyordu;
/// yıkıcı eylem için bu yetmiyor. Kullanıcının bir kelimenin tehlikeli
/// olduğunu, ona basarak öğrenmesi gerekmiyor — silme onayı arkada dursa bile
/// hangi kelimenin ne yaptığı önceden okunmalı.
///
/// Kutu ya da kalınlık eklenmiyor: değişen tek şey mürekkebin rengi. Şerit
/// hâlâ üç eşit kelime, biri farklı bir şey söylüyor.
class ColophonAction {
  const ColophonAction({
    this.key,
    required this.label,
    required this.semanticLabel,
    required this.onPressed,
    this.color,
    this.pressColor,
    this.accent = false,
    this.busy = false,
    this.busyLabel,
  });

  final Key? key;
  final String label;
  final String semanticLabel;
  final VoidCallback? onPressed;

  /// Dinlenirken kelimenin rengi. Boşsa tam mürekkep (ya da [accent] ile kor).
  final Color? color;

  final Color? pressColor;

  /// Şeridin baskın eylemi kor renginde yazılır.
  ///
  /// Kutu yok, ikon yok: bir kelimenin "asıl olan" olduğunu söylemenin kalan
  /// tek yolu renk. Mürekkep tonundaki "KAYDET", yanındaki "VAZGEÇ" ile aynı
  /// ağırlıkta okunuyor ve gözden kaçıyordu.
  final bool accent;

  /// İş sürerken kelime nefes alır. Spinner yok: şeritte tek bir dönen çark
  /// hem Material'dan ödünç alınmış olur hem de tipografik satırın ritmini
  /// bozardı. Beklendiğini kelimenin kendisi söylüyor.
  final bool busy;

  /// Beklerken yerine geçen ad (ör. "KAYDEDİLİYOR"). Boşsa [label] kalır.
  final String? busyLabel;
}

class _ColophonWord extends StatefulWidget {
  const _ColophonWord({super.key, required this.action});

  final ColophonAction action;

  @override
  State<_ColophonWord> createState() => _ColophonWordState();
}

class _ColophonWordState extends State<_ColophonWord>
    with SingleTickerProviderStateMixin {
  /// Künyenin harf aralığı. Geniş aralık son harften sonra da bir boşluk
  /// bırakır; ortalanan kelime bu yüzden optik olarak sola kaçar. Hücre bu
  /// değer kadar soldan doldurulunca merkez yerine oturuyor.
  static const double tracking = 1.3;

  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  bool _down = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBreath();
  }

  @override
  void didUpdateWidget(_ColophonWord oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.action.busy != widget.action.busy) _syncBreath();
  }

  void _syncBreath() {
    if (!widget.action.busy) {
      _breath
        ..stop()
        ..value = 0;
      return;
    }
    // "Hareketi azalt" açıkken nefes yerine sabit bir sönüklük kalır: bilgi
    // kaybolmuyor, yalnızca kıpırdamıyor.
    if (MediaQuery.disableAnimationsOf(context)) {
      _breath
        ..stop()
        ..value = 0.5;
      return;
    }
    if (!_breath.isAnimating) _breath.repeat(reverse: true);
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  void _setDown(bool value) {
    if (_down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final action = widget.action;
    final enabled = action.onPressed != null && !action.busy;
    final label = action.busy
        ? (action.busyLabel ?? action.label)
        : action.label;

    return Semantics(
      button: true,
      enabled: enabled,
      label: action.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _setDown(true) : null,
        onTapUp: enabled ? (_) => _setDown(false) : null,
        onTapCancel: enabled ? () => _setDown(false) : null,
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                action.onPressed!();
              }
            : null,
        child: AnimatedScale(
          scale: _down ? 0.96 : 1,
          duration: AppMotion.fast,
          curve: AppMotion.ease,
          child: Center(
            child: Padding(
              // Bkz. [tracking]: son harften sonra kalan boşluğu dengeleyen
              // optik kaydırma.
              padding: const EdgeInsets.only(left: tracking),
              child: AnimatedBuilder(
                animation: _breath,
                builder: (context, child) => Opacity(
                  opacity: enabled || action.busy
                      ? 1 - _breath.value * 0.55
                      : 0.4,
                  child: child,
                ),
                child: AnimatedDefaultTextStyle(
                  duration: AppMotion.fast,
                  curve: AppMotion.ease,
                  style: palette.overline.copyWith(
                    color: _down
                        ? (action.pressColor ?? palette.ember)
                        : action.color ??
                              (action.accent ? palette.ember : palette.ink),
                    fontSize: 11,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    letterSpacing: tracking,
                  ),
                  child: Text(
                    context.l10n.upper(label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
