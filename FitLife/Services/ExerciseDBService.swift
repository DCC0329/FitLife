import Foundation

// MARK: - Response Models

struct StringListResponse: Codable {
    let success: Bool
    let data: [String]
}

struct ExerciseDBResponse: Codable {
    let success: Bool
    let metadata: ExerciseDBMetadata
    let data: [ExerciseDBExercise]
}

struct ExerciseDBMetadata: Codable {
    let totalExercises: Int
    let totalPages: Int
    let currentPage: Int
}

struct ExerciseDBExercise: Codable, Identifiable {
    let exerciseId: String
    let name: String
    let gifUrl: String
    let targetMuscles: [String]
    let bodyParts: [String]
    let equipments: [String]
    let secondaryMuscles: [String]
    let instructions: [String]

    var id: String { exerciseId }
}

struct SingleExerciseResponse: Codable {
    let success: Bool
    let data: ExerciseDBExercise
}

// MARK: - Service Errors

enum ExerciseDBError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL."
        case .invalidResponse:
            return "Invalid response from server."
        case .httpError(let statusCode):
            return "HTTP error with status code \(statusCode)."
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}

// MARK: - Service

class ExerciseDBService {
    static let shared = ExerciseDBService()

    private let baseURL = "https://exercisedb.dev/api/v1"
    private let session: URLSession

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: configuration)
    }

    // MARK: - Public Methods

    func fetchBodyParts() async throws -> [String] {
        let data = try await performRequest(path: "/bodyparts")
        do {
            let response = try JSONDecoder().decode(StringListResponse.self, from: data)
            return response.data
        } catch {
            throw ExerciseDBError.decodingError(error)
        }
    }

    func fetchEquipments() async throws -> [String] {
        let data = try await performRequest(path: "/equipments")
        do {
            let response = try JSONDecoder().decode(StringListResponse.self, from: data)
            return response.data
        } catch {
            throw ExerciseDBError.decodingError(error)
        }
    }

    func fetchExercisesByBodyPart(_ bodyPart: String, offset: Int = 0, limit: Int = 20) async throws -> [ExerciseDBExercise] {
        let encodedBodyPart = bodyPart.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? bodyPart
        let data = try await performRequest(
            path: "/bodyparts/\(encodedBodyPart)/exercises",
            queryItems: [
                URLQueryItem(name: "offset", value: "\(offset)"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
        )
        do {
            let response = try JSONDecoder().decode(ExerciseDBResponse.self, from: data)
            return response.data
        } catch {
            throw ExerciseDBError.decodingError(error)
        }
    }

    func fetchExercisesByEquipment(_ equipment: String, offset: Int = 0, limit: Int = 20) async throws -> [ExerciseDBExercise] {
        let encodedEquipment = equipment.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? equipment
        let data = try await performRequest(
            path: "/equipments/\(encodedEquipment)/exercises",
            queryItems: [
                URLQueryItem(name: "offset", value: "\(offset)"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
        )
        do {
            let response = try JSONDecoder().decode(ExerciseDBResponse.self, from: data)
            return response.data
        } catch {
            throw ExerciseDBError.decodingError(error)
        }
    }

    func fetchExercisesByMuscle(_ muscle: String, offset: Int = 0, limit: Int = 20) async throws -> [ExerciseDBExercise] {
        let encodedMuscle = muscle.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? muscle
        let data = try await performRequest(
            path: "/muscles/\(encodedMuscle)/exercises",
            queryItems: [
                URLQueryItem(name: "offset", value: "\(offset)"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
        )
        do {
            let response = try JSONDecoder().decode(ExerciseDBResponse.self, from: data)
            return response.data
        } catch {
            throw ExerciseDBError.decodingError(error)
        }
    }

    func searchExercises(query: String, limit: Int = 20) async throws -> [ExerciseDBExercise] {
        let data = try await performRequest(
            path: "/exercises/search",
            queryItems: [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
        )
        do {
            let response = try JSONDecoder().decode(ExerciseDBResponse.self, from: data)
            return response.data
        } catch {
            throw ExerciseDBError.decodingError(error)
        }
    }

    func fetchExercise(id: String) async throws -> ExerciseDBExercise? {
        let encodedId = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        let data = try await performRequest(path: "/exercises/\(encodedId)")
        do {
            let response = try JSONDecoder().decode(SingleExerciseResponse.self, from: data)
            return response.data
        } catch {
            throw ExerciseDBError.decodingError(error)
        }
    }

    // MARK: - Private Helpers

    private func performRequest(path: String, queryItems: [URLQueryItem]? = nil) async throws -> Data {
        guard var components = URLComponents(string: baseURL + path) else {
            throw ExerciseDBError.invalidURL
        }

        if let queryItems, !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw ExerciseDBError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ExerciseDBError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw ExerciseDBError.httpError(statusCode: httpResponse.statusCode)
        }

        return data
    }
}
