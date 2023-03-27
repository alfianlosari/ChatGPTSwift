//
//  File.swift
//  
//
//  Created by Alfian Losari on 02/03/23.
//

import Foundation

public struct Message: Codable {
    public let role: String
    public let content: String
    
    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

extension Array where Element == Message {
    
    var contentCount: Int { map { $0.content }.count }
    var content: String { reduce("") { $0 + $1.content } }
}

struct Request: Codable {
    let model: String
    let temperature: Double
    let messages: [Message]
    let stream: Bool
}

struct ErrorRootResponse: Decodable {
    let error: ErrorResponse
}

struct ErrorResponse: Decodable {
    let message: String
    let type: String?
}

struct CompletionResponse: Decodable {
    let choices: [Choice]
    let usage: Usage?
}

struct Usage: Decodable {
    let promptTokens: Int?
    let completionTokens: Int?
    let totalTokens: Int?
}

struct Choice: Decodable {
    let finishReason: String?
    let message: Message
}

struct StreamCompletionResponse: Decodable {
    let choices: [StreamChoice]
}

struct StreamChoice: Decodable {
    let finishReason: String?
    let delta: StreamMessage
}

struct StreamMessage: Decodable {
    let content: String?
    let role: String?
}
