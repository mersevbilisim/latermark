import 'package:flutter_test/flutter_test.dart';
import 'package:not_app/features/home_widget/home_widget_link.dart';

void main() {
  test('widget bağlantısından not kimliğini okur', () {
    final id = noteIdFromWidgetUri(Uri.parse('latermark://note/42?homeWidget'));

    expect(id, 42);
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
  });
}
