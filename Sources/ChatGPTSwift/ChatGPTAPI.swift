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

public typealias ChatCompletionTool = Components.Schemas.ChatCompletionTool
public typealias ChatCompletionResponseMessage = Components.Schemas.ChatCompletionResponseMessage
public typealias ChatGPTModel = Components.Schemas.CreateChatCompletionRequest.modelPayload
    .Value2Payload
typealias ModelPayload = Components.Schemas.CreateChatCompletionRequest.modelPayload

public class ChatGPTAPI: @unchecked Sendable {

    public enum Constants {
        public static let defaultSystemText = "You're a helpful assistant"
        public static let defaultTemperature = 0.5
    }

    public private(set) var client: Client
    private let urlString = "https://api.openai.com/v1"
    private let gptEncoder = GPTEncoder()
    public private(set) var historyList = [Message]()
    private var apiKey: String

    let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "YYYY-MM-dd"
        return df
    }()

    private func systemMessage(content: String) -> Message {
        .init(role: "system", content: content)
    }

    public init(apiKey: String) {
        self.apiKey = apiKey
        let clientTransport: ClientTransport
        #if os(Linux)
            clientTransport = AsyncHTTPClientTransport()
        #else
            clientTransport = URLSessionTransport()
        #endif
        self.client = Client(
            serverURL: URL(string: self.urlString)!,
            transport: clientTransport,
            middlewares: [AuthMiddleware(apiKey: apiKey)])
    }

    public func updateAPIKey(_ apiKey: String) {
        self.apiKey = apiKey
        let clientTransport: ClientTransport
        #if os(Linux)
            clientTransport = AsyncHTTPClientTransport()
        #else
            clientTransport = URLSessionTransport()
        #endif
        self.client = Client(
            serverURL: URL(string: self.urlString)!,
            transport: clientTransport,
            middlewares: [AuthMiddleware(apiKey: apiKey)])
    }

    private func generateMessages(from text: String, systemText: String) -> [Message] {
        var messages =
            [systemMessage(content: systemText)] + historyList + [
                Message(role: "user", content: text)
            ]
        if gptEncoder.encode(text: messages.content).count > 4096 {
            _ = historyList.removeFirst()
            messages = generateMessages(from: text, systemText: systemText)
        }
        return messages
    }

    private func generateInternalMessages(from text: String, systemText: String) -> [Components
        .Schemas.ChatCompletionRequestMessage]
    {
        let messages = self.generateMessages(from: text, systemText: systemText)
        return messages.map {
            $0.role == "user"
                ? .ChatCompletionRequestUserMessage(.init(content: .case1($0.content), role: .user))
                : .ChatCompletionRequestSystemMessage(.init(content: $0.content, role: .system))
        }
    }

    private func jsonBody(
        text: String, model: String, systemText: String, temperature: Double, stream: Bool = true
    ) throws -> Data {
        let request = Request(
            model: model,
            temperature: temperature,
            messages: generateMessages(from: text, systemText: systemText),
            stream: stream)
        return try JSONEncoder().encode(request)
    }

    public func appendToHistoryList(userText: String, responseText: String) {
        self.historyList.append(Message(role: "user", content: userText))
        self.historyList.append(Message(role: "assistant", content: responseText))
    }
    
    public func sendMessageStream(
        text: String,
        model: String,
        systemText: String = ChatGPTAPI.Constants.defaultSystemText,
        temperature: Double = ChatGPTAPI.Constants.defaultTemperature,
        maxTokens: Int? = nil,
        responseFormat: Components.Schemas.CreateChatCompletionRequest.response_formatPayload? =
            nil,
        stop: Components.Schemas.CreateChatCompletionRequest.stopPayload? = nil,
        imageData: Data? = nil
    ) async throws -> AsyncMapSequence<
        AsyncThrowingPrefixWhileSequence<
            AsyncThrowingMapSequence<
                ServerSentEventsDeserializationSequence<
                    ServerSentEventsLineDeserializationSequence<HTTPBody>
                >,
                ServerSentEventWithJSONData<Components.Schemas.CreateChatCompletionStreamResponse>
            >
        >, String
    > {
        try await sendMessageStreamInternal(text: text, model: .init(value1: model, value2: nil), systemText: systemText, temperature: temperature, maxTokens: maxTokens, responseFormat: responseFormat, stop: stop, imageData: imageData)
    }
    
    public func sendMessageStream(
        text: String,
        model: ChatGPTModel = .gpt_hyphen_4_period_1,
        systemText: String = ChatGPTAPI.Constants.defaultSystemText,
        temperature: Double = ChatGPTAPI.Constants.defaultTemperature,
        maxTokens: Int? = nil,
        responseFormat: Components.Schemas.CreateChatCompletionRequest.response_formatPayload? =
            nil,
        stop: Components.Schemas.CreateChatCompletionRequest.stopPayload? = nil,
        imageData: Data? = nil
    ) async throws -> AsyncMapSequence<
        AsyncThrowingPrefixWhileSequence<
            AsyncThrowingMapSequence<
                ServerSentEventsDeserializationSequence<
                    ServerSentEventsLineDeserializationSequence<HTTPBody>
                >,
                ServerSentEventWithJSONData<Components.Schemas.CreateChatCompletionStreamResponse>
            >
        >, String
    > {
        try await sendMessageStreamInternal(text: text, model: .init(value1: nil, value2: model), systemText: systemText, temperature: temperature, maxTokens: maxTokens, responseFormat: responseFormat, stop: stop, imageData: imageData)
    }

    private func sendMessageStreamInternal(
        text: String,
        model: ModelPayload,
        systemText: String = ChatGPTAPI.Constants.defaultSystemText,
        temperature: Double = ChatGPTAPI.Constants.defaultTemperature,
        maxTokens: Int? = nil,
        responseFormat: Components.Schemas.CreateChatCompletionRequest.response_formatPayload? =
            nil,
        stop: Components.Schemas.CreateChatCompletionRequest.stopPayload? = nil,
        imageData: Data? = nil
    ) async throws -> AsyncMapSequence<
        AsyncThrowingPrefixWhileSequence<
            AsyncThrowingMapSequence<
                ServerSentEventsDeserializationSequence<
                    ServerSentEventsLineDeserializationSequence<HTTPBody>
                >,
                ServerSentEventWithJSONData<Components.Schemas.CreateChatCompletionStreamResponse>
            >
        >, String
    > {
        var messages = generateInternalMessages(from: text, systemText: systemText)
        if let imageData {
            messages.append(createMessage(imageData: imageData))
        }

        let response = try await client.createChatCompletion(
            .init(
                headers: .init(accept: [.init(contentType: .text_event_hyphen_stream)]),
                body: .json(
                    .init(
                        messages: messages,
                        model: model,
                        max_tokens: maxTokens,
                        response_format: responseFormat,
                        stop: stop,
                        stream: true))))

        do {
            let stream = try response.ok.body.text_event_hyphen_stream
                .asDecodedServerSentEventsWithJSONData(
                    of: Components.Schemas.CreateChatCompletionStreamResponse.self
                )
                .prefix { chunk in
                    if let choice = chunk.data?.choices.first {
                        return choice.finish_reason != .stop
                    } else {
                        throw "Invalid data"
                    }
                }
                .map { $0.data?.choices.first?.delta.content ?? "" }
            return stream
        } catch {
            let statusCode: Int
            let errorDesc = (error as CustomStringConvertible).description
            if errorDesc.contains("statusCode: 401") {
                statusCode = 401
            } else if errorDesc.contains("statusCode: 403") {
                statusCode = 403
            } else if errorDesc.contains("statusCode: 429") {
                statusCode = 429
            } else {
                statusCode = 500
            }
            throw getError(statusCode: statusCode, model: model.value1 ?? model.value2?.rawValue, payload: nil)
        }
    }
    
    
    public func sendMessage(
        text: String,
        model: String,
        systemText: String = ChatGPTAPI.Constants.defaultSystemText,
        temperature: Double = ChatGPTAPI.Constants.defaultTemperature,
        maxTokens: Int? = nil,
        responseFormat: Components.Schemas.CreateChatCompletionRequest.response_formatPayload? =
            nil,
        stop: Components.Schemas.CreateChatCompletionRequest.stopPayload? = nil,
        imageData: Data? = nil
    ) async throws -> String {
        try await sendMessageInternal(text: text, model: .init(value1: model, value2: nil), systemText: systemText, temperature: temperature, maxTokens: maxTokens, responseFormat: responseFormat, stop: stop, imageData: imageData)
    }
    
    public func sendMessage(
        text: String,
        model: ChatGPTModel = .gpt_hyphen_4_period_1,
        systemText: String = ChatGPTAPI.Constants.defaultSystemText,
        temperature: Double = ChatGPTAPI.Constants.defaultTemperature,
        maxTokens: Int? = nil,
        responseFormat: Components.Schemas.CreateChatCompletionRequest.response_formatPayload? =
            nil,
        stop: Components.Schemas.CreateChatCompletionRequest.stopPayload? = nil,
        imageData: Data? = nil
    ) async throws -> String {
        try await sendMessageInternal(text: text, model: .init(value1: nil, value2: model), systemText: systemText, temperature: temperature, maxTokens: maxTokens, responseFormat: responseFormat, stop: stop, imageData: imageData)
    }

    private func sendMessageInternal(
        text: String,
        model: ModelPayload,
        systemText: String = ChatGPTAPI.Constants.defaultSystemText,
        temperature: Double = ChatGPTAPI.Constants.defaultTemperature,
        maxTokens: Int? = nil,
        responseFormat: Components.Schemas.CreateChatCompletionRequest.response_formatPayload? =
            nil,
        stop: Components.Schemas.CreateChatCompletionRequest.stopPayload? = nil,
        imageData: Data? = nil
    ) async throws -> String {
        var messages = generateInternalMessages(from: text, systemText: systemText)
        if let imageData {
            messages.append(createMessage(imageData: imageData))
        }

        let response = try await client.createChatCompletion(
            body: .json(
                .init(
                    messages: messages,
                    model: model,
                    max_tokens: maxTokens,
                    response_format: responseFormat,
                    stop: stop
                )))

        switch response {
        case .ok(let body):
            let json = try body.body.json
            guard let content = json.choices.first?.message.content else {
                throw "No Response"
            }
            self.appendToHistoryList(userText: text, responseText: content)
            return content
        case .undocumented(let statusCode, let payload):
            throw getError(statusCode: statusCode, model: model.value1 ?? model.value2?.rawValue, payload: payload)
        }
    }
    
    public func callFunction(
        prompt: String,
        tools: [ChatCompletionTool],
        model: ChatGPTModel = .gpt_hyphen_4_period_1,
        maxTokens: Int? = nil,
        responseFormat: Components.Schemas.CreateChatCompletionRequest.response_formatPayload? =
            nil,
        stop: Components.Schemas.CreateChatCompletionRequest.stopPayload? = nil,
        systemText: String =
            "Don't make assumptions about what values to plug into functions. Ask for clarification if a user request is ambiguous.",
        imageData: Data? = nil
    ) async throws -> ChatCompletionResponseMessage {
        try await callFunctionInternal(prompt: prompt, tools: tools, model: .init(value1: nil, value2: model), maxTokens: maxTokens, responseFormat: responseFormat, stop: stop, systemText: systemText, imageData: imageData)
    }
    
    public func callFunction(
        prompt: String,
        tools: [ChatCompletionTool],
        model: String,
        maxTokens: Int? = nil,
        responseFormat: Components.Schemas.CreateChatCompletionRequest.response_formatPayload? =
            nil,
        stop: Components.Schemas.CreateChatCompletionRequest.stopPayload? = nil,
        systemText: String =
            "Don't make assumptions about what values to plug into functions. Ask for clarification if a user request is ambiguous.",
        imageData: Data? = nil
    ) async throws -> ChatCompletionResponseMessage {
        try await callFunctionInternal(prompt: prompt, tools: tools, model: .init(value1: model, value2: nil), maxTokens: maxTokens, responseFormat: responseFormat, stop: stop, systemText: systemText, imageData: imageData)
    }

    private func callFunctionInternal(
        prompt: String,
        tools: [ChatCompletionTool],
        model: ModelPayload,
        maxTokens: Int? = nil,
        responseFormat: Components.Schemas.CreateChatCompletionRequest.response_formatPayload? =
            nil,
        stop: Components.Schemas.CreateChatCompletionRequest.stopPayload? = nil,
        systemText: String =
            "Don't make assumptions about what values to plug into functions. Ask for clarification if a user request is ambiguous.",
        imageData: Data? = nil
    ) async throws -> ChatCompletionResponseMessage {
        var messages = generateInternalMessages(from: prompt, systemText: systemText)
        if let imageData {
            messages.append(createMessage(imageData: imageData))
        }

        let response = try await client.createChatCompletion(
            .init(
                body: .json(
                    .init(
                        messages: messages,
                        model: model,
                        max_tokens: maxTokens,
                        response_format: responseFormat,
                        stop: stop,
                        tools: tools,
                        tool_choice: .none))))

        switch response {
        case .ok(let body):
            let json = try body.body.json
            guard let message = json.choices.first?.message else {
                throw "No Response"
            }
            return message
        case .undocumented(let statusCode, let payload):
            throw getError(statusCode: statusCode, model: model.value1 ?? model.value2?.rawValue, payload: payload)
        }
    }
    
    
    public func generateSpeechFrom(
        input: String,
        model: String,
        voice: Components.Schemas.CreateSpeechRequest.voicePayload = .alloy,
        format: Components.Schemas.CreateSpeechRequest.response_formatPayload = .aac
    ) async throws -> Data {
        try await generateSpeechInternalFrom(input: input, model: .init(value1: model, value2: nil), voice: voice, format: format)
    }
    
    
    public func generateSpeechFrom(
        input: String,
        model: Components.Schemas.CreateSpeechRequest.modelPayload.Value2Payload = .tts_hyphen_1,
        voice: Components.Schemas.CreateSpeechRequest.voicePayload = .alloy,
        format: Components.Schemas.CreateSpeechRequest.response_formatPayload = .aac
    ) async throws -> Data {
        try await generateSpeechInternalFrom(input: input, model: .init(value1: nil, value2: model), voice: voice, format: format)
    }

    private func generateSpeechInternalFrom(
        input: String,
        model: Components.Schemas.CreateSpeechRequest.modelPayload,
        voice: Components.Schemas.CreateSpeechRequest.voicePayload = .alloy,
        format: Components.Schemas.CreateSpeechRequest.response_formatPayload = .aac
    ) async throws -> Data {
        let response = try await client.createSpeech(
            body: .json(
                .init(
                    model: model,
                    input: input,
                    voice: voice,
                    response_format: format
                )))

        switch response {
        case .ok(let response):
            switch response.body {
            case .any(let body):
                var data = Data()
                for try await byte in body {
                    data.append(contentsOf: byte)
                }
                return data
            }

        case .undocumented(let statusCode, let payload):
            throw getError(statusCode: statusCode, model: model.value1 ?? model.value2?.rawValue, payload: payload)
        }
    }

    public func deleteHistoryList() {
        self.historyList.removeAll()
    }

    public func replaceHistoryList(with messages: [Message]) {
        self.historyList = messages
    }

    #if os(iOS) || os(macOS) || os(watchOS) || os(tvOS) || os(visionOS)
        /// TODO: use swift-openapi-runtime MultipartFormBuilder
        public func generateAudioTransciptions(
            audioData: Data, fileName: String = "recording.m4a", model: String = "whisper-1",
            language: String = "en"
        ) async throws -> String {
            var request = URLRequest(
                url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
            let boundary: String = UUID().uuidString
            request.timeoutInterval = 30
            request.httpMethod = "POST"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue(
                "multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

            let bodyBuilder = MultipartFormDataBodyBuilder(
                boundary: boundary,
                entries: [
                    .file(
                        paramName: "file", fileName: fileName, fileData: audioData,
                        contentType: "audio/mpeg"),
                    .string(paramName: "model", value: model),
                    .string(paramName: "language", value: language),
                    .string(paramName: "response_format", value: "text"),
                ])
            request.httpBody = bodyBuilder.build()
            let (data, resp) = try await URLSession.shared.data(for: request)
            guard let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 else {
                let statusCode = (resp as? HTTPURLResponse)?.statusCode ?? 500
                throw getError(statusCode: statusCode, model: model, payload: nil)
            }
            guard let text = String(data: data, encoding: .utf8) else {
                throw "Invalid format"
            }

            return text
        }
    #endif

    public func generateDallE3Image(
        prompt: String,
        quality: Components.Schemas.CreateImageRequest.qualityPayload = .standard,
        responseFormat: Components.Schemas.CreateImageRequest.response_formatPayload = .url,
        style: Components.Schemas.CreateImageRequest.stylePayload = .vivid

    ) async throws -> Components.Schemas.Image {

        let response = try await client.createImage(
            .init(
                body: .json(
                    .init(
                        prompt: prompt,
                        model: .init(value1: nil, value2: .dall_hyphen_e_hyphen_3),
                        n: 1,
                        quality: quality,
                        response_format: responseFormat,
                        size: ._1024x1024,
                        style: style
                    ))))

        switch response {
        case .ok(let response):
            switch response.body {
            case .json(let imageResponse) where imageResponse.data.first != nil:
                return imageResponse.data.first!

            default:
                throw "Unknown response"
            }

        case .undocumented(let statusCode, let payload):
            throw getError(
                statusCode: statusCode,
                model: Components.Schemas.CreateImageRequest.modelPayload.Value2Payload
                    .dall_hyphen_e_hyphen_3.rawValue, payload: payload)
        }
    }

    func getError(statusCode: Int, model: String?, payload: UndocumentedPayload?) -> Error {
        var error = "\(statusCode) - "
        if statusCode == 401 {
            error +=
                "Invalid Authentication. Check your OpenAI API Key. Make sure it is correct with sufficient quota"
            if let model {
                error += " and are eligible to use \(model)."
            } else {
                error += "."
            }
        } else if statusCode == 403 {
            error +=
                "Country, region, or territory not supported. Check OpenAI website for supported countries."
        } else if statusCode == 429 {
            error +=
                " Rate limit reached for requests - You are sending requests too quickly or you exceeded your current quota, please check your plan and billing details."
        } else {
            error =
                "Status Code: \(statusCode). Check OpenAI Doc for status code error description."
            if let payload {
                error += " \(payload)"
            }
        }

        return error
    }

    func createMessage(imageData: Data) -> Components.Schemas.ChatCompletionRequestMessage {
        .ChatCompletionRequestUserMessage(
            .init(
                content: .case2([
                    .ChatCompletionRequestMessageContentPartImage(
                        .init(
                            _type: .image_url,
                            image_url:
                                .init(
                                    url:
                                        "data:image/jpeg;base64,\(imageData.base64EncodedString())",
                                    detail: .auto)))
                ]),
                role: .user))
    }

}
