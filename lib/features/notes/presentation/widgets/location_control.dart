import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../l10n/l10n_context.dart';
import '../../data/location_service.dart';
import 'note_option_label.dart';

/// "Bu kareye nerede çekildiğini iliştir."
///
/// Yalnızca kamerayla çekilen karede görünür. Galeriden gelen bir fotoğrafın
/// çekildiği yer cihazın *şu anki* konumu değildir; oraya bugünün koordinatını
/// yazmak kaydı sessizce yalancı yapardı.
///
/// Anahtar açıldığı anda iki şey olur: izin istenir ve — verilmişse — konum
/// arka planda alınmaya başlar. **Kaydetme hiçbir zaman beklemez**: kaydete
/// basıldığında koordinat henüz gelmediyse not konumsuz kaydedilir. Bir GPS
/// sabitlemesi için kullanıcıyı bekletmek, uygulamanın "çek, yaz, unut"
/// sözünün tam tersi olurdu.
///
/// Değerin sahibi çağıran ekran; [ReminderControl] ile aynı kalıp.
/// Sayfa ile denetim arasındaki dar köprü.
///
/// Kaydetme anında sayfanın tek bir sorusu var: "bekleyen bir sabitleme var
/// mı, varsa kısa bir süre bekleyebilir miyim?" Denetimin iç durumunu sayfaya
/// taşımak yerine bu soruyu tek bir metotla cevaplıyoruz — düzenleyicideki
/// [EditNoteController] ile aynı kalıp.
class LocationController {
  _LocationControlState? _state;

  /// Bekleyen sabitleme varsa en fazla [limit] kadar bekler ve sonucu döner.
  ///
  /// Bekleyen bir şey yoksa **anında** döner: konum kapalıyken ya da koordinat
  /// çoktan geldiğinde kaydetme hiç gecikmez.
  Future<NoteLocation?> settle({Duration limit = const Duration(seconds: 4)}) {
    final state = _state;
    if (state == null) return Future<NoteLocation?>.value();
    return state._settle(limit);
  }

  void _attach(_LocationControlState state) => _state = state;

  void _detach(_LocationControlState state) {
    if (identical(_state, state)) _state = null;
  }
}

class LocationControl extends StatefulWidget {
  const LocationControl({
    super.key,
    required this.enabled,
    required this.onChanged,
    required this.onResolved,
    this.controller,
  });

  /// Kaydetmenin bekleyen sabitlemeye ulaşmasını sağlayan köprü.
  final LocationController? controller;

  /// Anahtarın etkin durumu. Varsayılanı ayarlardaki son tercih besler; ancak
  /// izin yoksa denetim bu değeri `false` olarak geri uzlaştırır.
  final bool enabled;

  final ValueChanged<bool> onChanged;

  /// Konum çözüldüğünde ya da anahtar kapandığında çağrılır. `null`, "bu
  /// kayıtta konum yok" demek.
  final ValueChanged<NoteLocation?> onResolved;

  @override
  State<LocationControl> createState() => _LocationControlState();
}

class _LocationControlState extends State<LocationControl> {
  /// Konum izni yokken `true`; anahtarın altında açıklama gösterilir.
  bool _blocked = false;

  /// İzin bir kez istenir. Kullanıcı reddettiyse her açma denemesinde sistem
  /// istemini yeniden tetiklemenin anlamı yok — iOS zaten açmaz.
  bool _permissionAsked = false;

  /// Aynı anda tek okuma. Anahtarla oynayan biri arka arkaya sabitleme
  /// başlatmasın.
  bool _resolving = false;
  bool _resolved = false;
  int _resolveGeneration = 0;

  /// Yürürlükteki sabitlemenin sonucu. Kaydetme bunu kısa bir süre bekler.
  Completer<NoteLocation?>? _pending;
  NoteLocation? _fix;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
    // Ayarlardan açık gelmişse kullanıcı zaten kararını vermiş; koordinatı
    // sayfa açılır açılmaz, kullanıcı yazarken arka planda topla.
    if (widget.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_resolve(askPermission: false));
      });
    }
  }

  @override
  void didUpdateWidget(LocationControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller?._detach(this);
    widget.controller?._attach(this);
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _closePending(null);
    super.dispose();
  }

  void _closePending(NoteLocation? value) {
    final pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) pending.complete(value);
  }

  /// Bekleyen sabitleme varsa [limit] kadar bekler; süre dolarsa konumsuz
  /// devam edilir. Kullanıcıyı bir GPS sabitlemesi için süresiz bekletmek,
  /// "çek, yaz, unut" sözünün tersi olurdu.
  Future<NoteLocation?> _settle(Duration limit) async {
    if (!widget.enabled || _blocked) return null;
    if (_fix != null) return _fix;
    final pending = _pending;
    if (pending == null) return null;
    return pending.future.timeout(limit, onTimeout: () => null);
  }

  Future<void> _onChanged(bool value) async {
    if (!value) {
      widget.onChanged(false);
      _resolveGeneration++;
      _fix = null;
      _closePending(null);
      widget.onResolved(null);
      if (_blocked || _resolving || _resolved) {
        setState(() {
          _blocked = false;
          _resolving = false;
          _resolved = false;
        });
      }
      return;
    }
    // Açma isteğini, izin sonucu gelmeden kalıcı tercihe yazma. Aksi hâlde
    // kullanıcı istemi reddetse bile bir sonraki Compose açık anahtarla
    // başlıyor ve notun konumlu kaydedildiği izlenimini veriyordu.
    await _resolve(askPermission: true, enableWhenAllowed: true);
  }

  Future<void> _resolve({
    required bool askPermission,
    bool enableWhenAllowed = false,
  }) async {
    if (_resolving) return;
    final generation = ++_resolveGeneration;
    _fix = null;
    _closePending(null);
    _pending = Completer<NoteLocation?>();
    setState(() {
      _resolving = true;
      _resolved = false;
    });
    try {
      final location = context.location;

      var allowed = await location.hasPermission();
      if (!allowed && askPermission && !_permissionAsked) {
        _permissionAsked = true;
        allowed = await location.requestPermission();
      }

      if (!mounted || generation != _resolveGeneration) return;
      setState(() => _blocked = !allowed);
      if (!allowed) {
        _closePending(null);
        // Ayarlardaki tercih yalnızca bir niyet olabilir; işletim sistemi izin
        // vermiyorsa ekrandaki ve kalıcı değer aynı anda kapanır. Gerçeğin tek
        // sahibi parent state'tir, kalıcılığı da onun onChanged'i yapar.
        widget.onChanged(false);
        widget.onResolved(null);
        return;
      }

      if (enableWhenAllowed && !widget.enabled) widget.onChanged(true);

      final fix = await location.current();
      if (generation != _resolveGeneration) return;
      _fix = fix;
      _closePending(fix);
      if (!mounted) return;
      setState(() => _resolved = fix != null);
      widget.onResolved(fix);
    } finally {
      if (generation == _resolveGeneration) _closePending(_fix);
      if (mounted && generation == _resolveGeneration) {
        setState(() => _resolving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;
    final detail = switch ((_blocked, _resolving, _resolved)) {
      (true, _, _) => l10n.composeLocationPermissionRequired,
      (_, true, _) => l10n.composeLocationResolving,
      (_, _, true) => l10n.composeLocationReady,
      _ => l10n.composeLocationDescription,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        NoteOptionRow(
          label: NoteOptionLabel(
            icon: Icons.location_on_outlined,
            title: l10n.locationAddLabel,
            detail: detail,
            active: widget.enabled && !_blocked,
          ),
          trailing: Switch.adaptive(
            key: const ValueKey('compose-location-switch'),
            value: widget.enabled && !_blocked,
            onChanged: (value) => unawaited(_onChanged(value)),
            activeTrackColor: palette.ember,
          ),
        ),
        if (_blocked) ...[
          const SizedBox(height: 6),
          _BlockedNotice(key: const ValueKey('compose-location-blocked')),
        ],
      ],
    );
  }
}

/// Anahtar açık ama izin yokken görünen açıklama.
///
/// Sessizce hiçbir şey yapmamak en kötüsü olurdu: kullanıcı konumun
/// eklendiğini sanırdı. Kayıt yine de kaydedilir, yalnızca konumsuz.
class _BlockedNotice extends StatelessWidget {
  const _BlockedNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.location_off_outlined, size: 15, color: palette.inkFaint),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            context.l10n.locationBlocked,
            style: palette.caption.copyWith(
              color: palette.inkFaint,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
