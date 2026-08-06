import 'package:flutter/material.dart';

import '../../../../../core/theme/app_palette.dart';
import '../../../../../core/utils/tr_format.dart';
import '../../../domain/retention.dart';
import '../../widgets/retention_selector.dart';

/// Yazı alanı + "Otomatik Sil" seçimi.
///
/// Hem yeni kayıt ekranında hem de düzenleme panelinde aynı gövde kullanılır;
/// aralarındaki tek fark [header] ve [action].
class NoteComposer extends StatelessWidget {
  const NoteComposer({
    super.key,
    required this.controller,
    required this.retention,
    required this.onRetentionChanged,
    required this.action,
    this.focusNode,
    this.header,
    this.autofocus = false,
    this.hintText = 'Bunu neden çektin?',
    this.expand = true,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final Retention retention;
  final ValueChanged<Retention> onRetentionChanged;

  /// Alt kısımdaki eylem(ler).
  final Widget action;

  /// Yazı alanının üstünde görünecek isteğe bağlı satır (tarih vb.).
  final Widget? header;

  final bool autofocus;
  final String hintText;

  /// `true` ise yazı alanı kalan tüm yüksekliği kaplar (tam ekran yazma),
  /// `false` ise içeriğe göre büyür (panel içinde).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      maxLines: expand ? null : 6,
      minLines: expand ? null : 3,
      expands: expand,
      textAlignVertical: TextAlignVertical.top,
      textCapitalization: TextCapitalization.sentences,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      keyboardAppearance: Brightness.dark,
      style: palette.body.copyWith(fontSize: 17, height: 1.45),
      cursorColor: palette.ember,
      cursorWidth: 2,
      cursorRadius: const Radius.circular(2),
      decoration: InputDecoration.collapsed(
        hintText: hintText,
        hintStyle: palette.body.copyWith(
          fontSize: 17,
          color: palette.inkGhost,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null) ...[header!, const SizedBox(height: 14)],
        if (expand) Expanded(child: field) else field,
        const SizedBox(height: 20),
        RetentionSelector(value: retention, onChanged: onRetentionChanged),
        const SizedBox(height: 18),
        action,
      ],
    );
  }
}

/// Kaydın zaman damgası. Kor rengi nokta, notun "canlı" olduğunu ima eder.
class ComposerStamp extends StatelessWidget {
  const ComposerStamp({super.key, required this.at, this.trailing});

  final String at;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: palette.ember,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(child: Text(TrFormat.upper(at), style: palette.overline)),
        ?trailing,
      ],
    );
  }
}
