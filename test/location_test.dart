import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/core/utils/map_link.dart';
import 'package:latermark/features/notes/data/location_service.dart';

void main() {
  group('NoteLocation.fromMap', () {
    test('geçerli koordinatı çözer', () {
      final location = NoteLocation.fromMap({
        'latitude': 41.2607,
        'longitude': 29.0421,
      });
      expect(
        location,
        const NoteLocation(latitude: 41.2607, longitude: 29.0421),
      );
    });

    test('yarım koordinat koordinat değildir', () {
      expect(NoteLocation.fromMap({'latitude': 41.26}), isNull);
      expect(NoteLocation.fromMap({'longitude': 29.04}), isNull);
      expect(NoteLocation.fromMap(null), isNull);
      expect(NoteLocation.fromMap('41.26,29.04'), isNull);
    });

    test('aralık dışı ve sonsuz değerler elenir', () {
      expect(
        NoteLocation.fromMap({'latitude': 91.0, 'longitude': 0.0}),
        isNull,
      );
      expect(
        NoteLocation.fromMap({'latitude': 0.0, 'longitude': 181.0}),
        isNull,
      );
      expect(
        NoteLocation.fromMap({'latitude': double.nan, 'longitude': 0.0}),
        isNull,
      );
    });

    test('tam sayı gelen değeri de kabul eder', () {
      // Kanal `0` gönderdiğinde Dart tarafında `int` oluyor; `num` üzerinden
      // okunmazsa cast patlar ve konum sessizce kaybolurdu.
      expect(
        NoteLocation.fromMap({'latitude': 0, 'longitude': 0}),
        const NoteLocation(latitude: 0, longitude: 0),
      );
    });
  });

  group('MapLink', () {
    test('koordinat yuvarlanarak yön harfleriyle biçimlenir', () {
      expect(
        MapLink.format(
          41.26075,
          29.04213,
          north: 'K',
          south: 'G',
          east: 'D',
          west: 'B',
        ),
        '41.2608° K  ·  29.0421° D',
      );
    });

    test('güney ve batı eksi işaretiyle değil harfle anlatılır', () {
      expect(
        MapLink.format(
          -33.8688,
          -151.2093,
          north: 'N',
          south: 'S',
          east: 'E',
          west: 'W',
        ),
        '33.8688° S  ·  151.2093° W',
      );
    });

    test('adres https ve yalnızca koordinat taşır', () {
      // https olması şart: universal/app link olarak Haritalar'a yönlenmesi ve
      // uygulama içi tarayıcıya düşebilmesi buna bağlı. Özel şema ikisini de
      // yapamazdı. Adreste bir yer *adı* yok — olsaydı ağa çıkılmış olurdu.
      final url = MapLink.of(41.2607, 29.0421).toString();
      expect(url, startsWith('https://'));
      expect(url, contains('41.2607,29.0421'));
    });
  });
}
