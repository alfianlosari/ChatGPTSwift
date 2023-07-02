//
//  ChatGPTAPI.swift
//  XCAChatGPT
//
//  Created by Alfian Losari on 01/02/23.
//

import Foundation
import GPTEncoder

#if os(Linux)
    import AsyncHTTPClient
    import FoundationNetworking
    import NIOFoundationCompat
#endif

public class ChatGPTAPI: @unchecked Sendable {
    
    public enum Constants {
        public static let defaultModel = "gpt-3.5-turbo"
        public static let defaultSystemText = "You're a helpful assistant"
        public static let defaultTemperature = 0.5
    }
    
    private let urlString = "https://api.openai.com/v1/chat/completions"
    private let apiKey: String
    private let gptEncoder = GPTEncoder()
    public private(set) var historyList = [Message]()

    let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "YYYY-MM-dd"
        return df
    }()
    
    private let jsonDecoder: JSONDecoder = {
        let jsonDecoder = JSONDecoder()
        jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
        return jsonDecoder
    }()
    
    private var headers: [String: String] {
        [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(apiKey)"
        ]
    }
    
    private func systemMessage(content: String) -> Message {
        .init(role: "system", content: content)
    }
    
    public init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    private func generateMessages(from text: String, systemText: String) -> [Message] {
        var messages = [systemMessage(content: systemText)] + historyList + [Message(role: "user", content: text)]
        if gptEncoder.encode(text: messages.content).count > 4096  {
            _ = historyList.removeFirst()
            messages = generateMessages(from: text, systemText: systemText)
        }
        return messages
    }
    
    private func jsonBody(
        text: String,
        model: String = ChatGPTAPI.Constants.defaultModel,
        systemText: String = ChatGPTAPI.Constants.defaultSystemText,
        temperature: Double = ChatGPTAPI.Constants.defaultTemperature,
        stream: Bool = true) throws -> Data {
        let request = Request(model: model,
                        temperature: temperature,
                        messages: generateMessages(from: text, systemText: systemText),
                        stream: stream)
        return try JSONEncoder().encode(request)
    }
    
    private func appendToHistoryList(userText: String, responseText: String) {
        self.historyList.append(Message(role: "user", content: userText))
        self.historyList.append(Message(role: "assistant", content: responseText))
    }
    
    #if os(Linux)
    private let httpClient = HTTPClient(eventLoopGroupProvider: .createNew)
    private var clientRequest: HTTPClientRequest {
        var request = HTTPClientRequest(url: urlString)
        request.method = .POST
        headers.forEach {
            request.headers.add(name: $0.key, value: $0.value)
        }
        return request
    }

    public func sendMessageStream(text: String) async throws -> AsyncThrowingStream<String, Error> {
         var request = self.clientRequest
        request.body = .bytes(try jsonBody(text: text, stream: true))
        
        let response = try await httpClient.execute(request, timeout: .seconds(25))
        try Task.checkCancellation()

        guard response.status == .ok else {
            var data = Data()
            for try await buffer in response.body {
                try Task.checkCancellation()
                data.append(.init(buffer: buffer))
            }
            var error = "Bad Response: \(response.status.code)"
            if data.count > 0, let errorResponse = try? jsonDecoder.decode(ErrorRootResponse.self, from: data).error {
                error.append("\n\(errorResponse.message)")
            }
            throw error
        }
        
        var responseText = ""
        return AsyncThrowingStream { [weak self] in
            guard let self else { return nil }
            for try await buffer in response.body {
                try Task.checkCancellation()
                let line = String(buffer: buffer)
                if line.hasPrefix("data: "),
                   let data = line.dropFirst(6).data(using: .utf8),
                   let response = try? self.jsonDecoder.decode(StreamCompletionResponse.self, from: data),
                   let text = response.choices.first?.delta.content {
                    responseText += text
                    return text
                }
            }
            self.appendToHistoryList(userText: text, responseText: responseText)
            return nil
        }
    }

    public func sendMessage(text: String,
                            model: String = ChatGPTAPI.Constants.defaultModel,
                            systemText: String = ChatGPTAPI.Constants.defaultSystemText,
                            temperature: Double = ChatGPTAPI.Constants.defaultTemperature) async throws -> String {
        var request = self.clientRequest
        request.body = .bytes(try jsonBody(text: text, model: model, systemText: systemText, temperature: temperature, stream: false))
        
        let response = try await httpClient.execute(request, timeout: .seconds(25))
        try Task.checkCancellation()
        var data = Data()
        for try await buffer in response.body {
            try Task.checkCancellation()
            data.append(.init(buffer: buffer))
        }

        guard response.status == .ok else {
            var error = "Bad Response: \(response.status.code)"
            if data.count > 0, let errorResponse = try? jsonDecoder.decode(ErrorRootResponse.self, from: data).error {
                error.append("\n\(errorResponse.message)")
            }
            throw error
        }
        
        do {
            let completionResponse = try self.jsonDecoder.decode(CompletionResponse.self, from: data)
            let responseText = completionResponse.choices.first?.message.content ?? ""
            self.appendToHistoryList(userText: text, responseText: responseText)
            return responseText
        } catch {
            throw error
        }
        
    }

    deinit {
        let client = self.httpClient
        Task.detached { try await client.shutdown() }
        
    }
    #else

    private let urlSession = URLSession.shared
    private var urlRequest: URLRequest {
        let url = URL(string: urlString)!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        headers.forEach {  urlRequest.setValue($1, forHTTPHeaderField: $0) }
        return urlRequest
    }

    public func sendMessageStream(text: String,
                                  model: String = ChatGPTAPI.Constants.defaultModel,
                                  systemText: String = ChatGPTAPI.Constants.defaultSystemText,
                                  temperature: Double = ChatGPTAPI.Constants.defaultTemperature) async throws -> AsyncThrowingStream<String, Error> {
        var urlRequest = self.urlRequest
        urlRequest.httpBody = try jsonBody(text: text, model: model, systemText: systemText, temperature: temperature)
        let (result, response) = try await urlSession.bytes(for: urlRequest)
        try Task.checkCancellation()
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw "Invalid response"
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            var errorText = ""
            for try await line in result.lines {
                try Task.checkCancellation()
                errorText += line
            }
            if let data = errorText.data(using: .utf8), let errorResponse = try? jsonDecoder.decode(ErrorRootResponse.self, from: data).error {
                errorText = "\n\(errorResponse.message)"
            }
            throw "Bad Response: \(httpResponse.statusCode). \(errorText)"
        }
        
        
        var responseText = ""
        return AsyncThrowingStream { [weak self] in
            guard let self else { return nil }
            for try await line in result.lines {
                try Task.checkCancellation()
                if line.hasPrefix("data: "),
                   let data = line.dropFirst(6).data(using: .utf8),
                   let response = try? self.jsonDecoder.decode(StreamCompletionResponse.self, from: data),
                   let text = response.choices.first?.delta.content {
                    responseText += text
                    return text
                }
            }
            self.appendToHistoryList(userText: text, responseText: responseText)
            return nil
        }
    }

    public func sendMessage(text: String,
                            model: String = ChatGPTAPI.Constants.defaultModel,
                            systemText: String = ChatGPTAPI.Constants.defaultSystemText,
                            temperature: Double = ChatGPTAPI.Constants.defaultTemperature) async throws -> String {
        var urlRequest = self.urlRequest
        urlRequest.httpBody = try jsonBody(text: text, model: model, systemText: systemText, temperature: temperature, stream: false)
        
        let (data, response) = try await urlSession.data(for: urlRequest)
        try Task.checkCancellation()
        guard let httpResponse = response as? HTTPURLResponse else {
            throw "Invalid response"
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            var error = "Bad Response: \(httpResponse.statusCode)"
            if let errorResponse = try? jsonDecoder.decode(ErrorRootResponse.self, from: data).error {
                error.append("\n\(errorResponse.message)")
            }
            throw error
        }
        
        do {
            let completionResponse = try self.jsonDecoder.decode(CompletionResponse.self, from: data)
            let responseText = completionResponse.choices.first?.message.content ?? ""
            self.appendToHistoryList(userText: text, responseText: responseText)
            return responseText
        } catch {
            throw error
        }
    }
    #endif
    
    public func deleteHistoryList() {
        self.historyList.removeAll()
    }
    
    public func replaceHistoryList(with messages: [Message]) {
        self.historyList = messages
    }
    
}

