import ChatGPTSwift
import Foundation

let api = ChatGPTAPI(apiKey: "apikey")
let prompt = "what is openai?"
Task {
    do {
        let stream = try await api.sendMessageStream(text: prompt)
        var responseText = ""
        for try await line in stream {
            responseText += line
            print(line)
        }
        api.appendToHistoryList(userText: prompt, responseText: responseText)
        print(responseText)
        exit(0)
    } catch {
        print(error.localizedDescription)
    }
}


RunLoop.main.run(until: .distantFuture)