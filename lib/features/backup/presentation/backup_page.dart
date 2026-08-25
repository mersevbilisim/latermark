import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:path/path.dart' as p;

import '../../../shared/widgets/app_toast.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_shape.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_format.dart';
import '../../../l10n/l10n_context.dart';
import '../../../shared/widgets/pressable.dart';
import '../../notes/presentation/home/widgets/note_photo.dart';
import '../data/backup_service.dart';
import '../domain/backup_status.dart';

enum BackupMode { create, restore }

const latermarkBackupUti = 'com.mersev.latermark.backup';
const latermarkBackupMimeType = 'application/vnd.latermark.backup';

/// Her platformun dosya seçicisi farklı bir tür bilgisi okur.
///
/// Özellikle iOS uzantıyı dikkate almaz ve UTI verilmezse dosya seçiciyi
/// açmadan `ArgumentError` fırlatır. Özel UTI Info.plist'te `.latermark`
/// uzantısıyla eşleştirilir. Android tarafında hem yeni özel MIME türünü hem
/// de daha önce paylaşılmış dosyaların genel binary MIME türünü kabul ederiz.
const latermarkBackupType = XTypeGroup(
  label: 'Latermark backup',
  extensions: [BackupService.fileExtension],
  mimeTypes: [latermarkBackupMimeType, 'application/octet-stream'],
  // Restore içerik imzasını zaten doğruluyor. Seçicide `public.data`
  // kullanmak, eski geliştirme kurulumlarında özel UTI henüz işletim sistemi
  // tarafından indekslenmemiş olsa bile Files ekranının açılmasını sağlar.
  uniformTypeIdentifiers: ['public.data'],
);

Future<File?> pickLatermarkBackup() async {
  final selected = await openFile(
    acceptedTypeGroups: const [latermarkBackupType],
  );
  return selected == null ? null : File(selected.path);
}

/// Ayarlar sayfasını iki teknik eylemle kalabalıklaştırmadan yedekleme
/// niyetini seçtirir. Dil paneliyle aynı editoryal aileyi kullanır: tek yüzey,
/// ince cetveller, küçük bir vurgu izi ve sıfır kart/blur.
/// [hasData] yanlışken yedek alma seçeneği kapalı görünür.
///
/// Boş bir arşivden teknik olarak geçerli bir yedek üretilebilir ama o dosya
/// hiçbir işe yaramaz: kullanıcı parola seçip bekledikten sonra elinde içi boş
/// bir dosyayla kalır. Sebebi seçim anında söylemek, sonra hata vermekten iyi.
Future<BackupMode?> showBackupActionsSheet(
  BuildContext context, {
  required int noteCount,
  required List<File> previews,
}) {
  return showModalBottomSheet<BackupMode>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.68),
    isScrollControlled: true,
    builder: (context) =>
        _BackupActionsSheet(noteCount: noteCount, previews: previews),
  );
}

/// Yedek akışının kapısı.
///
/// Yüzey bir ayar listesi değil, **arşivin kendisi**: üstte kullanıcının son
/// kareleri baskı köşeleriyle yan yana duruyor, altında kaç tane oldukları ve
/// hepsinin tek bir şifreli dosyaya gireceği yazıyor. Yedek soyut bir tercih
/// değil; bu kareler.
///
/// İki eylem yön: biri arşivi dışarı çıkarır, diğeri dışarıdan gelenin yerine
/// koyar. O yüzden satırların başında yön oku var ve sonlarında liste kalıbının
/// tipik ">" işareti yok — buradan iki farklı yere gidiliyor, bir listede
/// ilerlenmiyor. Numaralar da kalktı: sıralı olmayan iki alternatifi "01/02"
/// diye numaralamak, akıştaki gerçek adım göstergesinin anlamını da
/// zayıflatıyordu.
///
/// Sonuçlarını yalnızca geri yükleme taşıyor: geri alınamayan tek eylem o.
class _BackupActionsSheet extends StatelessWidget {
  const _BackupActionsSheet({required this.noteCount, required this.previews});

  final int noteCount;

  /// Şeritte gösterilecek son kareler. Boşsa şerit hiç çizilmez — arşiv boşken
  /// gösterilecek bir şey de yok.
  final List<File> previews;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;
    final media = MediaQuery.of(context);
    final hasData = noteCount > 0;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: media.size.height - media.padding.top - 12,
      ),
      child: DecoratedBox(
        key: const Key('backup-actions-surface'),
        decoration: BoxDecoration(
          color: palette.canvasLift,
          border: Border(
            top: BorderSide(color: palette.hairlineBright, width: 0.5),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 2,
              child: Stack(
                children: [
                  PositionedDirectional(
                    start: 22,
                    top: 0,
                    bottom: 0,
                    width: 38,
                    child: ColoredBox(color: palette.ember),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                key: const Key('backup-actions-list'),
                shrinkWrap: true,
                padding: EdgeInsets.only(bottom: media.padding.bottom + 6),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 16, 14, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  l10n.upper(l10n.backupSectionTitle),
                                  style: palette.overline,
                                ),
                              ),
                            ),
                            Pressable(
                              onPressed: () => Navigator.of(context).pop(),
                              scale: 0.88,
                              semanticLabel: l10n.actionClose,
                              child: ExcludeSemantics(
                                child: SizedBox.square(
                                  dimension: 40,
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 20,
                                    color: palette.inkSoft,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (previews.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _ArchiveStrip(previews: previews),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          l10n.noteCount(noteCount),
                          key: const Key('backup-actions-count'),
                          maxLines: 2,
                          style: palette.title.copyWith(
                            fontSize: 26,
                            color: hasData ? palette.ink : palette.inkSoft,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 7),
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: Text(
                            l10n.backupCreateDescription,
                            style: palette.caption.copyWith(
                              color: palette.inkFaint,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ColoredBox(
                    color: palette.hairlineBright,
                    child: const SizedBox(height: 0.5),
                  ),
                  _BackupActionOption(
                    key: const Key('backup-action-create'),
                    icon: Icons.arrow_upward_rounded,
                    title: l10n.backupCreateTitle,
                    detail: hasData ? null : l10n.backupNothingToSave,
                    onPressed: hasData
                        ? () => Navigator.of(context).pop(BackupMode.create)
                        : null,
                  ),
                  _BackupActionOption(
                    key: const Key('backup-action-restore'),
                    icon: Icons.arrow_downward_rounded,
                    title: l10n.backupRestoreTitle,
                    // Geri alınamayan tek eylem: sonucunu dokunmadan önce
                    // söylemek, sonra bir onay diyaloğuyla durdurmaktan iyi.
                    detail: l10n.backupRestoreDescription,
                    onPressed: () =>
                        Navigator.of(context).pop(BackupMode.restore),
                    isLast: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Arşivin yüzü: son kareler, baskı köşeleriyle yan yana.
///
/// Genel bir "yedek" ikonu ya da çizimi yerine kullanıcının kendi kareleri.
/// Aynı şerit başka bir uygulamaya taşınamaz — çünkü orada bu kareler yok.
class _ArchiveStrip extends StatelessWidget {
  const _ArchiveStrip({required this.previews});

  final List<File> previews;

  static const _size = 58.0;
  static const _gap = 7.0;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final frames = previews.take(3).toList();

    return ExcludeSemantics(
      child: SizedBox(
        key: const Key('backup-actions-strip'),
        height: _size,
        child: Row(
          children: [
            for (var index = 0; index < frames.length; index++) ...[
              if (index > 0) const SizedBox(width: _gap),
              ClipRSuperellipse(
                borderRadius: AppShape.all(AppShape.print),
                child: SizedBox.square(
                  dimension: _size,
                  child: ColoredBox(
                    color: palette.canvasSunk,
                    child: NotePhoto(file: frames[index], decodeWidth: _size),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Yön, ad ve —gerekiyorsa— sonuç.
///
/// Sonda ">" yok: bu satırlar bir listede ilerletmiyor, iki ayrı yere
/// gönderiyor. Yönü baştaki ok söylüyor.
class _BackupActionOption extends StatelessWidget {
  const _BackupActionOption({
    super.key,
    required this.icon,
    required this.title,
    required this.onPressed,
    this.detail,
    this.isLast = false,
  });

  final IconData icon;
  final String title;

  /// `null` ise seçenek kapalı: dokunulamaz ve soluk görünür.
  final VoidCallback? onPressed;

  /// Adın altındaki tek satır: kapalıyken gerekçe, açıkken sonuç.
  final String? detail;

  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    final enabled = onPressed != null;
    // Kapalı seçenek gizlenmiyor, soluklaşıyor: olmayan bir satır "neden
    // yedekleyemiyorum" sorusunu doğurur, soluk bir satır cevabını yanında
    // taşır.
    final tint = enabled ? palette.ink : palette.inkGhost;
    final detail = this.detail;

    return Pressable(
      onPressed: onPressed,
      scale: 0.995,
      semanticLabel: detail == null ? title : '$title. $detail',
      child: ExcludeSemantics(
        child: Stack(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 68),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(22, 17, 22, 17),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 32,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          icon,
                          size: 19,
                          color: enabled ? palette.ember : palette.inkGhost,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: palette.body.copyWith(
                              color: tint,
                              fontSize: 17,
                            ),
                          ),
                          if (detail != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              detail,
                              style: palette.caption.copyWith(
                                color: enabled
                                    ? palette.inkFaint
                                    : palette.inkGhost,
                                fontSize: 12.5,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!isLast)
              PositionedDirectional(
                start: 22,
                end: 0,
                bottom: 0,
                child: ColoredBox(
                  color: palette.hairline,
                  child: const SizedBox(height: 0.5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class BackupPage extends StatefulWidget {
  const BackupPage.create({super.key}) : mode = BackupMode.create, file = null;

  const BackupPage.restore({super.key, required this.file})
    : mode = BackupMode.restore;

  final BackupMode mode;
  final File? file;

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  static const _minimumPasswordLength = 8;

  final _password = TextEditingController();
  final _passwordAgain = TextEditingController();
  bool _acknowledged = false;
  bool _attempted = false;
  bool _busy = false;
  bool _restored = false;
  BackupProgress? _progress;
  BackupPreview? _preview;
  CreatedBackup? _created;
  BackupFailureKind? _error;

  bool get _creating => widget.mode == BackupMode.create;

  @override
  void initState() {
    super.initState();
    _password.addListener(_fieldChanged);
    _passwordAgain.addListener(_fieldChanged);
  }

  @override
  void dispose() {
    _preview?.dispose();
    _password
      ..removeListener(_fieldChanged)
      ..dispose();
    _passwordAgain
      ..removeListener(_fieldChanged)
      ..dispose();
    super.dispose();
  }

  void _fieldChanged() {
    if (mounted) setState(() => _error = null);
  }

  bool get _passwordLongEnough =>
      _password.text.length >= _minimumPasswordLength;

  bool get _passwordsMatch => _password.text == _passwordAgain.text;

  bool get _canCreate =>
      _passwordLongEnough && _passwordsMatch && _acknowledged && !_busy;

  bool get _canInspect => _password.text.isNotEmpty && !_busy;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final title = _creating
        ? context.l10n.backupCreateTitle
        : context.l10n.backupRestoreTitle;

    return PopScope(
      canPop: !_busy,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.overlayFor(palette.brightness),
        child: Scaffold(
          backgroundColor: palette.canvas,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _BackupHeader(title: title, enabled: !_busy),
                ColoredBox(
                  color: palette.hairline,
                  child: const SizedBox(height: 0.5, width: double.infinity),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      22,
                      34,
                      22,
                      MediaQuery.paddingOf(context).bottom + 34,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: _stage(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stage() {
    if (_busy) {
      return _ProgressStage(
        key: const ValueKey('progress'),
        progress: _progress,
      );
    }
    if (_creating && _created != null) {
      return _ReadyStage(
        key: const ValueKey('ready'),
        result: _created!,
        onSave: _save,
        onShare: _share,
      );
    }
    if (!_creating && _restored) {
      return const _RestoredStage(key: ValueKey('restored'));
    }
    if (!_creating && _preview != null) {
      return _RestorePreviewStage(
        key: const ValueKey('preview'),
        preview: _preview!,
        acknowledged: _acknowledged,
        error: _errorText,
        onAcknowledge: (value) => setState(() => _acknowledged = value),
        onRestore: _acknowledged ? _restore : null,
      );
    }
    return _PasswordStage(
      key: const ValueKey('password'),
      creating: _creating,
      password: _password,
      passwordAgain: _creating ? _passwordAgain : null,
      acknowledged: _acknowledged,
      attempted: _attempted,
      minimumLength: _minimumPasswordLength,
      error: _errorText,
      onAcknowledge: (value) => setState(() => _acknowledged = value),
      onSubmit: _creating
          ? (_canCreate ? _create : _markAttempted)
          : (_canInspect ? _inspect : _markAttempted),
    );
  }

  void _markAttempted() => setState(() => _attempted = true);

  Future<void> _create() async {
    if (!_canCreate) return _markAttempted();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _progress = const BackupProgress(phase: BackupPhase.preparing);
    });

    try {
      final backups = context.backups;
      final password = _password.text;
      final info = await PackageInfo.fromPlatform();
      final appVersion = info.buildNumber.isEmpty
          ? info.version
          : '${info.version}+${info.buildNumber}';
      final result = await backups.createBackup(
        password: password,
        appVersion: appVersion,
        onProgress: _onProgress,
      );
      if (!mounted) return;
      setState(() {
        _created = result;
        _busy = false;
      });
    } on BackupFailure catch (failure) {
      _finishWithError(failure.kind);
    } catch (_) {
      _finishWithError(BackupFailureKind.io);
    }
  }

  Future<void> _inspect() async {
    if (!_canInspect) return _markAttempted();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _progress = const BackupProgress(phase: BackupPhase.derivingKey);
    });

    try {
      final preview = await context.backups.inspect(
        file: widget.file!,
        password: _password.text,
      );
      if (!mounted) {
        preview.dispose();
        return;
      }
      setState(() {
        _preview = preview;
        _busy = false;
      });
    } on BackupFailure catch (failure) {
      _finishWithError(failure.kind);
    } catch (_) {
      _finishWithError(BackupFailureKind.io);
    }
  }

  Future<void> _restore() async {
    final preview = _preview;
    if (preview == null || !_acknowledged) return;
    setState(() {
      _busy = true;
      _error = null;
      _progress = const BackupProgress(phase: BackupPhase.reading);
    });

    try {
      await context.backups.restore(preview: preview, onProgress: _onProgress);
      if (!mounted) return;
      setState(() {
        _restored = true;
        _busy = false;
      });
    } on BackupFailure catch (failure) {
      _finishWithError(failure.kind);
    } catch (_) {
      _finishWithError(BackupFailureKind.io);
    }
  }

  void _onProgress(BackupProgress progress) {
    if (mounted) setState(() => _progress = progress);
  }

  void _finishWithError(BackupFailureKind kind) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = kind;
    });
  }

  /// Dosyayı kullanıcının seçtiği yere yazar.
  ///
  /// Paylaşmaktan ayrı bir yol olması şart: iOS'un paylaşım sayfası
  /// "Dosyalar'a Kaydet"i kendiliğinden içeriyor ama Android'in paylaşım
  /// menüsü yalnızca içeriği **alabilecek uygulamaları** listeliyor, dosyayı
  /// telefona yazacak bir seçenek sunmuyor. Android'de kaydetmenin yolu
  /// sistemin belge oluşturma ekranı; bu çağrı orada onu, iOS'ta da doğrudan
  /// Dosyalar'ı açıyor.
  Future<void> _save() async {
    final result = _created;
    if (result == null) return;

    try {
      final saved = await FlutterFileDialog.saveFile(
        params: SaveFileDialogParams(
          sourceFilePath: result.file.path,
          fileName: p.basename(result.file.path),
          mimeTypesFilter: const [latermarkBackupMimeType],
        ),
      );
      // `null` iptal demek; kullanıcı vazgeçtiğinde hata göstermek yanlış olur.
      if (saved == null || !mounted) return;
      showToast(context, context.l10n.backupSavedToDevice);
    } catch (error, stackTrace) {
      debugPrint('Backup save failed: $error\n$stackTrace');
      if (!mounted) return;
      showToast(context, context.l10n.backupErrorGeneric, error: true);
    }
  }

  Future<void> _share() async {
    final result = _created;
    if (result == null) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(result.file.path, mimeType: latermarkBackupMimeType)],
        title: context.l10n.backupReadyTitle,
      ),
    );
  }

  String? get _errorText {
    final error = _error;
    if (error == null) return null;
    return switch (error) {
      BackupFailureKind.wrongPassword => context.l10n.backupErrorWrongPassword,
      BackupFailureKind.notABackup => context.l10n.backupErrorNotABackup,
      BackupFailureKind.corrupt => context.l10n.backupErrorCorrupt,
      BackupFailureKind.unsupportedFormat ||
      BackupFailureKind.unsupportedSchema =>
        context.l10n.backupErrorUnsupported,
      BackupFailureKind.cancelled ||
      BackupFailureKind.io => context.l10n.backupErrorGeneric,
    };
  }
}

class _BackupHeader extends StatelessWidget {
  const _BackupHeader({required this.title, required this.enabled});

  final String title;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      height: 60,
      child: Row(
        children: [
          Pressable(
            onPressed: enabled ? () => Navigator.of(context).maybePop() : null,
            scale: 0.9,
            semanticLabel: context.l10n.actionBack,
            child: const SizedBox.square(
              dimension: 56,
              child: Icon(Icons.arrow_back_rounded, size: 20),
            ),
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: palette.title.copyWith(fontSize: 18),
            ),
          ),
          const SizedBox(width: 22),
        ],
      ),
    );
  }
}

class _PasswordStage extends StatelessWidget {
  const _PasswordStage({
    super.key,
    required this.creating,
    required this.password,
    required this.passwordAgain,
    required this.acknowledged,
    required this.attempted,
    required this.minimumLength,
    required this.error,
    required this.onAcknowledge,
    required this.onSubmit,
  });

  final bool creating;
  final TextEditingController password;
  final TextEditingController? passwordAgain;
  final bool acknowledged;
  final bool attempted;
  final int minimumLength;
  final String? error;
  final ValueChanged<bool> onAcknowledge;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final longEnough = password.text.length >= minimumLength;
    final matches =
        passwordAgain == null || password.text == passwordAgain!.text;
    final localError = !creating || !attempted
        ? null
        : !longEnough
        ? l10n.backupPasswordShort(minimumLength)
        : !matches
        ? l10n.backupPasswordMismatch
        : !acknowledged
        ? l10n.backupLossWarning
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StageIntro(
          index: creating ? '01' : '01',
          title: creating ? l10n.backupPasswordTitle : l10n.backupUnlockTitle,
          subtitle: creating
              ? l10n.backupPasswordSubtitle
              : l10n.backupUnlockSubtitle,
        ),
        const SizedBox(height: 38),
        _PasswordField(controller: password, label: l10n.backupPasswordLabel),
        if (creating) ...[
          const SizedBox(height: 22),
          _PasswordField(
            controller: passwordAgain!,
            label: l10n.backupPasswordRepeat,
            onSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: 18),
          _PasswordStrength(length: password.text.length),
          const SizedBox(height: 30),
          _CheckLine(
            value: acknowledged,
            label: l10n.backupLossWarning,
            onChanged: onAcknowledge,
          ),
        ],
        if (error ?? localError case final message?) ...[
          const SizedBox(height: 20),
          _InlineError(message),
        ],
        const SizedBox(height: 34),
        _FlatAction(
          key: const Key('backup-password-submit'),
          label: creating ? l10n.backupActionCreate : l10n.backupUnlockTitle,
          onPressed: onSubmit,
        ),
      ],
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return TextField(
      controller: controller,
      obscureText: true,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: onSubmitted == null
          ? TextInputAction.next
          : TextInputAction.done,
      onSubmitted: onSubmitted,
      style: palette.body.copyWith(fontSize: 17),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: palette.label.copyWith(color: palette.inkSoft),
        floatingLabelStyle: palette.label.copyWith(color: palette.ember),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: palette.hairlineBright, width: 0.5),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: palette.ember, width: 1.5),
        ),
      ),
    );
  }
}

class _PasswordStrength extends StatelessWidget {
  const _PasswordStrength({required this.length});

  final int length;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final level = length < 8
        ? 1
        : length < 14
        ? 2
        : 3;
    final label = switch (level) {
      1 => context.l10n.backupStrengthWeak,
      2 => context.l10n.backupStrengthFair,
      _ => context.l10n.backupStrengthStrong,
    };

    return Row(
      children: [
        for (var i = 0; i < 3; i++) ...[
          Expanded(
            child: ColoredBox(
              color: i < level ? palette.ember : palette.hairlineBright,
              child: const SizedBox(height: 2),
            ),
          ),
          if (i < 2) const SizedBox(width: 5),
        ],
        const SizedBox(width: 12),
        Text(label, style: palette.caption.copyWith(color: palette.inkSoft)),
      ],
    );
  }
}

class _ProgressStage extends StatelessWidget {
  const _ProgressStage({super.key, required this.progress});

  final BackupProgress? progress;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final value = progress;
    final fraction = value?.fraction ?? .12;
    final phase = switch (value?.phase) {
      BackupPhase.preparing => context.l10n.backupPhasePreparing,
      BackupPhase.derivingKey => context.l10n.backupPhaseKey,
      BackupPhase.writing => context.l10n.backupPhaseWriting,
      BackupPhase.reading => context.l10n.backupPhaseReading,
      BackupPhase.verifying => context.l10n.backupPhaseVerifying,
      BackupPhase.applying ||
      BackupPhase.done => context.l10n.backupPhaseApplying,
      null => context.l10n.backupPhasePreparing,
    };

    return Column(
      key: const Key('backup-progress'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('LATERMARK / 02', style: palette.overline),
        const SizedBox(height: 18),
        Text(phase, style: palette.display.copyWith(fontSize: 32)),
        const SizedBox(height: 28),
        LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              ColoredBox(
                color: palette.hairlineBright,
                child: const SizedBox(height: 3, width: double.infinity),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: constraints.maxWidth * fraction,
                height: 3,
                color: palette.ember,
              ),
            ],
          ),
        ),
        if (value != null && value.itemsTotal > 0) ...[
          const SizedBox(height: 12),
          Text(
            context.l10n.backupItems(value.itemsDone, value.itemsTotal),
            style: palette.caption.copyWith(color: palette.inkSoft),
          ),
        ],
      ],
    );
  }
}

class _ReadyStage extends StatelessWidget {
  const _ReadyStage({
    super.key,
    required this.result,
    required this.onSave,
    required this.onShare,
  });

  final CreatedBackup result;
  final VoidCallback onSave;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return _CompletionStage(
      mark: '✓',
      title: context.l10n.backupReadyTitle,
      subtitle: context.l10n.backupReadySubtitle(
        result.noteCount,
        result.photoCount,
      ),
      actionLabel: context.l10n.backupActionSave,
      onAction: onSave,
      secondaryLabel: context.l10n.actionShare,
      onSecondary: onShare,
    );
  }
}

class _RestorePreviewStage extends StatelessWidget {
  const _RestorePreviewStage({
    super.key,
    required this.preview,
    required this.acknowledged,
    required this.error,
    required this.onAcknowledge,
    required this.onRestore,
  });

  final BackupPreview preview;
  final bool acknowledged;
  final String? error;
  final ValueChanged<bool> onAcknowledge;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final manifest = preview.manifest;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StageIntro(
          index: '02',
          title: context.l10n.backupFoundTitle,
          subtitle: context.l10n.backupFoundCounts(
            manifest.noteCount,
            manifest.photoCount,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          context.l10n.backupFoundDate(
            context.l10n.stamp(
              manifest.createdAt,
              use24Hour: context.use24Hour,
            ),
          ),
          style: palette.label.copyWith(color: palette.inkSoft),
        ),
        const SizedBox(height: 34),
        ColoredBox(color: palette.hairline, child: const SizedBox(height: 0.5)),
        const SizedBox(height: 24),
        Text(
          context.l10n.backupReplaceWarning,
          style: palette.body.copyWith(color: palette.danger, height: 1.45),
        ),
        const SizedBox(height: 22),
        _CheckLine(
          value: acknowledged,
          label: context.l10n.backupReplaceAcknowledge,
          onChanged: onAcknowledge,
        ),
        if (error != null) ...[
          const SizedBox(height: 20),
          _InlineError(error!),
        ],
        const SizedBox(height: 34),
        _FlatAction(
          key: const Key('backup-restore-confirm'),
          label: context.l10n.backupActionRestore,
          onPressed: onRestore,
          danger: true,
        ),
      ],
    );
  }
}

class _RestoredStage extends StatelessWidget {
  const _RestoredStage({super.key});

  @override
  Widget build(BuildContext context) {
    return _CompletionStage(
      mark: '✓',
      title: context.l10n.backupRestoredTitle,
      subtitle: context.l10n.backupFoundCounts(0, 0),
      actionLabel: context.l10n.actionClose,
      onAction: () => Navigator.of(context).maybePop(),
      showSubtitle: false,
    );
  }
}

class _CompletionStage extends StatelessWidget {
  const _CompletionStage({
    required this.mark,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    this.showSubtitle = true,
  });

  final String mark;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  /// Birincilin altında duran ikinci yol. Yedek bittiğinde "cihaza kaydet" ile
  /// "paylaş" ayrı ayrı sunuluyor: Android'in paylaşım menüsünde dosyayı
  /// telefona yazacak bir seçenek yok, oradaki tek kaydetme yolu sistemin
  /// belge oluşturma ekranı.
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  final bool showSubtitle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: palette.ember, width: 1),
            ),
            child: Text(
              mark,
              style: palette.title.copyWith(color: palette.ember),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(title, style: palette.display.copyWith(fontSize: 34)),
        if (showSubtitle) ...[
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: palette.body.copyWith(color: palette.inkSoft, height: 1.45),
          ),
        ],
        const SizedBox(height: 38),
        _FlatAction(label: actionLabel, onPressed: onAction),
        if (secondaryLabel != null) ...[
          const SizedBox(height: 10),
          _FlatAction(
            key: const Key('backup-secondary-action'),
            label: secondaryLabel!,
            onPressed: onSecondary,
            quiet: true,
          ),
        ],
      ],
    );
  }
}

class _StageIntro extends StatelessWidget {
  const _StageIntro({
    required this.index,
    required this.title,
    required this.subtitle,
  });

  final String index;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('LATERMARK', style: palette.overline),
            const SizedBox(width: 12),
            Expanded(
              child: ColoredBox(
                color: palette.hairline,
                child: const SizedBox(height: 0.5),
              ),
            ),
            const SizedBox(width: 12),
            Text('$index / 02', style: palette.overline),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          title,
          style: palette.display.copyWith(fontSize: 34, height: 1.08),
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          style: palette.body.copyWith(color: palette.inkSoft, height: 1.45),
        ),
      ],
    );
  }
}

class _CheckLine extends StatelessWidget {
  const _CheckLine({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      checked: value,
      label: label,
      child: Pressable(
        onPressed: () => onChanged(!value),
        scale: 0.995,
        semanticLabel: label,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                key: const Key('backup-square-check'),
                width: 18,
                height: 18,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  color: value ? palette.ember : Colors.transparent,
                  border: Border.all(
                    color: value ? palette.ember : palette.hairlineBright,
                  ),
                ),
                child: value
                    ? const Icon(
                        Icons.check_rounded,
                        size: 13,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  label,
                  style: palette.label.copyWith(
                    color: palette.inkSoft,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Text(
    message,
    key: const Key('backup-inline-error'),
    style: context.palette.label.copyWith(
      color: context.palette.danger,
      height: 1.35,
    ),
  );
}

class _FlatAction extends StatelessWidget {
  const _FlatAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.danger = false,
    this.quiet = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool danger;

  /// İkincil yol: dolu zemin yerine çerçeve. İki dolu düğme yan yana
  /// durduğunda hangisinin asıl yol olduğu okunmuyordu.
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = danger ? palette.danger : palette.ember;
    return AnimatedOpacity(
      opacity: onPressed == null ? .38 : 1,
      duration: const Duration(milliseconds: 160),
      child: Pressable(
        onPressed: onPressed,
        scale: .985,
        haptic: HapticFeedback.mediumImpact,
        semanticLabel: label,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: quiet ? Colors.transparent : color,
            border: quiet ? Border.all(color: color, width: 1) : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: palette.bodyStrong.copyWith(
              color: quiet ? color : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
