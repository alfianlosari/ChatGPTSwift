# ChatGPTSwift

Access ChatGPT "Official" API from Swift

## Supported Platforms

- iOS/tvOS 15 and above
- macOS 12 and above
- watchOS 8 and above

## Requirement

Register for API key from [OpenAPI](https://openai.com/api). Initialize with api key

```swift
let api = ChatGPTAPI(apiKey: "API_KEY")
```

## Usage

There are 2 APIs: stream and normal

### Stream

The server will stream data one by one until complete,, the method `AsyncThrowingStream` which you can loop using For-Loop like so:

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