import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';

/// Compose içindeki isteğe bağlı kayıt bilgisinin sol tarafı.
///
/// Kart veya rozet değildir. İnce ikon, kısa kayıt işareti ve iki tipografik
/// seviye; sağdaki gerçek kontrolün ne yaptığını daha dokunmadan anlatır.
class NoteOptionLabel extends StatelessWidget {
  const NoteOptionLabel({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    required this.active,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = active ? palette.ember : palette.inkFaint;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: SizedBox(
            width: 21,
            height: 39,
            child: Column(
              children: [
                Icon(icon, size: 18, color: color),
                const Spacer(),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 2,
                  height: 8,
                  color: active ? palette.ember : palette.hairlineBright,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: palette.bodyStrong.copyWith(
                  color: active ? palette.ink : palette.inkSoft,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(
                  detail,
                  key: ValueKey(detail),
                  style: palette.caption.copyWith(
                    color: palette.inkFaint,
                    fontSize: 12.5,
                    height: 1.32,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Label ile mevcut seçim alanını uzun dil ve Dynamic Type'a göre yerleştirir.
class NoteOptionRow extends StatelessWidget {
  const NoteOptionRow({super.key, required this.label, required this.trailing});

  final Widget label;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Compose bu satıra iki yanda 22 px verir. Parent genişliğini öğrenmek
    // için LayoutBuilder kullanmak cazip görünse de satır IntrinsicHeight'lı
    // kaydırma gövdesinin içinde: Flutter LayoutBuilder'dan intrinsic ölçü
    // isteyemez. Aynı kullanılabilir genişliği ekran ölçüsünden çıkarmak hem
    // deterministik hem de o geçersiz ölçüm döngüsünü tamamen kaldırır.
    final availableWidth = media.size.width - 44;
    final textScale = media.textScaler.scale(1);
    final stacked = availableWidth < 300 || textScale > 1.25;

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          label,
          const SizedBox(height: 10),
          Align(alignment: AlignmentDirectional.centerEnd, child: trailing),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: label),
        const SizedBox(width: 14),
        trailing,
      ],
    );
  }
}
