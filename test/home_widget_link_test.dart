import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/features/home_widget/home_widget_link.dart';

void main() {
  test('widget bağlantısından not kimliğini okur', () {
    final id = noteIdFromWidgetUri(Uri.parse('latermark://note/42?homeWidget'));

    expect(id, 42);
  });

  test('kilit ekranı çekim bağlantısını ayrı bir eylem olarak okur', () {
    final action = homeWidgetActionFromUri(
      Uri.parse('latermark://capture?homeWidget'),
    );

    expect(action, isA<OpenWidgetCapture>());
    expect(
      noteIdFromWidgetUri(Uri.parse('latermark://capture?homeWidget')),
      isNull,
    );
  });

  test('başka şema, eksik işaret ve geçersiz kimlik reddedilir', () {
    expect(
      noteIdFromWidgetUri(Uri.parse('notapp://note/42?homeWidget')),
      isNull,
    );
    expect(noteIdFromWidgetUri(Uri.parse('latermark://note/42')), isNull);
    expect(
      noteIdFromWidgetUri(Uri.parse('latermark://note/0?homeWidget')),
      isNull,
    );
    expect(
      noteIdFromWidgetUri(Uri.parse('latermark://home?homeWidget')),
      isNull,
    );
    expect(homeWidgetActionFromUri(Uri.parse('latermark://capture')), isNull);
    expect(
      homeWidgetActionFromUri(
        Uri.parse('latermark://capture/extra?homeWidget'),
      ),
      isNull,
    );
  });
}
