import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import 'widget_keys.dart';

/// WidgetKit ve Android widget PendingIntent'lerinden gelen bağlantıları
/// uygulama içi eylemlere çevirir. Soğuk açılış ile açık uygulamaya gelen
/// dokunuş aynı akıştan yayınlanır.
class HomeWidgetLink {
  final _actions = StreamController<HomeWidgetAction>.broadcast();
  StreamSubscription<Uri?>? _clickSubscription;

  Stream<HomeWidgetAction> get actions => _actions.stream;

  /// Eski not-widget tüketicileri için dar görünüm. Yeni yönlendirmeler
  /// [actions] üzerinden dinlenmeli.
  Stream<int> get noteIds => actions
      .where((action) => action is OpenWidgetNote)
      .cast<OpenWidgetNote>()
      .map((action) => action.noteId);

  Future<void> start() async {
    if (kIsWeb || (!Platform.isIOS && !Platform.isAndroid)) return;

    try {
      await HomeWidget.setAppGroupId(kAppGroupId);
      _clickSubscription = HomeWidget.widgetClicked.listen(
        _emit,
        onError: (Object error) {
          debugPrint('Widget bağlantısı dinlenemedi: $error');
        },
      );
      _emit(await HomeWidget.initiallyLaunchedFromHomeWidget());
    } catch (error) {
      debugPrint('Widget açılışı okunamadı: $error');
    }
  }

  Future<void> dispose() async {
    await _clickSubscription?.cancel();
    await _actions.close();
  }

  void _emit(Uri? uri) {
    final action = homeWidgetActionFromUri(uri);
    if (action != null && !_actions.isClosed) _actions.add(action);
  }
}

sealed class HomeWidgetAction {
  const HomeWidgetAction();
}

final class OpenWidgetNote extends HomeWidgetAction {
  const OpenWidgetNote(this.noteId);

  final int noteId;
}

final class OpenWidgetCapture extends HomeWidgetAction {
  const OpenWidgetCapture();
}

/// Yalnızca Latermark widget'larının bağlantı sözleşmesini kabul eder:
///
/// * `latermark://note/12?homeWidget`
/// * `latermark://capture?homeWidget`
HomeWidgetAction? homeWidgetActionFromUri(Uri? uri) {
  if (uri == null ||
      uri.scheme != kWidgetUrlScheme ||
      !uri.queryParameters.containsKey('homeWidget')) {
    return null;
  }

  if (uri.host == 'capture' && uri.pathSegments.isEmpty) {
    return const OpenWidgetCapture();
  }

  if (uri.host != 'note' || uri.pathSegments.length != 1) return null;
  final id = int.tryParse(uri.pathSegments.single);
  return id != null && id > 0 ? OpenWidgetNote(id) : null;
}

/// Not bağlantıları için geriye dönük uyumluluk yardımcısı.
int? noteIdFromWidgetUri(Uri? uri) {
  final action = homeWidgetActionFromUri(uri);
  return action is OpenWidgetNote ? action.noteId : null;
}
