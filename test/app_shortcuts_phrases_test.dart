import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Siri'nin App Shortcut cümlelerinin **on dilde** tutarlılığı.
///
/// Bu dosyalar Dart tarafından hiç görülmüyor: Xcode paketliyor, eşleşmeyi iOS
/// yapıyor ve tutmayan bir cümle hata vermiyor — Siri yalnızca "anlamadım"
/// diyor. Yani buradaki her hata **sessizce yayınlanır**. ARB tarafında
/// `l10n_missing.txt` disiplini var; bunun karşılığı yoktu.
///
/// Test cümlenin *doğal* olup olmadığına bakamaz — o anadili işi. Baktığı şey
/// makineyle kesin bilinebilen kısım: anahtarların örtüşmesi, Apple'ın zorunlu
/// kıldığı yer tutucunun varlığı, boşa harcanan slotlar ve uygulama adının
/// serbest kaldığı bir çıkış cümlesinin bulunması.
void main() {
  final root = Directory('ios/AppIntentsExtension');

  /// Apple her cümlede bunu şart koşuyor; taşımayan cümle sessizce atılıyor.
  const placeholder = r'${applicationName}';

  /// Adın **bitişik** bir parçacık aldığı diller.
  ///
  /// Türkçe `'a`/`'ta` ekliyor, Japonca ve Korece parçacığı (`で`, `に`, `에`)
  /// doğrudan yapıştırıyor. Bu, konuşma tanıma adı beklenmedik yerden bölerse
  /// eşleşmeyi tümden kaybettiriyor — Türkçe bu yüzden `ile` biçimlerini de
  /// taşıyor ve adı serbest bırakıyor.
  ///
  /// ja/ko'da o çıpa **yok** ve eklemek anadili kararı: Japoncada parçacıktan
  /// önce boşluk yazmak doğal değil. Liste bu yüzden bir muafiyet değil, açık
  /// bir borç kaydı — biri o dilde serbest bir biçim eklerse test buradan
  /// düşmesini söyleyecek.
  const gluedNameLocales = {'ja', 'ko'};

  /// `"anahtar" = "değer";` satırlarını okur.
  Map<String, String> readStrings(File file) {
    final pattern = RegExp(r'^\s*"(.+?)"\s*=\s*"(.+?)"\s*;\s*$');
    final entries = <String, String>{};
    for (final line in file.readAsLinesSync()) {
      final match = pattern.firstMatch(line);
      if (match == null) continue;
      entries[match.group(1)!] = match.group(2)!;
    }
    return entries;
  }

  Map<String, Map<String, String>> readAll() {
    final byLocale = <String, Map<String, String>>{};
    for (final entity in root.listSync()) {
      if (entity is! Directory || !entity.path.endsWith('.lproj')) continue;
      final file = File('${entity.path}/AppShortcuts.strings');
      if (!file.existsSync()) continue;
      final locale = entity.uri.pathSegments
          .lastWhere((segment) => segment.isNotEmpty)
          .replaceAll('.lproj', '');
      byLocale[locale] = readStrings(file);
    }
    return byLocale;
  }

  test('dizin ve dosyalar yerinde', () {
    expect(root.existsSync(), isTrue, reason: 'Cümle dosyalarının kökü yok');
    final all = readAll();
    // Uygulamanın desteklediği on dil; biri eksikse o dilde Siri İngilizce
    // cümlelere düşer ve kullanıcı sebebini hiç öğrenemez.
    expect(all.keys.toSet(), {
      'en',
      'tr',
      'de',
      'es',
      'fr',
      'it',
      'ja',
      'ko',
      'pt',
      'pt-BR',
    });
  });

  test('bütün diller aynı anahtar kümesini taşıyor', () {
    final all = readAll();
    final reference = all['en']!.keys.toSet();
    expect(reference, isNotEmpty);

    for (final entry in all.entries) {
      expect(
        entry.value.keys.toSet(),
        reference,
        reason:
            '${entry.key} dilinin anahtarları İngilizceden ayrışmış; '
            'eksik anahtar o cümleyi o dilde tamamen kaybettirir',
      );
    }
  });

  test('her cümle uygulama adı yer tutucusunu taşıyor', () {
    for (final entry in readAll().entries) {
      for (final phrase in entry.value.entries) {
        expect(
          phrase.value.contains(placeholder),
          isTrue,
          reason:
              '${entry.key}: "${phrase.value}" yer tutucusuz. '
              'Apple böyle bir cümleyi hiç kaydetmiyor.',
        );
      }
    }
  });

  test('bir dilin içinde yinelenen cümle yok', () {
    for (final entry in readAll().entries) {
      final values = entry.value.values.toList();
      expect(
        values.toSet().length,
        values.length,
        reason:
            '${entry.key}: aynı cümle iki anahtarda. Yinelenen bir slot, '
            'kullanıcının söyleyebileceği başka bir biçimi çöpe atıyor.',
      );
    }
  });

  test('adın serbest kaldığı bir çıkış cümlesi her dilde var', () {
    final all = readAll();
    final glued = <String>{};

    for (final entry in all.entries) {
      // Yer tutucunun ardından boşluk gelmesi ya da cümleyi bitirmesi: ad
      // kendi başına bir sözcük olarak duruyor demek.
      final hasFreeName = entry.value.values.any((phrase) {
        final index = phrase.indexOf(placeholder);
        final after = index + placeholder.length;
        return after >= phrase.length || phrase[after] == ' ';
      });
      if (!hasFreeName) glued.add(entry.key);
    }

    expect(
      glued,
      gluedNameLocales,
      reason:
          'Adın serbest kaldığı bir biçimi olmayan diller değişti. Yeni bir '
          'dil listeye düştüyse çıpasını kaybetmiş demektir; bir dil listeden '
          'çıktıysa `gluedNameLocales` güncellenmeli.',
    );
  });

  test('alternatif uygulama adı sayısı iOS sınırını aşmıyor', () {
    // iOS'un yükleyicisi bunu **kurulum anında** reddediyor:
    // `TooManyAlternativeAppNames`, MIInstallerErrorDomain 132. Yani hata
    // derlemede değil, cihaza atarken çıkıyor — CI'da görülmesi güç, kabloyla
    // deneyene ise "Latermark yüklenemiyor" olarak görünüyor.
    //
    // Sınır her yerelleştirilmiş Info.plist için üç. Bu test yalnız temel
    // listeyi sayıyor; dile göre ayrı liste verilirse burası da genişlemeli.
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final names = RegExp(
      r'<key>INAlternativeAppName</key>',
    ).allMatches(plist).length;

    expect(
      names,
      lessThanOrEqualTo(3),
      reason:
          'iOS en fazla 3 alternatif ad kabul ediyor; $names tanımlanmış. '
          'Fazlası uygulamayı cihaza hiç kurdurmaz.',
    );
  });

  test('Swift tarafındaki cümleler İngilizce dosyayla birebir', () {
    // Asıl kayma riski burada: `phrases` dizisine bir cümle eklenip
    // `.strings` dosyaları unutulursa o cümle bütün dillerde İngilizce
    // kalıyor, ve bunu kimse bir hata olarak görmüyor.
    final swift = File(
      'ios/AppIntentsExtension/LatermarkShortcuts.swift',
    ).readAsStringSync();

    final declared = RegExp(r'"([^"\n]*\\\(\.applicationName\)[^"\n]*)"')
        .allMatches(swift)
        .map(
          (match) =>
              match.group(1)!.replaceAll(r'\(.applicationName)', placeholder),
        )
        .toSet();

    expect(declared, isNotEmpty, reason: 'Swift tarafında cümle bulunamadı');
    expect(
      readAll()['en']!.keys.toSet(),
      declared,
      reason:
          'Swift `phrases` dizisi ile en.lproj/AppShortcuts.strings ayrışmış',
    );
  });
}
