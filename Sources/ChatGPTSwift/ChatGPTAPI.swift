//
//  ChatGPTAPI.swift
//  XCAChatGPT
//
//  Created by Alfian Losari on 01/02/23.
//

import Foundation
import GPTEncoder
import OpenAPIRuntime
#if os(Linux)
import OpenAPIAsyncHTTPClient
#else
import OpenAPIURLSession
#endif

public class ChatGPTAPI: @unchecked Sendable {
    
    public enum Constants {
        public static let defaultSystemText = "You're a helpful assistant"
        public static let defaultTemperature = 0.5
    }

    public let client: Client
    private let urlString = "https://api.openai.com/v1"
    private let gptEncoder = GPTEncoder()
    public private(set) var historyList = [Message]()

    let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "YYYY-MM-dd"
        return df
    }()

    private func systemMessage(content: String) -> Message {
        .init(role: "system", content: content)
    }
    
    public init(apiKey: String) {
        let clientTransport: ClientTransport
        #if os(Linux)
        clientTransport = AsyncHTTPClientTransport()
        #else
        clientTransport = URLSessionTransport()
        #endif

        self.client = Client(serverURL: URL(string: self.urlString)!,
            transport: clientTransport,
            middlewares: [AuthMiddleware(apiKey: apiKey)])
    }
    
    private func generateMessages(from text: String, systemText: String) -> [Message] {
        var messages = [systemMessage(content: systemText)] + historyList + [Message(role: "user", content: text)]
        if gptEncoder.encode(text: messages.content).count > 4096  {
            _ = historyList.removeFirst()
            messages = generateMessages(from: text, systemText: systemText)
        }
        return messages
    }

    private func generateInternalMessages(from text: String, systemText: String) -> [Components.Schemas.ChatCompletionRequestMessage] {
        let messages = self.generateMessages(from: text, systemText: systemText)
        return messages.map {
            $0.role == "user" ? .ChatCompletionRequestUserMessage(.init(content: .case1($0.content), role: .user)) : .ChatCompletionRequestSystemMessage(.init(content: $0.content, role: .system))
        }
    }

    private func jsonBody(text: String, model: String, systemText: String, temperature: Double, stream: Bool = true) throws -> Data {
        let request = Request(model: model,
                        temperature: temperature,
                        messages: generateMessages(from: text, systemText: systemText),
                        stream: stream)
        return try JSONEncoder().encode(request)
    }
    
    public func appendToHistoryList(userText: String, responseText: String) {
        self.historyList.append(Message(role: "user", content: userText))
        self.historyList.append(Message(role: "assistant", content: responseText))
    }
    
    public func sendMessageStream(text: String,
                                  model: Components.Schemas.CreateChatCompletionRequest.modelPayload.Value2Payload = .gpt_hyphen_4,
                                  systemText: String = ChatGPTAPI.Constants.defaultSystemText,
                                  temperature: Double = ChatGPTAPI.Constants.defaultTemperature) async throws -> AsyncMapSequence<AsyncThrowingPrefixWhileSequence<AsyncThrowingMapSequence<ServerSentEventsDeserializationSequence<ServerSentEventsLineDeserializationSequence<HTTPBody>>, ServerSentEventWithJSONData<Components.Schemas.CreateChatCompletionStreamResponse>>>, String> {
        let response = try await client.createChatCompletion(.init(headers: .init(accept: [.init(contentType: .text_event_hyphen_stream)]), body: .json(.init(
            messages: self.generateInternalMessages(from: text, systemText: systemText),
            model: .init(value1: nil, value2: model),
            stream: true))))

        let stream = try response.ok.body.text_event_hyphen_stream.asDecodedServerSentEventsWithJSONData(
            of: Components.Schemas.CreateChatCompletionStreamResponse.self
        )
        .prefix { chunk in
            if let choice = chunk.data?.choices.first {
                return choice.finish_reason != .stop
            } else {
                throw "Invalid data"
            }
        }
        .map{ $0.data?.choices.first?.delta.content ?? "" }
        return stream
    }

    public func sendMessage(text: String,
                            model: Components.Schemas.CreateChatCompletionRequest.modelPayload.Value2Payload = .gpt_hyphen_4,
                            systemText: String = ChatGPTAPI.Constants.defaultSystemText,
                            temperature: Double = ChatGPTAPI.Constants.defaultTemperature) async throws -> String {

        let response = try await client.createChatCompletion(body: .json(.init(
            messages: self.generateInternalMessages(from: text, systemText: systemText),
            model: .init(value1: nil, value2: model))))
    
        switch response {
        case .ok(let body):
            let json = try body.body.json
            guard let content = json.choices.first?.message.content else {
                throw "No Response"
            }
            self.appendToHistoryList(userText: text, responseText: content)
            return content
        case .undocumented(let statusCode, let payload):
            throw "OpenAIClientError - statuscode: \(statusCode), \(payload)"
        }
    }
    
    
    public func deleteHistoryList() {
        self.historyList.removeAll()
    }
    
    public func replaceHistoryList(with messages: [Message]) {
        self.historyList = messages
    }
    
}
