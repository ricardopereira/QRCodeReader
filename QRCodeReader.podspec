Pod::Spec.new do |s|
  s.name             = "QRCodeReader"
  s.version          = "1.2"
  s.summary          = "A simple QRCode reader for Swift."
  s.homepage         = "https://github.com/ricardopereira/QRCodeReader"
  s.license          = 'MIT'
  s.author           = { "Ricardo Pereira" => "m@ricardopereira.eu" }
  s.source           = { :git => "https://github.com/ricardopereira/QRCodeReader.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/ricardopereiraw'

  s.platform     = :ios, '8.0'
  s.requires_arc = true

  s.source_files = '*.{h,swift}'
  s.frameworks = 'UIKit', 'AVFoundation'
end
