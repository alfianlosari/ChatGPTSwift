# ChatGPTSwift API

![Alt text](https://imagizer.imageshack.com/v2/640x480q90/923/c9MPBA.png "image")

Access ChatGPT "Official" API from Swift. Works on all Apple platforms.

## DISCLAIMERS!
This repository is updated frequently. Expect breaking changes. Always read readme before updating or opening an issue.

Use this at your own risk, there is a possibility that OpenAI might ban your account using this approach! I don't take any responsibility.

## UPDATE - 8 Feb 2023

The leaked model had been removed by OpenAI. Until a new model is found, i'll use the default text-davinci-003

## Supported Platforms

- iOS/tvOS 15 and above
- macOS 12 and above
- watchOS 8 and above

## Installation

Swift Package Manager
- File > Swift Packages > Add Package Dependency
- Add https://github.com/alfianlosari/ChatGPTSwift.git

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

## Demo Apps
You can check the demo apps for iOS and macOS from the [SwiftUIChatGPT repo](https://github.com/alfianlosari/ChatGPTSwiftUI)
