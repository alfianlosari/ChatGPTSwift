import Foundation
#if os(Linux)
import FoundationNetworking
class URLSessionDelegateStream<T: Decodable>: NSObject, URLSessionDataDelegate {
    var receivedData = Data()
    var continuation: AsyncThrowingStream<String, any Error>.Continuation?
    let jsonDecoder: JSONDecoder

    init(jsonDecoder: JSONDecoder, continuation:  AsyncThrowingStream<String, any Error>.Continuation?) {
        self.jsonDecoder = jsonDecoder
        self.continuation = continuation
        super.init()
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let continuation else { return }
        receivedData.append(data)
        if let line = String(data: receivedData, encoding: .utf8) {
			let datas = line.split(separator: "\n")
			for line in datas {
				if line.hasPrefix("data: [DONE]") {
					continue
				}
				
				if line.hasPrefix("data: ") {
					let jsonText = String(line.dropFirst(6))
					let data: Data
					do {
						data = try jsonData(jsonText: jsonText)
					} catch {
						print("Failed to convert string to json data \(error)")
						return
					}
					do {
						let response = try self.jsonDecoder.decode(StreamCompletionResponse.self, from: data)
						let text = response.choices.first?.delta.content ?? ""
						continuation.yield(text)
						receivedData = Data()
					} catch {
						print("Failed to convert jsonDta to response \(error)")
						return
					}
				}
			}
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let continuation else { return }
        guard let response = task.response as? HTTPURLResponse else {
            return
        }
        if response.statusCode == 200 {
            continuation.finish(throwing: nil)
        } else {
            if let error = error {
                continuation.finish(throwing: error)
            } else {
                continuation.finish(throwing: NSError(
                domain: "com.xca.generative-ai",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Response status code: \(response.statusCode)."]
                ))
            }
        }
    }

    private func jsonData(jsonText: String) throws -> Data {
        guard let data = jsonText.data(using: .utf8) else {
        let error = NSError(
            domain: "com.xca.generative-ai",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Could not parse response as UTF8."]
        )
        throw error
        }

        return data
    }

}
#endif

class URLSessionDelegateStreamChunk<T: Decodable>: NSObject, URLSessionDataDelegate {
    var receivedData = Data()
    var callback: (Result<StreamChunk, Error>) -> Void
    let jsonDecoder: JSONDecoder

    init(jsonDecoder: JSONDecoder, callback:  @escaping (Result<StreamChunk, Error>) -> Void) {
        self.jsonDecoder = jsonDecoder
        self.callback = callback
        super.init()
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        receivedData.append(data)
        if let line = String(data: receivedData, encoding: .utf8) {
            let datas = line.split(separator: "\n")
            for line in datas {
                if line.hasPrefix("data: [DONE]") {
                    continue
                }
                
                if line.hasPrefix("data: ") {
                    let jsonText = String(line.dropFirst(6))
                    let data: Data
                    do {
                        data = try jsonData(jsonText: jsonText)
                    } catch {
                        print("Failed to convert string to json data \(error)")
                        return
                    }
                    do {
                        let response = try self.jsonDecoder.decode(StreamCompletionResponse.self, from: data)
                        let text = response.choices.first?.delta.content ?? ""
                        callback(.success(.init(text: text, isFinished: false)))
                        receivedData = Data()
                    } catch {
                        print("Failed to convert jsonDta to response \(error)")
                        return
                    }
                }
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let response = task.response as? HTTPURLResponse else {
            return
        }
        if response.statusCode == 200 {
            callback(.success(.init(text: "", isFinished: true)))
        } else {
            if let error = error {
                callback(.failure(error))
            } else {
                callback(.failure(NSError(
                    domain: "com.xca.generative-ai",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Response status code: \(response.statusCode)."]
                    )))
            }
        }
    }

    private func jsonData(jsonText: String) throws -> Data {
        guard let data = jsonText.data(using: .utf8) else {
        let error = NSError(
            domain: "com.xca.generative-ai",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Could not parse response as UTF8."]
        )
        throw error
        }

        return data
    }

}
