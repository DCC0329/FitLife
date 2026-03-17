import Foundation

// MARK: - Free Exercise DB Model

struct FreeExercise: Codable, Identifiable {
    let id: String
    let name: String
    let force: String?
    let level: String?
    let mechanic: String?
    let equipment: String?
    let primaryMuscles: [String]
    let secondaryMuscles: [String]
    let instructions: [String]
    let category: String?
    let images: [String]
}

// MARK: - Free Exercise DB Service

class FreeExerciseDBService {
    static let shared = FreeExerciseDBService()

    private let exercisesURL = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json"
    private let imagesBaseURL = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/"

    private var cachedExercises: [FreeExercise]?
    private let session: URLSession

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: configuration)
    }

    // MARK: - Body Part Mapping

    /// Maps ExerciseDB body part names to Free Exercise DB primaryMuscles values
    private static let bodyPartToMuscles: [String: [String]] = [
        "chest": ["chest"],
        "back": ["middle back", "lower back", "lats", "traps"],
        "shoulders": ["shoulders"],
        "upper legs": ["quadriceps", "hamstrings", "glutes", "adductors", "abductors"],
        "lower legs": ["calves"],
        "upper arms": ["biceps", "triceps"],
        "lower arms": ["forearms"],
        "waist": ["abdominals", "obliques"],
    ]

    // MARK: - Data Loading

    private func loadAllExercises() async throws -> [FreeExercise] {
        if let cached = cachedExercises {
            return cached
        }

        guard let url = URL(string: exercisesURL) else {
            throw ExerciseDBError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ExerciseDBError.invalidResponse
        }

        do {
            let exercises = try JSONDecoder().decode([FreeExercise].self, from: data)
            cachedExercises = exercises
            return exercises
        } catch {
            throw ExerciseDBError.decodingError(error)
        }
    }

    // MARK: - Conversion

    private func convertToExerciseDB(_ exercise: FreeExercise) -> ExerciseDBExercise {
        let imageURL: String
        if let firstImage = exercise.images.first {
            imageURL = imagesBaseURL + firstImage
        } else {
            imageURL = ""
        }

        let equipments: [String]
        if let equipment = exercise.equipment {
            equipments = [equipment]
        } else {
            equipments = []
        }

        return ExerciseDBExercise(
            exerciseId: exercise.id,
            name: exercise.name,
            gifUrl: imageURL,
            targetMuscles: exercise.primaryMuscles,
            bodyParts: exercise.category.map { [$0] } ?? [],
            equipments: equipments,
            secondaryMuscles: exercise.secondaryMuscles,
            instructions: exercise.instructions
        )
    }

    // MARK: - Public Methods

    func fetchExercisesByBodyPart(_ bodyPart: String) async -> [ExerciseDBExercise] {
        do {
            let allExercises = try await loadAllExercises()
            let matchingMuscles = Self.bodyPartToMuscles[bodyPart.lowercased()] ?? [bodyPart.lowercased()]

            let filtered = allExercises.filter { exercise in
                exercise.primaryMuscles.contains { muscle in
                    matchingMuscles.contains(muscle.lowercased())
                }
            }

            return filtered.map { convertToExerciseDB($0) }
        } catch {
            return []
        }
    }

    func searchExercises(query: String) async -> [ExerciseDBExercise] {
        do {
            let allExercises = try await loadAllExercises()
            let lowercasedQuery = query.lowercased()

            let filtered = allExercises.filter { exercise in
                exercise.name.lowercased().contains(lowercasedQuery)
            }

            return filtered.map { convertToExerciseDB($0) }
        } catch {
            return []
        }
    }
}
