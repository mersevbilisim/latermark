import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../paywall/presentation/paywall_host.dart';
import 'reminder_field.dart';

/// [ReminderField]'ın etrafındaki kurallar: Pro kilidi ve bildirim izni.
///
/// Alanın kendisi salt görsel. İzin isteme anı ve ücretsiz katmanda ne olacağı
/// ise ürün kararı ve **iki ekranda da aynı** olmak zorunda: hatırlatma hem
/// yeni kayıt ekranında hem de kayıtlı bir notu düzenlerken veriliyor. Aynı
/// kuralı iki yerde ayrı ayrı kurmak, birini değiştirip diğerini unutmanın
/// kısa yolu — özellikle Pro kilidi gibi sessizce kaybolan bir şeyde.
///
/// Değerin sahibi çağıran ekran: kaydetme anında ona ihtiyaç duyuyor.
class ReminderControl extends StatefulWidget {
  const ReminderControl({
    super.key,
    required this.days,
    required this.onChanged,
    this.repeats = false,
    this.onRepeatsChanged,
    this.prominent = false,
  });

  /// Hatırlatma aralığı (gün). `0` ise hatırlatma yok.
  final int days;

  final ValueChanged<int> onChanged;

  /// Hatırlatma bu aralıkta tekrarlansın mı.
  final bool repeats;

  final ValueChanged<bool>? onRepeatsChanged;

  /// Compose'ta açıklamalı metadata label'ını kullanır. Düzenleme panelindeki
  /// daha sıkışık satır geriye dönük olarak aynı kalır.
  final bool prominent;

  @override
  State<ReminderControl> createState() => _ReminderControlState();
}

class _ReminderControlState extends State<ReminderControl> {
  /// Bildirim izni yokken `true`; alanın altında uyarı gösterilir.
  bool _blocked = false;

  /// İzin bir kez istenir; kullanıcı reddettiyse her rakam değişiminde
  /// sistem istemini tekrar tetiklemenin anlamı yok.
  bool _permissionAsked = false;

  /// Kullanıcı ilk kez süre verdiğinde izin *o anda* istenir.
  ///
  /// Açılışta sormak yerine burada sormak, isteği kullanıcının niyetini
  /// gösterdiği ana bağlıyor — sistem istemi de böylece anlamlı geliyor.
  void _onChanged(int value) {
    widget.onChanged(value);
    if (value > 0) unawaited(_ensurePermission());
  }

  Future<void> _ensurePermission() async {
    final reminders = context.reminders;
    final settings = AppScope.settingsOf(context);

    var allowed = await reminders.hasPermission();
    if (!allowed && !_permissionAsked) {
      _permissionAsked = true;
      allowed = await reminders.requestPermission();
    }
    // Hatırlatmaların ana şalteri kapalıysa, kullanıcı burada süre vererek
    // zaten istediğini söylemiş oluyor.
    if (allowed) await settings.setReminderEnabled(true);

    if (!mounted) return;
    setState(() => _blocked = !allowed);
  }

  @override
  Widget build(BuildContext context) {
    return ReminderField(
      days: widget.days,
      repeats: widget.repeats,
      blocked: _blocked,
      locked: !AppScope.preferences(context).proUnlocked,
      prominent: widget.prominent,
      onChanged: _onChanged,
      onRepeatsChanged: widget.onRepeatsChanged,
      onLockedTap: () => showPaywall(context, reason: PaywallReason.reminder),
      onOpenSystemSettings: () => context.reminders.openSystemSettings(),
    );
  }
}
