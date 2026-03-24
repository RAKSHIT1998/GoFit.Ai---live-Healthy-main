platform :ios, '13.0'
use_frameworks!

target 'GoFit.Ai - live Healthy' do
  pod 'Google-Mobile-Ads-SDK', '~> 13.0'
  pod 'GoogleUserMessagingPlatform', '~> 1.0'
end

target 'GoFit.Ai - live HealthyTests' do
end

target 'GoFit.Ai - live HealthyUITests' do
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)']
      config.build_settings['ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'] = 'NO'
    end
  end
  # Fix aggregate target xcconfigs to suppress swift-stdlib-tool warning
  installer.aggregate_targets.each do |aggregate_target|
    aggregate_target.xcconfigs.each do |config_name, config|
      config.attributes['ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'] = 'NO'
      xcconfig_path = aggregate_target.xcconfig_path(config_name)
      config.save_as(xcconfig_path)
    end
  end
end
