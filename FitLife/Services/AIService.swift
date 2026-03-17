import Foundation
import SwiftUI

// MARK: - AIProvider

enum AIProvider: String, CaseIterable, Identifiable {
    case gemini
    case claude
    case openai

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gemini: return "Gemini"
        case .claude: return "Claude"
        case .openai: return "ChatGPT"
        }
    }

    var apiKeyKey: String {
        switch self {
        case .gemini: return "gemini_api_key"
        case .claude: return "claude_api_key"
        case .openai: return "openai_api_key"
        }
    }
}

// MARK: - AIServiceProtocol

protocol AIServiceProtocol {
    func recognizeFood(imageData: Data) async throws -> FoodAnalysis
    func translateToChinese(texts: [String]) async throws -> [String]
}

// MARK: - AIServiceError

enum AIServiceError: LocalizedError {
    case apiKeyMissing
    case invalidImage
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)
    case noContent
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "API Key 未配置，请在设置中配置。"
        case .invalidImage:
            return "图片数据无效。"
        case .invalidURL:
            return "无法构建 API URL。"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .invalidResponse:
            return "服务器返回了无效响应。"
        case .httpError(let statusCode):
            return "服务器返回 HTTP \(statusCode)。"
        case .decodingError(let error):
            return "解析响应失败: \(error.localizedDescription)"
        case .noContent:
            return "API 未返回任何内容。"
        case .apiError(let message):
            return "API 错误: \(message)"
        }
    }
}

// MARK: - ClaudeService

class ClaudeService: AIServiceProtocol {
    static let shared = ClaudeService()

    private let session: URLSession
    private let model = "claude-sonnet-4-20250514"

    var apiKey: String? {
        get { UserDefaults.standard.string(forKey: "claude_api_key") }
        set { UserDefaults.standard.set(newValue, forKey: "claude_api_key") }
    }

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    func recognizeFood(imageData: Data) async throws -> FoodAnalysis {
        guard let apiKey, !apiKey.isEmpty else {
            throw AIServiceError.apiKeyMissing
        }

        let base64Image = imageData.base64EncodedString()
        if base64Image.isEmpty {
            throw AIServiceError.invalidImage
        }

        let prompt = """
        分析这张食物图片，返回JSON格式，包含foodName, calories, protein, carbs, fat, fiber, waterMl, suggestions字段。\
        其中calories/protein/carbs/fat/fiber单位为克(g)，waterMl单位为毫升(ml)。\
        suggestions为饮食建议。请只返回纯JSON，不要包含markdown标记。
        """

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ],
                        [
                            "type": "text",
                            "text": prompt
                        ]
                    ]
                ]
            ]
        ]

        let url = URL(string: "https://api.anthropic.com/v1/messages")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AIServiceError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorBody = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorBody["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw AIServiceError.apiError(message)
            }
            throw AIServiceError.httpError(statusCode: httpResponse.statusCode)
        }

        return try parseClaudeResponse(data: data)
    }

    func translateToChinese(texts: [String]) async throws -> [String] {
        guard let apiKey, !apiKey.isEmpty else {
            throw AIServiceError.apiKeyMissing
        }

        let numberedText = texts.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")

        let prompt = """
        将以下运动指导步骤翻译为中文，保持编号格式，每行一个步骤，只返回翻译结果，不要额外说明：
        \(numberedText)
        """

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]

        let url = URL(string: "https://api.anthropic.com/v1/messages")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AIServiceError.invalidResponse
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else {
            throw AIServiceError.noContent
        }

        let lines = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n")
            .map { line in
                var cleaned = line.trimmingCharacters(in: .whitespaces)
                if let dotRange = cleaned.range(of: #"^\d+[\.\、\)\s]+"#, options: .regularExpression) {
                    cleaned = String(cleaned[dotRange.upperBound...])
                }
                return cleaned
            }
            .filter { !$0.isEmpty }

        return lines
    }

    private func parseClaudeResponse(data: Data) throws -> FoodAnalysis {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else {
            throw AIServiceError.noContent
        }

        var cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanedText.hasPrefix("```json") {
            cleanedText = String(cleanedText.dropFirst(7))
        } else if cleanedText.hasPrefix("```") {
            cleanedText = String(cleanedText.dropFirst(3))
        }
        if cleanedText.hasSuffix("```") {
            cleanedText = String(cleanedText.dropLast(3))
        }
        cleanedText = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleanedText.data(using: .utf8) else {
            throw AIServiceError.noContent
        }

        do {
            let analysis = try JSONDecoder().decode(FoodAnalysis.self, from: jsonData)
            return analysis
        } catch {
            throw AIServiceError.decodingError(error)
        }
    }
}

// MARK: - OpenAIService

class OpenAIService: AIServiceProtocol {
    static let shared = OpenAIService()

    private let session: URLSession
    private let model = "gpt-4o"

    var apiKey: String? {
        get { UserDefaults.standard.string(forKey: "openai_api_key") }
        set { UserDefaults.standard.set(newValue, forKey: "openai_api_key") }
    }

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    func recognizeFood(imageData: Data) async throws -> FoodAnalysis {
        guard let apiKey, !apiKey.isEmpty else {
            throw AIServiceError.apiKeyMissing
        }

        let base64Image = imageData.base64EncodedString()
        if base64Image.isEmpty {
            throw AIServiceError.invalidImage
        }

        let prompt = """
        分析这张食物图片，返回JSON格式，包含foodName, calories, protein, carbs, fat, fiber, waterMl, suggestions字段。\
        其中calories/protein/carbs/fat/fiber单位为克(g)，waterMl单位为毫升(ml)。\
        suggestions为饮食建议。请只返回纯JSON，不要包含markdown标记。
        """

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": prompt
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Image)"
                            ]
                        ]
                    ]
                ]
            ]
        ]

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AIServiceError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorBody = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorBody["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw AIServiceError.apiError(message)
            }
            throw AIServiceError.httpError(statusCode: httpResponse.statusCode)
        }

        return try parseOpenAIResponse(data: data)
    }

    func translateToChinese(texts: [String]) async throws -> [String] {
        guard let apiKey, !apiKey.isEmpty else {
            throw AIServiceError.apiKeyMissing
        }

        let numberedText = texts.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")

        let prompt = """
        将以下运动指导步骤翻译为中文，保持编号格式，每行一个步骤，只返回翻译结果，不要额外说明：
        \(numberedText)
        """

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AIServiceError.invalidResponse
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let text = message["content"] as? String else {
            throw AIServiceError.noContent
        }

        let lines = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n")
            .map { line in
                var cleaned = line.trimmingCharacters(in: .whitespaces)
                if let dotRange = cleaned.range(of: #"^\d+[\.\、\)\s]+"#, options: .regularExpression) {
                    cleaned = String(cleaned[dotRange.upperBound...])
                }
                return cleaned
            }
            .filter { !$0.isEmpty }

        return lines
    }

    private func parseOpenAIResponse(data: Data) throws -> FoodAnalysis {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let text = message["content"] as? String else {
            throw AIServiceError.noContent
        }

        var cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanedText.hasPrefix("```json") {
            cleanedText = String(cleanedText.dropFirst(7))
        } else if cleanedText.hasPrefix("```") {
            cleanedText = String(cleanedText.dropFirst(3))
        }
        if cleanedText.hasSuffix("```") {
            cleanedText = String(cleanedText.dropLast(3))
        }
        cleanedText = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleanedText.data(using: .utf8) else {
            throw AIServiceError.noContent
        }

        do {
            let analysis = try JSONDecoder().decode(FoodAnalysis.self, from: jsonData)
            return analysis
        } catch {
            throw AIServiceError.decodingError(error)
        }
    }
}

// MARK: - AIServiceManager

class AIServiceManager: ObservableObject {
    static let shared = AIServiceManager()

    @AppStorage("selected_ai_provider") var selectedProvider: String = "gemini"

    var currentProvider: AIProvider {
        AIProvider(rawValue: selectedProvider) ?? .gemini
    }

    var currentService: AIServiceProtocol {
        switch currentProvider {
        case .gemini:
            return GeminiService.shared
        case .claude:
            return ClaudeService.shared
        case .openai:
            return OpenAIService.shared
        }
    }

    private init() {}

    func recognizeFood(imageData: Data) async throws -> FoodAnalysis {
        try await currentService.recognizeFood(imageData: imageData)
    }

    func translateToChinese(texts: [String]) async throws -> [String] {
        try await currentService.translateToChinese(texts: texts)
    }

    func apiKey(for provider: AIProvider) -> String? {
        let key = UserDefaults.standard.string(forKey: provider.apiKeyKey)
        return (key?.isEmpty == true) ? nil : key
    }

    func setApiKey(_ key: String, for provider: AIProvider) {
        UserDefaults.standard.set(key, forKey: provider.apiKeyKey)
    }

    func isConfigured(provider: AIProvider) -> Bool {
        apiKey(for: provider) != nil
    }
}
