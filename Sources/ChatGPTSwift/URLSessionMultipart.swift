////
////  File.swift
////
////
////  Created by Alfian Losari on 21/11/23.
////
//
import Foundation

#if os(iOS) || os(macOS) || os(watchOS) || os(tvOS) || os(visionOS)
/// Original source code: https://github.com/MacPaw/OpenAI
///
enum MultipartFormDataEntry {
    
    case file(paramName: String, fileName: String?, fileData: Data?, contentType: String),
         string(paramName: String, value: Any?)
}


final class MultipartFormDataBodyBuilder {
        
    let boundary: String
    let entries: [MultipartFormDataEntry]
    
    init(boundary: String, entries: [MultipartFormDataEntry]) {
        self.boundary = boundary
        self.entries = entries
    }
    
    func build() -> Data {
        var httpData = entries
            .map { $0.makeBodyData(boundary: boundary) }
            .reduce(Data(), +)
        httpData.append("--\(boundary)--\r\n")
        return httpData
    }
}

extension MultipartFormDataEntry {
    
    func makeBodyData(boundary: String) -> Data {
        var body = Data()
        switch self {
        case .file(let paramName, let fileName, let fileData, let contentType):
            if let fileName, let fileData {
                body.append("--\(boundary)\r\n")
                body.append("Content-Disposition: form-data; name=\"\(paramName)\"; filename=\"\(fileName)\"\r\n")
                body.append("Content-Type: \(contentType)\r\n\r\n")
                body.append(fileData)
                body.append("\r\n")
            }
        case .string(let paramName, let value):
            if let value {
                body.append("--\(boundary)\r\n")
                body.append("Content-Disposition: form-data; name=\"\(paramName)\"\r\n\r\n")
                body.append("\(value)\r\n")
            }
        }
        return body
    }
}

extension Data {
    
    mutating func append(_ string: String) {
        let data = string.data(
            using: String.Encoding.utf8,
            allowLossyConversion: true)
        append(data!)
    }
}

#endif
