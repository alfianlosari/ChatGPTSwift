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
  pod 'ChatGPTSwift', '~> 1.2.3'
end
```

## Requirement

Register for API key from [OpenAI](https://openai.com/api). Initialize with api key

```swift
let api = ChatGPTAPI(apiKey: "API_KEY")
```

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

### Providing extra parameters

Optionally, you can provide the model, system prompt, temperature, and model like so.

```swift
let response = try await api.sendMessage(text: "What is ChatGPT?",
                                         model: "gpt-4",
                                         systemPrompt: "You are a CS Professor",
                                         temperature: 0.5)
```

Default values for these parameters are:
- model: `gpt-3.5-turbo`
- systemPrompt: `You're a helpful assistant`
- temperature: `0.5`

To learn more about those parameters, you can visit the official [ChatGPT API documentation](https://platform.openai.com/docs/guides/chat/introduction) and [ChatGPT API Introduction Page](https://openai.com/blog/introducing-chatgpt-and-whisper-apis)

## History List

The client stores the history list of the conversation that will be included in the new prompt so ChatGPT aware of the previous context of conversation. When sending new prompt, the client will make sure the token count is not exceeding 4096 using [GPTEncoder library](https://github.com/alfianlosari/GPTEncoder) to calculate tokens in string, in case it exceeded the token, some of previous conversations will be truncated. In future i will provide an API to specify the token threshold as new gpt-4 model accept much bigger 8k tokens in a prompt.


### View Current History List

You can view current history list from the `historyList` property.

```swift
print(api.historyList)
```

### Delete History List

You can also delete the history list by invoking

```swift
api.deleteHistoryList()
```

### Replace History List

You can provide your own History List, this will replace the stored history list. Remember not to pass the 4096 tokens threshold.

```swift
let myHistoryList = [
    Message(role: "user", content: "who is james bond?")
    Message(role: "assistant", content: "secret british agent with codename 007"),
    Message(role: "user", content: "which one is the latest movie?"),
    Message(role: "assistant", content: "It's No Time to Die played by Daniel Craig")
]

api.replaceHistoryList(with: myHistoryList)
```

## Demo Apps
You can check the demo apps for iOS and macOS from the [SwiftUIChatGPT repo](https://github.com/alfianlosari/ChatGPTSwiftUI)
