# Runner.xcodeproj'a WidgetKit eklenti hedefini ekler.
#
# Xcode arayüzünde "File > New > Target > Widget Extension" ile yapılan işin
# betikle karşılığı. Yeniden çalıştırılabilir: hedef zaten varsa dokunmaz.
#
#   ruby ios/add_widget_target.rb
require 'xcodeproj'

PROJECT_PATH = File.expand_path('Runner.xcodeproj', __dir__)
TARGET_NAME  = 'NotWidget'
APP_GROUP    = 'group.com.mersev.latermark'

project = Xcodeproj::Project.open(PROJECT_PATH)
runner  = project.targets.find { |t| t.name == 'Runner' }
abort('Runner hedefi bulunamadı.') if runner.nil?

if project.targets.any? { |t| t.name == TARGET_NAME }
  puts "#{TARGET_NAME} zaten var — atlanıyor."
  exit 0
end

app_bundle_id = runner.build_configurations
                      .map { |c| c.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] }
                      .compact.first || 'com.mersev.latermark'
development_team = runner.build_configurations
                         .map { |c| c.build_settings['DEVELOPMENT_TEAM'] }
                         .compact.first

# --- Hedef ---------------------------------------------------------------
widget = project.new_target(
  :app_extension,
  TARGET_NAME,
  :ios,
  '17.0',
  nil,
  :swift
)

widget.build_configurations.each do |config|
  settings = config.build_settings
  settings['PRODUCT_BUNDLE_IDENTIFIER']   = "#{app_bundle_id}.#{TARGET_NAME}"
  settings['PRODUCT_NAME']                = TARGET_NAME
  settings['INFOPLIST_FILE']              = "#{TARGET_NAME}/Info.plist"
  settings['GENERATE_INFOPLIST_FILE']     = 'NO'
  settings['CODE_SIGN_ENTITLEMENTS']      = "#{TARGET_NAME}/#{TARGET_NAME}.entitlements"
  settings['IPHONEOS_DEPLOYMENT_TARGET']  = '17.0'
  settings['SWIFT_VERSION']               = '5.0'
  settings['TARGETED_DEVICE_FAMILY']      = '1,2'
  settings['SKIP_INSTALL']                = 'YES'
  settings['CURRENT_PROJECT_VERSION']     = '$(FLUTTER_BUILD_NUMBER)'
  settings['MARKETING_VERSION']           = '$(FLUTTER_BUILD_NAME)'
  settings['DEVELOPMENT_TEAM']            = development_team if development_team
  # Eklenti Flutter motorunu barındırmaz; yalnızca SwiftUI kullanır.
  settings['SWIFT_EMIT_LOC_STRINGS']      = 'YES'
end

# --- Kaynaklar -----------------------------------------------------------
group = project.main_group.find_subpath(TARGET_NAME, true)
group.set_source_tree('SOURCE_ROOT')
group.set_path(TARGET_NAME)

%w[NotDesign.swift NotWidgetEntry.swift NotWidget.swift].each do |name|
  file = group.new_reference(name)
  widget.add_file_references([file])
end
%w[Info.plist NotWidget.entitlements].each { |name| group.new_reference(name) }

# --- Uygulamaya gömme ----------------------------------------------------
runner.add_dependency(widget)

embed = runner.build_phases.find do |phase|
  phase.respond_to?(:name) && phase.name == 'Embed App Extensions'
end

if embed.nil?
  embed = runner.new_copy_files_build_phase('Embed App Extensions')
  embed.symbol_dst_subfolder_spec = :plug_ins
end
build_file = embed.add_file_reference(widget.product_reference)
build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

# Gömme adımı, Flutter'ın "Thin Binary" adımından önce çalışmalı.
runner.build_phases.delete(embed)
runner.build_phases.insert(runner.build_phases.length - 1, embed)

# --- Ana uygulamaya App Group yetkisi ------------------------------------
runner.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end

unless project.main_group['Runner'].files.any? { |f| f.path == 'Runner.entitlements' }
  project.main_group['Runner'].new_reference('Runner.entitlements')
end

# Otomatik imzalamanın App Group yetkisini görmesi için.
project.root_object.attributes['TargetAttributes'] ||= {}
project.root_object.attributes['TargetAttributes'][widget.uuid] = {
  'CreatedOnToolsVersion' => '16.0',
  'ProvisioningStyle'     => 'Automatic'
}

project.save

puts "#{TARGET_NAME} eklendi."
puts "  paket kimliği : #{app_bundle_id}.#{TARGET_NAME}"
puts "  app group     : #{APP_GROUP}"
puts "  ekip          : #{development_team || '(ayarlanmamış — cihazda Xcode’dan seçilmeli)'}"
