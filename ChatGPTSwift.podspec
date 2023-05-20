Pod::Spec.new do |s|

    s.name         = "ChatGPTSwift"
    s.version      = "1.4.0"
    s.summary      = "A Swift Client to interact with OpenAI Public ChatGPT API"
  
    s.description  = <<-DESC
                     Provide API to send prompt with histories both for stream and non-stream HTTP response
                     DESC
  
    s.homepage     = "https://github.com/alfianlosari/ChatGPTSwift"
    s.screenshots  = "https://camo.githubusercontent.com/3aedf67d1f99b2a04f7cbcac53016494274aa19605eb0189a54889d6aa60c96d/68747470733a2f2f696d6167697a65722e696d616765736861636b2e636f6d2f76322f363430783438307139302f3932332f63394d5042412e706e67"
  
    s.license      = { :type => "MIT", :file => "LICENSE" }
  
    s.authors            = { "alfianlosari" => "alfianlosari@gmail.com" }
    s.social_media_url   = "https://github.com/alfianlosari"
  
    s.swift_versions = ['5.7']
  
    s.ios.deployment_target = "15.0"
    s.osx.deployment_target = "13.0"
    # s.tvos.deployment_target = "15.0"
    # s.watchos.deployment_target = "8.0"
  
    s.source       = { :git => "https://github.com/alfianlosari/ChatGPTSwift.git", :tag => s.version }
    s.source_files  = ["Sources/ChatGPTSwift/**/*.swift"]
    s.dependency 'GPTEncoder', '1.0.0'
  
    s.requires_arc = true
  end
