# Runner.xcodeproj'a ExtensionKit tabanli App Intents hedefini ekler.
#
# Xcode 26'daki "App Intents Extension" sablonunun yeniden calistirilabilir
# karsiligidir. Kaynak dosyalar ios/AppIntentsExtension altinda hazir olmalidir.
#
#   ruby ios/add_app_intents_extension_target.rb

require 'xcodeproj'

PROJECT_PATH = File.expand_path('Runner.xcodeproj', __dir__)
EXTENSION_DIR = File.expand_path('AppIntentsExtension', __dir__)
TARGET_NAME = 'AppIntentsExtension'
BUNDLE_IDENTIFIER = 'com.mersev.latermark.AppIntentsExtension'
DEPLOYMENT_TARGET = '16.0'
PRODUCT_TYPE = 'com.apple.product-type.extensionkit-extension'

required_files = %w[
  Info.plist
  AppIntentsExtension.entitlements
  AppIntentsExtension.xcconfig
]
missing_files = required_files.reject do |name|
  File.file?(File.join(EXTENSION_DIR, name))
end
abort("Eksik App Intents dosyalari: #{missing_files.join(', ')}") unless missing_files.empty?

swift_paths = Dir.glob(File.join(EXTENSION_DIR, '**', '*.swift')).sort
abort('AppIntentsExtension altinda Swift kaynagi bulunamadi.') if swift_paths.empty?

project = Xcodeproj::Project.open(PROJECT_PATH)
runner = project.targets.find { |target| target.name == 'Runner' }
abort('Runner hedefi bulunamadi.') if runner.nil?

target = project.targets.find { |candidate| candidate.name == TARGET_NAME }
unless target
  # xcodeproj ExtensionKit urun tipini sembolik olarak bilmiyor. Once ayni
  # paket yapisina sahip bir app-extension olusturup urun tipini Xcode'un
  # App Intents sablonunda kullandigi UTI'a ceviriyoruz.
  target = project.new_target(
    :app_extension,
    TARGET_NAME,
    :ios,
    DEPLOYMENT_TARGET,
    nil,
    :swift
  )
end
target.product_type = PRODUCT_TYPE

development_team = runner.build_configurations
                         .map { |config| config.build_settings['DEVELOPMENT_TEAM'] }
                         .compact
                         .first

group = project.main_group.find_subpath(TARGET_NAME, true)
group.set_source_tree('SOURCE_ROOT')
group.set_path(TARGET_NAME)

def ensure_reference(group, path)
  group.files.find { |file| file.path == path } || group.new_reference(path)
end

def add_to_phase_once(phase, file_reference)
  return if phase.files_references.include?(file_reference)

  phase.add_file_reference(file_reference)
end

xcconfig = ensure_reference(group, 'AppIntentsExtension.xcconfig')
%w[Info.plist AppIntentsExtension.entitlements].each do |name|
  ensure_reference(group, name)
end

target.build_configurations.each do |config|
  settings = config.build_settings
  settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
  settings['CODE_SIGN_ENTITLEMENTS'] = 'AppIntentsExtension/AppIntentsExtension.entitlements'
  settings['CODE_SIGN_STYLE'] = 'Automatic'
  settings['CURRENT_PROJECT_VERSION'] = '$(FLUTTER_BUILD_NUMBER)'
  settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  settings['INFOPLIST_FILE'] = 'AppIntentsExtension/Info.plist'
  settings['IPHONEOS_DEPLOYMENT_TARGET'] = DEPLOYMENT_TARGET
  settings['LD_RUNPATH_SEARCH_PATHS'] = [
    '$(inherited)',
    '@executable_path/Frameworks',
    '@executable_path/../../Frameworks',
  ]
  settings['MARKETING_VERSION'] = '$(FLUTTER_BUILD_NAME)'
  settings['PRODUCT_BUNDLE_IDENTIFIER'] = BUNDLE_IDENTIFIER
  settings['PRODUCT_NAME'] = TARGET_NAME
  settings['SKIP_INSTALL'] = 'YES'
  settings['SWIFT_EMIT_LOC_STRINGS'] = 'YES'
  settings['SWIFT_VERSION'] = '5.0'
  settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  settings['DEVELOPMENT_TEAM'] = development_team if development_team
  config.base_configuration_reference = xcconfig
end

# Intent tanimlari **iki hedefte birden** derlenir.
#
# Uzantinin isi intent'i calistirmak. Sesli tetiklemede sistem uygulamanin
# kendi `Metadata.appintents` dosyasina bakiyor; Runner'da o dosya hic
# uretilmezse Siri kisayollari Kestirmeler'de gosteriyor ama cumleyle
# calistiramiyor - uygulamayi acmakla yetiniyor. Xcode'un App Intents
# Extension sablonu da kaynaklari iki hedefe birden ekler.
#
# Uzantinin giris noktasi (`@main`) disarida kalir; o yalniz uzantinin.
# Kisayol saglayicisi yalniz uygulamada, intent'ler iki hedefte de.
#
# Ikisi ayni sagayiciyi ilan ederse sistem ayni kisayollari iki kez goruyor.
# Apple'in ayrimi: `AppShortcutsProvider` uygulamanin hedefinde yasar,
# `AppIntent` uygulamalari uzantida calisir - bu yuzden intent kaynagi ortak,
# saglayici degil. Uzantinin `@main` giris noktasi da yalniz uzantinin.
RUNNER_ONLY_SOURCES = %w[LatermarkShortcuts.swift].freeze
EXTENSION_ONLY_SOURCES = %w[LatermarkAppIntentsExtension.swift].freeze

swift_paths.each do |absolute_path|
  relative_path = absolute_path.delete_prefix("#{EXTENSION_DIR}/")
  reference = ensure_reference(group, relative_path)

  unless RUNNER_ONLY_SOURCES.include?(relative_path)
    add_to_phase_once(target.source_build_phase, reference)
  end
  next if EXTENSION_ONLY_SOURCES.include?(relative_path)

  add_to_phase_once(runner.source_build_phase, reference)
end

# Onceki surum saglayiciyi uzantiya da eklemisti; oradan cikar.
shortcuts_reference = group.files.find do |file|
  RUNNER_ONLY_SOURCES.include?(file.path)
end
if shortcuts_reference
  target.source_build_phase.files.dup.each do |file|
    next unless file.file_ref == shortcuts_reference

    target.source_build_phase.remove_build_file(file)
  end
end

shared_group = project.main_group.find_subpath('Shared', false)
abort('Shared proje grubu bulunamadi.') if shared_group.nil?

shared_store = shared_group.files.find { |file| file.path == 'SharedImportStore.swift' }
abort('SharedImportStore.swift proje referansi bulunamadi.') if shared_store.nil?
add_to_phase_once(target.source_build_phase, shared_store)

# Localizable.strings ve AppShortcuts.strings dosyalarini Xcode'un bekledigi
# PBXVariantGroup yapisinda toplar. Ayni ada sahip Shared yerellestirmeleri
# ayrica eklenmez; aksi halde iki kaynak ayni cikti yoluna yazmaya calisir.
localized_paths = Dir.glob(File.join(EXTENSION_DIR, '*.lproj', '*.{strings,stringsdict}')).sort
localized_paths.group_by { |path| File.basename(path) }.each do |resource_name, paths|
  variant_group = group.children.find do |child|
    child.isa == 'PBXVariantGroup' && child.name == resource_name
  end
  variant_group ||= group.new_variant_group(resource_name)

  paths.each do |absolute_path|
    locale = File.basename(File.dirname(absolute_path), '.lproj')
    relative_path = absolute_path.delete_prefix("#{EXTENSION_DIR}/")
    localized_reference = variant_group.files.find do |file|
      file.path == relative_path || file.name == locale
    end
    localized_reference ||= variant_group.new_reference(relative_path)
    localized_reference.name = locale
  end

  add_to_phase_once(target.resources_build_phase, variant_group)

  # Ayni kaynaklar Runner'a da baglanir.
  #
  # Kisayollari uygulama ilan ediyor; uygulamanin paketinde bu tablolar yoksa
  # sistem hem basliklari hem tetikleme cumlelerini **Ingilizce anahtarlariyla**
  # kaydediyor - Kestirmeler'de "Add a Note" goruluyor ve Turkce soylenen hicbir
  # cumle tutmuyor. Runner'in kendi `Localizable.strings` tablosu olmadigi icin
  # cakisma da yok (`.lproj` klasorlerinde yalniz `InfoPlist.strings` var).
  add_to_phase_once(runner.resources_build_phase, variant_group)
end

# String Catalog gibi tek dosyali yerellestirme kaynaklarini da destekle.
Dir.glob(File.join(EXTENSION_DIR, '*.{xcstrings,stringsdict}')).sort.each do |absolute_path|
  relative_path = absolute_path.delete_prefix("#{EXTENSION_DIR}/")
  reference = ensure_reference(group, relative_path)
  add_to_phase_once(target.resources_build_phase, reference)
end

unless runner.dependencies.any? { |dependency| dependency.target == target }
  runner.add_dependency(target)
end

# ExtensionKit uzantisi `PlugIns/` altina konmaz.
#
# installd oradaki her `.appex`ten bir `NSExtension` sozlugu bekliyor;
# ExtensionKit bildirimi (`EXAppExtensionAttributes`) onun yerine geciyor ve
# kurulum "AppexBundleMissingNSExtensionDict" ile dusuyor. Derleme bunu hic
# gormuyor - hata yalnizca cihaza kurarken cikiyor.
#
# Eski tip uzantilar (NotWidget, ShareExtension) `PlugIns/`de kalmali. Bu
# yuzden ayri bir kopyalama adimi aciliyor; ikisi tek adimda toplanamaz cunku
# hedef klasoru adim belirliyor, dosya degil.
EXTENSIONKIT_PHASE_NAME = 'Embed ExtensionKit Extensions'
LEGACY_PHASE_NAME = 'Embed App Extensions'
INVALIDATE_SSU_PHASE_NAME = 'Invalidate App Intents SSU Cache'

legacy = runner.build_phases.find do |phase|
  phase.respond_to?(:name) && phase.name == LEGACY_PHASE_NAME
end
if legacy
  # Bu betigin onceki surumu appex'i eski adima ekliyordu ve Xcode adimin
  # hedefini ExtensionKit'inkine cevirip widget ile paylasim uzantisini de
  # `Extensions/`e tasiyordu. Ikisini de geri al.
  legacy.files.dup.each do |file|
    legacy.remove_build_file(file) if file.file_ref == target.product_reference
  end
  if legacy.dst_path.to_s.include?('EXTENSIONS_FOLDER_PATH')
    legacy.dst_path = ''
    legacy.symbol_dst_subfolder_spec = :plug_ins
  end
end

embed = runner.build_phases.find do |phase|
  phase.respond_to?(:name) && phase.name == EXTENSIONKIT_PHASE_NAME
end
embed ||= runner.new_copy_files_build_phase(EXTENSIONKIT_PHASE_NAME)
embed.symbol_dst_subfolder_spec = :products_directory
embed.dst_path = '$(EXTENSIONS_FOLDER_PATH)'

unless embed.files_references.include?(target.product_reference)
  build_file = embed.add_file_reference(target.product_reference)
  build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
end

# Flutter'in Thin Binary betigi gomulu uzantilari imzaladigi icin kopyalama
# adimi onun hemen oncesinde kalmali.
runner.build_phases.delete(embed)
thin_binary_index = runner.build_phases.index do |phase|
  phase.respond_to?(:name) && phase.name == 'Thin Binary'
end
runner.build_phases.insert(thin_binary_index || runner.build_phases.length, embed)

# Flutter her cihaz derlemesinde urun paketini yeniden olusturabiliyor; Xcode
# ise App Intents NLU ara ciktisini (`TARGET_TEMP_DIR/ssu/root.ssu.yaml`)
# guncel sayip islemciyi tekrar calistirmiyor. Islemcinin urun kopyasi bu
# durumda kayboluyor: Kestirmeler aksiyonu goruyor ama Siri cumleyi
# eslestiremiyor. Yalnizca uretilmis ara ciktiyi build basinda gecersiz kilarak
# Xcode'un kendi SSU islemcisinin her urun icin yeniden calismasini sagla.
invalidate_ssu = runner.build_phases.find do |phase|
  phase.respond_to?(:name) && phase.name == INVALIDATE_SSU_PHASE_NAME
end
invalidate_ssu ||= runner.new_shell_script_build_phase(INVALIDATE_SSU_PHASE_NAME)
invalidate_ssu.always_out_of_date = '1'
invalidate_ssu.input_paths = []
invalidate_ssu.output_paths = []
invalidate_ssu.shell_script = <<~'SH'
  set -e

  case "${TARGET_TEMP_DIR}" in
    */Runner.build/*/Runner.build)
      rm -f "${TARGET_TEMP_DIR}/ssu/root.ssu.yaml"
      ;;
    *)
      echo "Unexpected TARGET_TEMP_DIR; refusing to remove SSU cache: ${TARGET_TEMP_DIR}" >&2
      exit 1
      ;;
  esac
SH

# Ilk kullanici build adimindan once calissin; kaynak derleme ve metadata
# cikarma bundan sonra gerceklesir.
runner.build_phases.delete(invalidate_ssu)
runner.build_phases.unshift(invalidate_ssu)

project.root_object.attributes['TargetAttributes'] ||= {}
project.root_object.attributes['TargetAttributes'][target.uuid] = {
  'CreatedOnToolsVersion' => '26.0',
  'ProvisioningStyle' => 'Automatic',
}

project.save

puts "#{TARGET_NAME} hedefi baglandi."
puts "  urun tipi : #{PRODUCT_TYPE}"
puts "  paket      : #{BUNDLE_IDENTIFIER}"
puts "  iOS        : #{DEPLOYMENT_TARGET}+"
