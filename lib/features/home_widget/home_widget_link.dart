import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import 'widget_keys.dart';

/// WidgetKit ve Android widget PendingIntent'lerinden gelen bağlantıları not
/// kimliklerine çevirir. Soğuk açılış ile açık uygulamaya gelen dokunuş aynı
/// akıştan yayınlanır.
class HomeWidgetLink {
  final _noteIds = StreamController<int>.broadcast();
  StreamSubscription<Uri?>? _clickSubscription;

  Stream<int> get noteIds => _noteIds.stream;

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
    await _noteIds.close();
  }

  void _emit(Uri? uri) {
    final id = noteIdFromWidgetUri(uri);
    if (id != null && !_noteIds.isClosed) _noteIds.add(id);
  }
}

/// Yalnızca Latermark'ın imzalı widget bağlantı biçimini kabul eder:
/// `latermark://note/12?homeWidget`.
int? noteIdFromWidgetUri(Uri? uri) {
  if (uri == null ||
      uri.scheme != kWidgetUrlScheme ||
      uri.host != 'note' ||
      !uri.queryParameters.containsKey('homeWidget') ||
      uri.pathSegments.length != 1) {
    return null;
  }

  final id = int.tryParse(uri.pathSegments.single);
  return id != null && id > 0 ? id : null;
}
