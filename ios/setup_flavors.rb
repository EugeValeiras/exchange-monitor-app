#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.find { |t| t.name == 'Runner' }

# Define flavors
flavors = ['dev', 'prod']

# Get existing configurations as templates
debug_config = project.build_configurations.find { |c| c.name == 'Debug' }
release_config = project.build_configurations.find { |c| c.name == 'Release' }
profile_config = project.build_configurations.find { |c| c.name == 'Profile' }

# Create new build configurations for each flavor
flavors.each do |flavor|
  # Debug configuration for flavor
  debug_flavor_name = "Debug-#{flavor}"
  unless project.build_configurations.any? { |c| c.name == debug_flavor_name }
    new_config = project.add_build_configuration(debug_flavor_name, :debug)
    new_config.build_settings = debug_config.build_settings.clone
    new_config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = flavor == 'dev' ? 'AppIcon-Dev' : 'AppIcon'
    new_config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = flavor == 'dev' ? 'com.eugeniovaleiras.exchangeMonitor.dev' : 'com.eugeniovaleiras.exchangeMonitor'
    new_config.build_settings['PRODUCT_NAME'] = flavor == 'dev' ? 'Exchange DEV' : 'Exchange Monitor'

    # Also add to target
    target_config = target.add_build_configuration(debug_flavor_name, :debug)
    target_config.build_settings = target.build_configurations.find { |c| c.name == 'Debug' }.build_settings.clone
    target_config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = flavor == 'dev' ? 'AppIcon-Dev' : 'AppIcon'
    target_config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = flavor == 'dev' ? 'com.eugeniovaleiras.exchangeMonitor.dev' : 'com.eugeniovaleiras.exchangeMonitor'
    target_config.build_settings['PRODUCT_NAME'] = flavor == 'dev' ? 'Exchange DEV' : 'Exchange Monitor'
  end

  # Release configuration for flavor
  release_flavor_name = "Release-#{flavor}"
  unless project.build_configurations.any? { |c| c.name == release_flavor_name }
    new_config = project.add_build_configuration(release_flavor_name, :release)
    new_config.build_settings = release_config.build_settings.clone
    new_config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = flavor == 'dev' ? 'AppIcon-Dev' : 'AppIcon'
    new_config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = flavor == 'dev' ? 'com.eugeniovaleiras.exchangeMonitor.dev' : 'com.eugeniovaleiras.exchangeMonitor'
    new_config.build_settings['PRODUCT_NAME'] = flavor == 'dev' ? 'Exchange DEV' : 'Exchange Monitor'

    target_config = target.add_build_configuration(release_flavor_name, :release)
    target_config.build_settings = target.build_configurations.find { |c| c.name == 'Release' }.build_settings.clone
    target_config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = flavor == 'dev' ? 'AppIcon-Dev' : 'AppIcon'
    target_config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = flavor == 'dev' ? 'com.eugeniovaleiras.exchangeMonitor.dev' : 'com.eugeniovaleiras.exchangeMonitor'
    target_config.build_settings['PRODUCT_NAME'] = flavor == 'dev' ? 'Exchange DEV' : 'Exchange Monitor'
  end

  # Profile configuration for flavor
  profile_flavor_name = "Profile-#{flavor}"
  unless project.build_configurations.any? { |c| c.name == profile_flavor_name }
    new_config = project.add_build_configuration(profile_flavor_name, :release)
    new_config.build_settings = profile_config.build_settings.clone if profile_config
    new_config.build_settings ||= release_config.build_settings.clone
    new_config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = flavor == 'dev' ? 'AppIcon-Dev' : 'AppIcon'
    new_config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = flavor == 'dev' ? 'com.eugeniovaleiras.exchangeMonitor.dev' : 'com.eugeniovaleiras.exchangeMonitor'
    new_config.build_settings['PRODUCT_NAME'] = flavor == 'dev' ? 'Exchange DEV' : 'Exchange Monitor'

    target_config = target.add_build_configuration(profile_flavor_name, :release)
    profile_target = target.build_configurations.find { |c| c.name == 'Profile' }
    target_config.build_settings = (profile_target || target.build_configurations.find { |c| c.name == 'Release' }).build_settings.clone
    target_config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = flavor == 'dev' ? 'AppIcon-Dev' : 'AppIcon'
    target_config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = flavor == 'dev' ? 'com.eugeniovaleiras.exchangeMonitor.dev' : 'com.eugeniovaleiras.exchangeMonitor'
    target_config.build_settings['PRODUCT_NAME'] = flavor == 'dev' ? 'Exchange DEV' : 'Exchange Monitor'
  end
end

project.save

puts "Build configurations created successfully!"
puts "Configurations: #{project.build_configurations.map(&:name).join(', ')}"
