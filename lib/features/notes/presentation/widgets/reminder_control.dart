import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../l10n/l10n_context.dart';
import '../../../../shared/widgets/ember_switch.dart';
import '../../../../shared/widgets/pressable.dart';
import '../../../../shared/widgets/pro_badge.dart';
import '../../../paywall/presentation/paywall_host.dart';
import '../../../reminders/reminder_service.dart';
import 'note_option_label.dart';

/// Not formundaki tek hatırlatma kararı: **istiyor musun?**
///
/// Gün, saat ve tekrar burada sorulmuyor. Yazarken verilecek karar bir tanedir
/// ve evet/hayırdır; takvim, klavyenin altında sıkışan bir satırda değil,
/// kaydettikten sonra açılan kendi ekranında karşılanıyor. Böylece yazma
/// ekranı yazmaya, planlama ekranı planlamaya ait oluyor.
///
/// İzin isteme anı ve ücretsiz katmanda ne olacağı ürün kararı ve **iki
/// ekranda da aynı** olmak zorunda: anahtar hem yeni kayıt ekranında hem de
/// kayıtlı bir notu düzenlerken var. Aynı kuralı iki yerde kurmak, birini
/// değiştirip diğerini unutmanın kısa yolu — özellikle Pro kilidi gibi
/// sessizce kaybolan bir şeyde.
///
/// Değerin sahibi çağıran ekran: kaydetme anında ona ihtiyaç duyuyor.
class ReminderControl extends StatefulWidget {
  const ReminderControl({
    super.key,
    required this.value,
    required this.onChanged,
  });

  /// Kullanıcı bu kare için hatırlatma istiyor mu.
  final bool value;

  final ValueChanged<bool> onChanged;

  @override
  State<ReminderControl> createState() => _ReminderControlState();
}

class _ReminderControlState extends State<ReminderControl> {
  /// Bildirim izni yokken `true`; satırın altında uyarı gösterilir.
  bool _blocked = false;

  /// İzin bir kez istenir; kullanıcı reddettiyse her açma denemesinde sistem
  /// istemini tekrar tetiklemenin anlamı yok.
  bool _permissionAsked = false;

  @override
  void initState() {
    super.initState();
    // Var olan bir hatırlatıcı düzenlenirken izin sonradan sistemden
    // kapatılmış olabilir. Satır ilk kareden itibaren gerçeği söylesin; açılış
    // sırasında sistem istemi göstermeden yalnızca mevcut durumu okur.
    if (widget.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_ensurePermission(ask: false));
      });
    }
  }

  @override
  void didUpdateWidget(ReminderControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value && !widget.value) _blocked = false;
  }

  /// İzin, anahtarın açıldığı anda isteniyor.
  ///
  /// Açılışta sormak yerine burada sormak, isteği kullanıcının niyetini
  /// gösterdiği ana bağlıyor — sistem istemi de böylece anlamlı geliyor.
  void _onChanged(bool value) {
    widget.onChanged(value);
    if (value) unawaited(_ensurePermission(ask: true));
  }

  Future<void> _ensurePermission({required bool ask}) async {
    final reminders = context.reminders;
    final settings = AppScope.settingsOf(context);

    // Anahtarı açmak, OS izninden bağımsız olarak kullanıcının Latermark
    // hatırlatmalarını istediği anlamına gelir. Niyeti şimdi saklamak,
    // reddedilen izni Sistem Ayarları'ndan sonradan açtığında aynı nota geri
    // dönüp seçimi yeniden yapma zorunluluğunu ortadan kaldırır. Native
    // programlama yine merkezi izin durumu ile sıkı biçimde kapılıdır.
    if (ask) await settings.setReminderEnabled(true);

    var permission = await reminders.refreshPermission();
    if (permission != ReminderPermissionState.granted &&
        ask &&
        !_permissionAsked) {
      _permissionAsked = true;
      permission = await reminders.requestPermissionState();
    }
    if (!mounted) return;
    setState(() => _blocked = permission == ReminderPermissionState.denied);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locked = !AppScope.preferences(context).proUnlocked;
    final permission = AppScope.reminderPermission(context);
    final blocked = widget.value
        ? switch (permission) {
            ReminderPermissionState.granted => false,
            ReminderPermissionState.denied => true,
            ReminderPermissionState.unknown => _blocked,
          }
        : false;

    // Tek satır: çan, cümle, anahtar. Altına bir açıklama daha koymak satırı
    // iki kata çıkarıp adının zaten söylediğini tekrarlıyordu.
    final label = NoteOptionLabel(
      icon: Icons.notifications_none_rounded,
      title: l10n.reminderSwitchLabel,
      active: widget.value && !locked,
    );

    if (locked) {
      return Pressable(
        key: const Key('reminder-locked-row'),
        onPressed: () => showPaywall(context, reason: PaywallReason.reminder),
        scale: 0.99,
        semanticLabel: '${l10n.reminderSwitchLabel}, ${l10n.proBadge}',
        child: ExcludeSemantics(
          child: NoteOptionRow(label: label, trailing: const ProGateMark()),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Satırın tamamı hedef: 52 puanlık anahtara nişan almak, telefonu tek
        // elle tutan birinden gereksiz bir hassasiyet istemek olurdu.
        GestureDetector(
          key: const Key('reminder-switch-row'),
          behavior: HitTestBehavior.opaque,
          onTap: () => _onChanged(!widget.value),
          child: MergeSemantics(
            child: NoteOptionRow(
              label: ExcludeSemantics(child: label),
              trailing: EmberSwitch(
                key: const Key('reminder-switch'),
                value: widget.value,
                onChanged: _onChanged,
                semanticLabel: l10n.reminderSwitchLabel,
              ),
            ),
          ),
        ),
        if (widget.value && blocked) ...[
          const SizedBox(height: 10),
          ReminderBlockedNotice(
            onOpenSystemSettings: () => context.reminders.openSystemSettings(),
          ),
        ],
      ],
    );
  }
}

/// Hatırlatma istenmiş ama bildirim izni yokken görünen satır.
///
/// Sessizce hiçbir şey yapmamak en kötüsü olurdu: kullanıcı hatırlatmanın
/// kurulduğunu sanırdı. Kayıt yine saklanır, yalnızca bildirim çalmaz.
class ReminderBlockedNotice extends StatelessWidget {
  const ReminderBlockedNotice({super.key, this.onOpenSystemSettings});

  final VoidCallback? onOpenSystemSettings;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.notifications_off_outlined,
          size: 15,
          color: palette.inkFaint,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            context.l10n.reminderBlocked,
            style: palette.caption.copyWith(
              color: palette.inkFaint,
              height: 1.35,
            ),
          ),
        ),
        if (onOpenSystemSettings != null) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onOpenSystemSettings,
            child: Text(
              context.l10n.actionOpen,
              style: palette.label.copyWith(color: palette.ember),
            ),
          ),
        ],
      ],
    );
  }
}
