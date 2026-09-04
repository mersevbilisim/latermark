import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/core/theme/accent_tone.dart';
import 'package:latermark/core/theme/app_accent.dart';
import 'package:latermark/core/theme/app_palette.dart';
import 'package:latermark/features/notes/data/notes_database.dart';
import 'package:latermark/features/settings/data/settings_repository.dart';

/// İki renk arasındaki WCAG karşıtlık oranı.
double _contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  final light = first > second ? first : second;
  final dark = first > second ? second : first;
  return (light + 0.05) / (dark + 0.05);
}

void main() {
  test('her ton her üç zeminde de okunur kalıyor', () {
    // Özel rengin bütün varlık sebebi bu: kullanıcı ham RGB seçseydi
    // tonların bir kısmı üç zeminden en az birinde kaybolurdu. Ton başına
    // parlaklığı uygulama sabitlediği için burada **istisnasız** hepsi
    // geçmeli — tek bir açının bile düşmesi seçicinin sözünü bozar.
    var worstDark = 99.0;
    var worstLight = 99.0;

    for (var hue = 0; hue < AccentTone.hueCount; hue++) {
      final dark = AccentTone.colorFor(hue, Brightness.dark);
      final light = AccentTone.colorFor(hue, Brightness.light);

      final onCanvas = _contrast(dark, AppPalette.dark.canvas);
      final onPaper = _contrast(light, AppPalette.light.canvas);
      // Fotoğraf zemini temadan bağımsız koyudur ve koyu tema tonunu kullanır.
      final onPhoto = _contrast(AccentTone.onPhoto(hue), OnPhoto.canvas);

      if (onCanvas < worstDark) worstDark = onCanvas;
      if (onPaper < worstLight) worstLight = onPaper;

      expect(onCanvas, greaterThan(4.5), reason: 'ton $hue koyu zeminde');
      expect(onPaper, greaterThan(4.5), reason: 'ton $hue aydınlık zeminde');
      expect(onPhoto, greaterThan(4.5), reason: 'ton $hue fotoğraf üstünde');
    }

    // Küratörlü altı renk de aynı bandın içinde: özel bir ton yanlarında
    // yabancı durmuyor.
    for (final accent in AppAccent.values) {
      if (accent == AppAccent.custom) continue;
      expect(
        _contrast(accent.colorFor(Brightness.dark), AppPalette.dark.canvas),
        greaterThan(4.5),
      );
    }

    expect(worstDark, greaterThan(4.5));
    expect(worstLight, greaterThan(4.5));
  });

  test('ton çemberin dışına taşsa da normalleşiyor', () {
    expect(AccentTone.normalizeHue(360), 0);
    expect(AccentTone.normalizeHue(-1), 359);
    expect(AccentTone.normalizeHue(725), 5);
    // Aynı ton her zaman aynı rengi veriyor: sürüklerken titremesin.
    expect(
      AccentTone.colorFor(-1, Brightness.dark),
      AccentTone.colorFor(359, Brightness.dark),
    );
  });

  test('palet özel tonu taşıyor ve parlaklık kopyasında koruyor', () {
    final palette = AppPalette.forAccent(
      Brightness.dark,
      AppAccent.custom,
      customHue: 214,
    );
    expect(palette.accent, AppAccent.custom);
    expect(palette.customHue, 214);
    expect(palette.ember, AccentTone.colorFor(214, Brightness.dark));
    expect(palette.onPhotoAccent, AccentTone.onPhoto(214));

    // Tema parlaklığı değişince palet yeniden kuruluyor; ton orada
    // kaybolursa kullanıcının rengi aydınlık temada turuncuya dönerdi.
    final light = palette.copyWith(brightness: Brightness.light);
    expect(light.accent, AppAccent.custom);
    expect(light.customHue, 214);
    expect(light.ember, AccentTone.colorFor(214, Brightness.light));
  });

  test('özel renk tek yazıda hem seçimi hem tonu kaydediyor', () async {
    final sandbox = await Directory.systemTemp.createTemp('lm_custom_accent');
    addTearDown(() {
      if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
    });

    final file = File('${sandbox.path}/latermark_db.sqlite');
    var database = NotesDatabase.forExecutor(NativeDatabase(file));
    var repository = SettingsRepository(database);

    expect((await repository.read()).accent, AppAccent.orange);
    expect((await repository.read()).accentHue, AccentTone.defaultHue);

    // Ayrı yazılsalardı arada bir akış yayını çıkar ve arayüz bir kare
    // boyunca eski rengi yeni tonla karıştırırdı.
    final emitted = <String>[];
    final sub = repository.watch().listen(
      (value) => emitted.add('${value.accent.name}:${value.accentHue}'),
    );

    await repository.setCustomAccent(214);
    var settings = await repository.read();
    expect(settings.accent, AppAccent.custom);
    expect(settings.accentHue, 214);
    expect(emitted, isNot(contains('custom:${AccentTone.defaultHue}')));
    await sub.cancel();

    // Ton çemberin dışından gelse de normalleşerek yazılıyor.
    await repository.setCustomAccent(-30);
    expect((await repository.read()).accentHue, 330);

    // Küratörlü bir renge dönen kullanıcı tonunu kaybetmiyor: geri
    // döndüğünde kendi rengini yeniden ayarlamak zorunda kalmamalı.
    await repository.setAccent(AppAccent.green);
    settings = await repository.read();
    expect(settings.accent, AppAccent.green);
    expect(settings.accentHue, 330);

    await database.close();

    // Ve seçim yeniden açılışta yerinde.
    database = NotesDatabase.forExecutor(NativeDatabase(file));
    repository = SettingsRepository(database);
    expect((await repository.read()).accentHue, 330);
    await database.close();
  });
}
