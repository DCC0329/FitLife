import Foundation

// MARK: - FoodAnalysis

struct FoodAnalysis: Codable, Identifiable {
    var id: UUID = UUID()
    let foodName: String
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double
    let waterMl: Double
    let suggestions: String

    enum CodingKeys: String, CodingKey {
        case foodName, calories, protein, carbs, fat, fiber, waterMl, suggestions
    }
}

// MARK: - GeminiError

enum GeminiError: LocalizedError {
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
            return "Gemini API key is not configured. Please set it in Settings."
        case .invalidImage:
            return "The provided image data is invalid."
        case .invalidURL:
            return "Failed to construct the API URL."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Received an invalid response from the server."
        case .httpError(let statusCode):
            return "Server returned HTTP \(statusCode)."
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .noContent:
            return "The API returned no content."
        case .apiError(let message):
            return "Gemini API error: \(message)"
        }
    }
}

// MARK: - GeminiService

class GeminiService: AIServiceProtocol {

    static let shared = GeminiService()

    private let session: URLSession
    private let model = "gemini-2.5-flash"

    var apiKey: String? {
        get { UserDefaults.standard.string(forKey: "gemini_api_key") }
        set { UserDefaults.standard.set(newValue, forKey: "gemini_api_key") }
    }

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public

    func recognizeFood(imageData: Data) async throws -> FoodAnalysis {
        guard let apiKey, !apiKey.isEmpty else {
            throw GeminiError.apiKeyMissing
        }

        let base64Image = imageData.base64EncodedString()
        if base64Image.isEmpty {
            throw GeminiError.invalidImage
        }

        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw GeminiError.invalidURL
        }

        let prompt = """
        分析这张食物图片，返回JSON格式，包含foodName, calories, protein, carbs, fat, fiber, waterMl, suggestions字段。\
        其中calories/protein/carbs/fat/fiber单位为克(g)，waterMl单位为毫升(ml)。\
        suggestions为饮食建议。请只返回纯JSON，不要包含markdown标记。
        """

        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": prompt
                        ],
                        [
                            "inline_data": [
                                "mime_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ]
                    ]
                ]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw GeminiError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to extract error message from response body
            if let errorBody = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorBody["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw GeminiError.apiError(message)
            }
            throw GeminiError.httpError(statusCode: httpResponse.statusCode)
        }

        return try parseGeminiResponse(data: data)
    }

    // MARK: - Translate Text

    func translateToChinese(texts: [String]) async throws -> [String] {
        guard let apiKey, !apiKey.isEmpty else {
            throw GeminiError.apiKeyMissing
        }

        let numberedText = texts.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")

        let prompt = """
        将以下运动指导步骤翻译为中文，保持编号格式，每行一个步骤，只返回翻译结果，不要额外说明：
        \(numberedText)
        """

        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw GeminiError.invalidURL
        }

        let requestBody: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw GeminiError.invalidResponse
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw GeminiError.noContent
        }

        // Parse numbered lines
        let lines = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n")
            .map { line in
                // Remove "1. " or "1、" prefix
                var cleaned = line.trimmingCharacters(in: .whitespaces)
                if let dotRange = cleaned.range(of: #"^\d+[\.\、\)\s]+"#, options: .regularExpression) {
                    cleaned = String(cleaned[dotRange.upperBound...])
                }
                return cleaned
            }
            .filter { !$0.isEmpty }

        return lines
    }

    // MARK: - Private

    private func parseGeminiResponse(data: Data) throws -> FoodAnalysis {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw GeminiError.noContent
        }

        // Clean up the text: remove markdown code fences if present
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
            throw GeminiError.noContent
        }

        do {
            let analysis = try JSONDecoder().decode(FoodAnalysis.self, from: jsonData)
            return analysis
        } catch {
            throw GeminiError.decodingError(error)
        }
    }
}
