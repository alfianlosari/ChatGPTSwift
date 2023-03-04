//
//  ChatGPTAPI.swift
//  XCAChatGPT
//
//  Created by Alfian Losari on 01/02/23.
//

import Foundation

#if os(Linux)
    import AsyncHTTPClient
    import FoundationNetworking
    import NIOFoundationCompat
#endif

public class ChatGPTAPI: @unchecked Sendable {
    
    private let systemMessage: Message
    private let temperature: Double
    private let model: String
    
    private let urlString = "https://api.openai.com/v1/chat/completions"
    private let apiKey: String
    private var historyList = [Message]()

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
    
    public init(apiKey: String,
         model: String = "gpt-3.5-turbo",
         systemPrompt: String = "You are a helpful assistant",
         temperature: Double = 0.5) {
        self.apiKey = apiKey
        self.model = model
        self.systemMessage = .init(role: "system", content: systemPrompt)
        self.temperature = temperature
    }
    
    private func generateMessages(from text: String) -> [Message] {
        var messages = [systemMessage] + historyList + [Message(role: "user", content: text)]
        if messages.contentCount > (4000 * 4) {
            _ = historyList.dropFirst()
            messages = generateMessages(from: text)
        }
        return messages
    }
    
    private func jsonBody(text: String, stream: Bool = true) throws -> Data {
        let request = Request(model: model,
                        temperature: temperature,
                        messages: generateMessages(from: text),
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

    public func sendMessage(text: String) async throws -> String {
        var request = self.clientRequest
        request.body = .bytes(try jsonBody(text: text, stream: false))
        
        let response = try await httpClient.execute(request, timeout: .seconds(25))
        let byteBuffers = response.body.map { Data(buffer: $0)}

        var data = Data()
        for try await chunk in byteBuffers {
            data.append(chunk)            
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

    #else
    private let urlSession = URLSession.shared
    private var urlRequest: URLRequest {
        let url = URL(string: urlString)!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        headers.forEach {  urlRequest.setValue($1, forHTTPHeaderField: $0) }
        return urlRequest
    }

    public func sendMessageStream(text: String) async throws -> AsyncThrowingStream<String, Error> {
        var urlRequest = self.urlRequest
        urlRequest.httpBody = try jsonBody(text: text)
        let (result, response) = try await urlSession.bytes(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw "Invalid response"
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            var errorText = ""
            for try await line in result.lines {
               errorText += line
            }
            if let data = errorText.data(using: .utf8), let errorResponse = try? jsonDecoder.decode(ErrorRootResponse.self, from: data).error {
                errorText = "\n\(errorResponse.message)"
            }
            throw "Bad Response: \(httpResponse.statusCode). \(errorText)"
        }
        
        return AsyncThrowingStream<String, Error> {  continuation in
            Task(priority: .userInitiated) { [weak self] in
                do {
                    var responseText = ""
                    for try await line in result.lines {
                        if line.hasPrefix("data: "),
                           let data = line.dropFirst(6).data(using: .utf8),
                           let response = try? self?.jsonDecoder.decode(StreamCompletionResponse.self, from: data),
                           let text = response.choices.first?.delta.content {
                            responseText += text
                            continuation.yield(text)
                        }
                    }
                    self?.appendToHistoryList(userText: text, responseText: responseText)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func sendMessage(text: String) async throws -> String {
        var urlRequest = self.urlRequest
        urlRequest.httpBody = try jsonBody(text: text, stream: false)
        
        let (data, response) = try await urlSession.data(for: urlRequest)
        
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
}

