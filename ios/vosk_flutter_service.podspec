#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint vosk_flutter.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'vosk_flutter_service'

  s.version          = '0.1.3'
  s.summary          = 'Flutter plugin for offline speech recognition using the Vosk speech recognition toolkit.'
  s.description      = <<-DESC
Flutter plugin for offline speech recognition using the Vosk speech recognition toolkit.
                       DESC
  s.homepage         = 'https://www.bechattaoui.dev'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Dhia Bechattaoui' => 'dhia@bechattaoui.dev' }
  s.source           = { :path => '.' }
  s.source_files = 'vosk_flutter_service/Classes/**/*'
  s.public_header_files = 'vosk_flutter_service/Classes/vosk_api.h'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'
  s.vendored_frameworks = 'Frameworks/vosk.xcframework'
  s.libraries = 'c++'
  s.frameworks = 'Accelerate'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
  s.swift_version = '5.0'

  s.preserve_paths = 'Frameworks/vosk.xcframework/**/*', 'vosk_flutter_service/Classes/vosk_api.h'
end
