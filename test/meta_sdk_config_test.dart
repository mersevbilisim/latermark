import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Meta SDK yapılandırması kod değil, iki platform dosyası: `AndroidManifest`
/// ve `Info.plist`. Oradaki bir eksik derlemeyi kesmiyor, testi düşürmüyor,
/// çalışma anında hata da vermiyor — olaylar sessizce hiç gitmiyor ve bu
/// yayına çıktıktan haftalar sonra fark ediliyor.
///
/// Bu dosya o sessizliği bozar.
void main() {
  final androidValues = File(
    'android/app/src/main/res/values/facebook.xml',
  ).readAsStringSync();
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();
  final plist = File('ios/Runner/Info.plist').readAsStringSync();

  final androidAppId = _androidString(androidValues, 'facebook_app_id');
  final androidToken = _androidString(androidValues, 'facebook_client_token');
  final iosAppId = _plistValue(plist, 'FacebookAppID');
  final iosToken = _plistValue(plist, 'FacebookClientToken');

  group('kimlikler', () {
    test('App ID iki platformda aynı', () {
      expect(androidAppId, isNotNull);
      expect(iosAppId, isNotNull);
      expect(
        iosAppId,
        androidAppId,
        reason:
            'Ayrı düşen App ID, tek platformun ölçümünü sessizce boşa '
            'çıkarır.',
      );
    });

    test('Client Token iki platformda aynı', () {
      expect(androidToken, isNotNull);
      expect(iosToken, isNotNull);
      expect(iosToken, androidToken);
    });

    test('iOS URL şeması App ID ile eşleşiyor', () {
      // Meta `fb<APPID>` şemasını bekliyor; App ID değişip şema unutulursa
      // uygulamaya geri dönüş kırılıyor.
      expect(
        plist,
        contains('<string>fb$iosAppId</string>'),
        reason: 'Info.plist içinde fb$iosAppId şeması yok.',
      );
      // Uygulamanın kendi şeması korunmalı.
      expect(plist, contains('<string>latermark</string>'));
    });

    test('yer tutucular gerçek değerlerle değiştirildi', () {
      // Bu test, yapılandırma tamamlanana kadar bilerek kırmızı yanar:
      // eksik kurulumun tek görünür işareti bu.
      expect(
        androidAppId,
        isNot('000000000000000'),
        reason:
            'Meta App ID hâlâ yer tutucu. Değerler: '
            'android/app/src/main/res/values/facebook.xml ve '
            'ios/Runner/Info.plist (FacebookAppID + fb<APPID> şeması).',
      );
      expect(
        androidToken,
        isNot('META_CLIENT_TOKEN_PLACEHOLDER'),
        reason:
            'Client Token hâlâ yer tutucu. Meta panelinde '
            'Ayarlar → Gelişmiş → İstemci Jetonu. App Secret değil.',
      );
    });

    test('App Secret pakete girmemiş', () {
      // App Secret sunucu tarafı kimlik bilgisidir; uygulama paketinden
      // okunabilir. Client Token ile karıştırmak kolay, sonucu ağır.
      for (final key in const ['facebook_app_secret', 'FacebookAppSecret']) {
        expect(androidValues, isNot(contains(key)));
        expect(manifest, isNot(contains(key)));
        expect(plist, isNot(contains(key)));
      }
    });
  });

  group('bayraklar', () {
    test('Android: otomatik loglama ve reklam kimliği açık', () {
      expect(
        _metaData(manifest, 'com.facebook.sdk.AutoLogAppEventsEnabled'),
        'true',
      );
      // Android'de ATT gibi bir istem yok: reklam kimliğinin kullanıcıya
      // maliyeti sıfır, karşılığı tam attribution.
      expect(
        _metaData(manifest, 'com.facebook.sdk.AdvertiserIDCollectionEnabled'),
        'true',
      );
      expect(
        _metaData(manifest, 'com.facebook.sdk.ApplicationId'),
        '@string/facebook_app_id',
      );
      expect(
        _metaData(manifest, 'com.facebook.sdk.ClientToken'),
        '@string/facebook_client_token',
      );
    });

    test('iOS: otomatik loglama açık, reklam kimliği kapalı', () {
      expect(_plistValue(plist, 'FacebookAutoLogAppEventsEnabled'), 'true');
      expect(_plistValue(plist, 'FacebookAdvertiserIDCollectionEnabled'),
          'false');
    });

    test('iOS reklam kimliği ile ATT istemi birlikte değişir', () {
      // Apple istemsiz IDFA erişimini reddediyor; tersi de doğru — istem
      // isteyip kimliği toplamamak kullanıcıya bedelini boşuna ödetiyor.
      // Bu iki yarı ayrı düşerse hata mağazada ortaya çıkar, burada değil.
      final collecting =
          _plistValue(plist, 'FacebookAdvertiserIDCollectionEnabled') == 'true';
      final hasAttKey = plist.contains(
        '<key>NSUserTrackingUsageDescription</key>',
      );

      expect(
        hasAttKey,
        collecting,
        reason: collecting
            ? 'Reklam kimliği açık ama NSUserTrackingUsageDescription yok; '
                  'ATT isteği de aynı değişiklikte eklenmeli.'
            : 'Reklam kimliği kapalıyken ATT anahtarı gereksiz; istemi '
                  'göstermeden IDFA toplanmıyor.',
      );
    });
  });

  group('izinler ve kimlikler', () {
    test('AD_ID izni tanımlı ve kaldırılmamış', () {
      expect(
        manifest,
        contains('android:name="com.google.android.gms.permission.AD_ID"'),
      );
      // Kimi şablonlar bu izni `tools:node="remove"` ile düşürüyor; o blok
      // geri gelirse reklam kimliği Android'de de toplanmaz.
      expect(
        RegExp(
          r'AD_ID"[^>]*tools:node="remove"',
          dotAll: true,
        ).hasMatch(manifest),
        isFalse,
      );
    });

    test('INTERNET izni yayın manifestinde', () {
      // Uygulamanın geri kalanı ağa çıkmıyor; izin yalnız debug manifestinde
      // duruyordu. Meta olayları onsuz sessizce düşer.
      expect(
        manifest,
        contains('android:name="android.permission.INTERNET"'),
      );
    });

    test('SKAdNetwork kimlikleri tanımlı', () {
      // IDFA olmadan kurulum eşleşmesi buradan yürüyor.
      expect(plist, contains('<string>v9wttpbfk9.skadnetwork</string>'));
      expect(plist, contains('<string>n38lu8286q.skadnetwork</string>'));
    });
  });
}

/// `res/values/*.xml` içindeki bir string kaynağının değeri.
String? _androidString(String xml, String name) {
  final match = RegExp(
    '<string name="${RegExp.escape(name)}"[^>]*>(.*?)</string>',
    dotAll: true,
  ).firstMatch(xml);
  return match?.group(1);
}

/// Manifestteki bir `<meta-data>` düğümünün `android:value` değeri.
///
/// Ad ile değer ayrı satırlarda olabildiği için düğüm boşluk toleranslı
/// okunuyor.
String? _metaData(String manifest, String name) {
  final match = RegExp(
    'android:name="${RegExp.escape(name)}"\\s*android:value="(.*?)"',
    dotAll: true,
  ).firstMatch(manifest);
  return match?.group(1);
}

/// `<key>NAME</key>` sonrasındaki ilk değer düğümü.
///
/// `<string>` içeriğini olduğu gibi, `<true/>`/`<false/>` düğümlerini
/// `'true'`/`'false'` olarak döndürür.
String? _plistValue(String plist, String key) {
  final match = RegExp(
    '<key>${RegExp.escape(key)}</key>\\s*'
    '(?:<string>(.*?)</string>|<(true|false)\\s*/>)',
    dotAll: true,
  ).firstMatch(plist);
  if (match == null) return null;
  return match.group(1) ?? match.group(2);
}
