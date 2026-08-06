import 'package:flutter/material.dart';

import '../../../../../core/theme/app_palette.dart';
import '../../../../../shared/widgets/primary_button.dart';

/// Kamera açılamadığında gösterilen sakin bilgilendirme.
///
/// Hata diyaloğu yerine tam ekran bir açıklama: kullanıcı ne olduğunu ve ne
/// yapacağını tek bakışta görür.
class CameraNotice extends StatelessWidget {
  const CameraNotice({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: OnPhoto.glass,
                border: Border.all(color: OnPhoto.hairline),
              ),
              child: Icon(icon, size: 28, color: OnPhoto.inkSoft),
            ),
            const SizedBox(height: 26),
            Text(title, style: OnPhotoText.title, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(message, style: OnPhotoText.label, textAlign: TextAlign.center),
            if (actionLabel != null) ...[
              const SizedBox(height: 30),
              SizedBox(
                width: 220,
                child: PrimaryButton(label: actionLabel!, onPressed: onAction),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
