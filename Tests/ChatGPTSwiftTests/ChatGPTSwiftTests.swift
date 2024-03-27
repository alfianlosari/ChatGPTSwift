import XCTest
@testable import ChatGPTSwift

final class ChatGPTSwiftTests: XCTestCase {
    func testSendMesssage() async throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        
        let api = ChatGPTAPI(apiKey: "API_KEY")
        
        let task = Task {
            do {
                let response = try await api.sendMessage(text: "What is ChatGPT?", model: "gpt-4", stop: "developed", temperature: 0.0)
                print(response)
            } catch {
                print(error.localizedDescription)
            }
        }
        await task.value
    }
}
