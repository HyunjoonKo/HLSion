Pod::Spec.new do |s|
  s.name         = 'HLSionKo'
  s.module_name  = 'HLSion'
  s.version      = '0.5.3'
  s.summary      = 'HLSion in Swift for iOS'
  s.description  = 'HTTP Live Streaming (HLS) download manager to offline playback.'
  s.homepage     = 'https://github.com/HyunjoonKo/HLSion'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { 'r-plus' => 'https://twitter.com/r_plus' }
  s.source       = { :git => 'https://github.com/HyunjoonKo/HLSion.git',
                     :tag => "#{s.version}" }
  s.platform     = :ios, '10.0'
  s.source_files = 'Sources/*.{swift,h}'
  s.frameworks   = 'UIKit', 'Foundation', 'AVFoundation'
  s.swift_version = '5.0'
end
