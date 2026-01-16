#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Fix Swift version for all targets and all configurations
project.targets.each do |target|
  target.build_configurations.each do |config|
    # Set Swift version to 5.0 for all configurations
    config.build_settings['SWIFT_VERSION'] = '5.0'
  end
end

# Also fix project-level configurations
project.build_configurations.each do |config|
  config.build_settings['SWIFT_VERSION'] = '5.0'
end

project.save
puts "Swift version fixed to 5.0 for all configurations!"
