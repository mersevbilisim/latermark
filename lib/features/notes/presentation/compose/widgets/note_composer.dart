import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_palette.dart';
import '../../../../../l10n/l10n_context.dart';
import '../../../../../core/utils/app_format.dart';

/// Yazı alanı ve altındaki tek kontrol.
///
/// Hem yeni kayıt ekranında hem de düzenleme panelinde aynı gövde kullanılır.
/// Aradaki kontrol sabit değil, [extra] ile veriliyor: yeni kayıtta hatırlatma
/// süresi, düzenlemede saklama süresi duruyor. Çekim akışında tek karar olsun
/// diye ikisi aynı anda gösterilmiyor.
class NoteComposer extends StatelessWidget {
  const NoteComposer({
    super.key,
    required this.controller,
    required this.action,
    this.extra,
    this.focusNode,
    this.header,
    this.autofocus = false,
    this.hintText,
    this.expand = true,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;

  /// Yazı alanı ile eylem arasında duran kontrol.
  final Widget? extra;

  /// Alt kısımdaki eylem(ler).
  final Widget action;

  /// Yazı alanının üstünde görünecek isteğe bağlı satır (tarih vb.).
  final Widget? header;

  final bool autofocus;
  final String? hintText;

  /// `true` ise yazı alanı kalan tüm yüksekliği kaplar (tam ekran yazma),
  /// `false` ise içeriğe göre büyür (panel içinde).
  final bool expand;

  /// Yazı alanının pes etmeyeceği taban.
  ///
  /// Alan, düzendeki tek esneyen parçaydı: fotoğraf tabanını, hatırlatma
  /// bloğu ve alt şerit boyunu koruduğu için klavye açılınca kaybın tamamını
  /// o yutuyor ve bir–iki satıra çöküyordu (ölçüldü: 393×852'de 51pt,
  /// 400pt'lik klavyede 25pt). Artık bu tabanın altına inmiyor; sığmayan
  /// durumda alanı küçültmek yerine sayfa kayıyor.
  static const double minFieldExtent = 104;

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
      keyboardAppearance: palette.brightness,
      style: palette.body.copyWith(fontSize: 17, height: 1.45),
      cursorColor: palette.ember,
      cursorWidth: 2,
      cursorRadius: const Radius.circular(2),
      decoration: InputDecoration.collapsed(
        hintText: hintText ?? context.l10n.composeHint,
        hintStyle: palette.body.copyWith(fontSize: 17, color: palette.inkGhost),
      ),
    );

    if (!expand) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (header != null) ...[header!, const SizedBox(height: 14)],
          field,
          if (extra != null) ...[const SizedBox(height: 20), extra!],
          const SizedBox(height: 18),
          action,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null) ...[header!, const SizedBox(height: 14)],
        Expanded(
          child: LayoutBuilder(
            builder: (context, viewport) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Yazı alanı kalan yeri kaplar ve **kendi içinde** kayar.
                // Eskiden alan metinle birlikte uzuyordu: sayfa kayıyor,
                // hatırlatma satırı aşağı kaçıyor ve uzun bir notta imleç
                // ekrandan çıkıyordu. Uzayan şey artık düzen değil, metin.
                Expanded(child: field),
                if (extra != null) ...[
                  const SizedBox(height: 20),
                  // Seçenekler yerinde duruyor; yalnızca aşırı yazı
                  // ölçeğinde kendi içinde kayıyor. Sınır, yazı alanının
                  // tabanını her koşulda koruyor.
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: math.max(
                        0,
                        viewport.maxHeight - minFieldExtent - 20,
                      ),
                    ),
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: extra!,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
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
        Expanded(child: Text(context.l10n.upper(at), style: palette.overline)),
        ?trailing,
      ],
    );
  }
}
