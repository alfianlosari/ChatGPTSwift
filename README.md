# ChatGPTSwift API

![Alt text](https://imagizer.imageshack.com/v2/640x480q90/923/c9MPBA.png "image")

Access OpenAI ChatGPT Official API using Swift. Works on all Apple platforms.

## Supported Platforms

- iOS/tvOS 15 and above
- macOS 12 and above
- watchOS 8 and above
- Linux

## Installation

### Swift Package Manager
- File > Swift Packages > Add Package Dependency
- Add https://github.com/alfianlosari/ChatGPTSwift.git

### Cocoapods
```ruby
platform :ios, '15.0'
use_frameworks!

target 'MyApp' do
  pod 'ChatGPTSwift', '~> 1.1.1'
end
```

## Requirement

Register for API key from [OpenAI](https://openai.com/api). Initialize with api key

```swift
let api = ChatGPTAPI(apiKey: "API_KEY")
```

optionally, you can provide the system prompt, temperature, and model like so.
```swift
public init(apiKey: String,
        model: String = "gpt-4",
        systemPrompt: String = "You are a helpful assistant",
        temperature: Double = 0.5)
```

To learn more about those parameters, you can visit the official [ChatGPT API documentation](https://platform.openai.com/docs/guides/chat/introduction) and [ChatGPT API Introduction Page](https://openai.com/blog/introducing-chatgpt-and-whisper-apis)

## Usage

There are 2 APIs: stream and normal

### Stream

The server will stream chunks of data until complete, the method `AsyncThrowingStream` which you can loop using For-Loop like so:

```swift
Task {
    do {
        let stream = try await api.sendMessageStream(text: "What is ChatGPT?")
        for try await line in stream {
            print(line)
        }
    } catch {
        print(error.localizedDescription)
    }
}
```

### Normal
A normal HTTP request and response lifecycle. Server will send the complete text (it will take more time to response)

```swift
Task {
    do {
        let response = try await api.sendMessage(text: "What is ChatGPT?")
        print(response)
    } catch {
        print(error.localizedDescription)
    }
}
        
```

## History List

The client stores the history list of the conversation that will be included in the new prompt so ChatGPT aware of the previous context of conversation. When sending new prompt, the client will make sure the token is not exceeding 4000 (using calculation of 1 token=4chars), in case it exceeded the token, some of previous conversations will be truncated

You can also delete the history list by invoking
```swift
api.deleteHistoryList()
```

You should not call this, while waiting for the response from ChatGPT. I'll need to handle this properly in later release/


## Demo Apps
You can check the demo apps for iOS and macOS from the [SwiftUIChatGPT repo](https://github.com/alfianlosari/ChatGPTSwiftUI)
