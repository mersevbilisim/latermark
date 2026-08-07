# Runner.xcodeproj'a Share Extension hedefini ve ortak gelen kutusu kaynağını
# ekler. Xcode'da "File > New > Target > Share Extension" işleminin yeniden
# çalıştırılabilir karşılığıdır.
require 'xcodeproj'

PROJECT_PATH = File.expand_path('Runner.xcodeproj', __dir__)
TARGET_NAME = 'ShareExtension'

project = Xcodeproj::Project.open(PROJECT_PATH)
runner = project.targets.find { |target| target.name == 'Runner' }
abort('Runner hedefi bulunamadı.') if runner.nil?

if project.targets.any? { |target| target.name == TARGET_NAME }
  puts "#{TARGET_NAME} zaten var — atlanıyor."
  exit 0
end

app_bundle_id = runner.build_configurations
                      .filter_map { |config| config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] }
                      .first || 'com.mersev.latermark'
development_team = runner.build_configurations
                         .filter_map { |config| config.build_settings['DEVELOPMENT_TEAM'] }
                         .first

share = project.new_target(:app_extension, TARGET_NAME, :ios, '15.0', nil, :swift)

xcconfig_group = project.main_group.find_subpath(TARGET_NAME, true)
xcconfig_group.set_source_tree('SOURCE_ROOT')
xcconfig_group.set_path(TARGET_NAME)

share_xcconfig = xcconfig_group.new_reference('ShareExtension.xcconfig')
share.build_configurations.each do |config|
  settings = config.build_settings
  settings['PRODUCT_BUNDLE_IDENTIFIER'] = "#{app_bundle_id}.#{TARGET_NAME}"
  settings['PRODUCT_NAME'] = TARGET_NAME
  settings['INFOPLIST_FILE'] = "#{TARGET_NAME}/Info.plist"
  settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  settings['CODE_SIGN_ENTITLEMENTS'] = "#{TARGET_NAME}/#{TARGET_NAME}.entitlements"
  settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
  settings['SWIFT_VERSION'] = '5.0'
  settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  settings['SKIP_INSTALL'] = 'YES'
  settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
  settings['SWIFT_EMIT_LOC_STRINGS'] = 'YES'
  settings['DEVELOPMENT_TEAM'] = development_team if development_team
  config.base_configuration_reference = share_xcconfig
end

share_controller = xcconfig_group.new_reference('ShareViewController.swift')
share.add_file_references([share_controller])
%w[Info.plist ShareExtension.entitlements].each do |name|
  xcconfig_group.new_reference(name)
end

shared_group = project.main_group.find_subpath('Shared', true)
shared_group.set_source_tree('SOURCE_ROOT')
shared_group.set_path('Shared')
shared_store = shared_group.new_reference('SharedImportStore.swift')
share.add_file_references([shared_store])
runner.add_file_references([shared_store])

runner.add_dependency(share)
embed = runner.build_phases.find do |phase|
  phase.respond_to?(:name) && phase.name == 'Embed App Extensions'
end
if embed.nil?
  embed = runner.new_copy_files_build_phase('Embed App Extensions')
  embed.symbol_dst_subfolder_spec = :plug_ins
end
build_file = embed.add_file_reference(share.product_reference)
build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

# Flutter'ın Thin Binary betiği uzantıları da imzaladığı için gömme önce olur.
runner.build_phases.delete(embed)
runner.build_phases.insert(runner.build_phases.length - 1, embed)

project.root_object.attributes['TargetAttributes'] ||= {}
project.root_object.attributes['TargetAttributes'][share.uuid] = {
  'CreatedOnToolsVersion' => '16.0',
  'ProvisioningStyle' => 'Automatic',
}

project.save
puts "#{TARGET_NAME} eklendi: #{app_bundle_id}.#{TARGET_NAME}"
