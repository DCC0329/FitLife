import Foundation
import HealthKit
import SwiftUI

@MainActor
class HealthKitManager: ObservableObject {

    // MARK: - Published Properties

    @Published var todaySteps: Double = 0
    @Published var todayCalories: Double = 0
    @Published var todayExerciseMinutes: Double = 0
    @Published var todayDistance: Double = 0
    @Published var isAuthorized: Bool = false
    @Published var currentHeartRate: Double = 0

    // MARK: - Private

    private let healthStore: HKHealthStore?
    private let isAvailable: Bool
    private var heartRateQuery: HKAnchoredObjectQuery?

    init() {
        if HKHealthStore.isHealthDataAvailable() {
            self.healthStore = HKHealthStore()
            self.isAvailable = true
        } else {
            self.healthStore = nil
            self.isAvailable = false
        }
    }

    // MARK: - Authorization

    /// The set of HealthKit quantity/category types we want to read.
    private var readTypes: Set<HKObjectType> {
        let types: [HKObjectType?] = [
            HKQuantityType.quantityType(forIdentifier: .stepCount),
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
            HKQuantityType.quantityType(forIdentifier: .appleExerciseTime),
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning),
            HKQuantityType.quantityType(forIdentifier: .bodyMass),
            HKQuantityType.quantityType(forIdentifier: .heartRate),
            HKCategoryType.categoryType(forIdentifier: .sleepAnalysis),
            HKObjectType.workoutType()
        ]
        return Set(types.compactMap { $0 })
    }

    func requestAuthorization() async {
        guard let healthStore, isAvailable else {
            isAuthorized = false
            return
        }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
        } catch {
            print("HealthKit authorization failed: \(error.localizedDescription)")
            isAuthorized = false
        }
    }

    // MARK: - Today Fetches

    func fetchTodaySteps() async -> Double {
        let value = await fetchTodayStatistic(for: .stepCount, unit: .count())
        todaySteps = value
        return value
    }

    func fetchTodayCalories() async -> Double {
        let value = await fetchTodayStatistic(for: .activeEnergyBurned, unit: .kilocalorie())
        todayCalories = value
        return value
    }

    func fetchTodayExerciseMinutes() async -> Double {
        let value = await fetchTodayStatistic(for: .appleExerciseTime, unit: .minute())
        todayExerciseMinutes = value
        return value
    }

    func fetchTodayDistance() async -> Double {
        let meters = await fetchTodayStatistic(for: .distanceWalkingRunning, unit: .meter())
        let km = meters / 1000.0
        todayDistance = km
        return km
    }

    // MARK: - Workouts

    func fetchWorkouts(for date: Date) async -> [HKWorkout] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }
        return await fetchWorkouts(from: startOfDay, to: endOfDay)
    }

    func fetchWorkouts(from startDate: Date, to endDate: Date) async -> [HKWorkout] {
        guard let healthStore, isAvailable else { return [] }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    print("Failed to fetch workouts: \(error.localizedDescription)")
                    continuation.resume(returning: [])
                    return
                }
                let workouts = (samples as? [HKWorkout]) ?? []
                continuation.resume(returning: workouts)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Sleep

    func fetchSleepData(for date: Date) async -> (bedTime: Date?, wakeTime: Date?, duration: TimeInterval)? {
        guard let healthStore, isAvailable else { return nil }

        let calendar = Calendar.current
        // Look for sleep that ended on this date (people go to bed the night before)
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return nil
        }
        // Search window: previous evening to end of target day
        guard let searchStart = calendar.date(byAdding: .hour, value: -12, to: startOfDay) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(withStart: searchStart, end: endOfDay, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    print("Failed to fetch sleep data: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }

                guard let categorySamples = samples as? [HKCategorySample], !categorySamples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }

                // Filter to asleep samples (not inBed)
                let asleepSamples = categorySamples.filter { sample in
                    sample.value != HKCategoryValueSleepAnalysis.inBed.rawValue
                }

                let sleepSamples = asleepSamples.isEmpty ? categorySamples : asleepSamples

                let bedTime = sleepSamples.first?.startDate
                let wakeTime = sleepSamples.last?.endDate
                let totalDuration = sleepSamples.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }

                continuation.resume(returning: (bedTime: bedTime, wakeTime: wakeTime, duration: totalDuration))
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Real-time Heart Rate

    func startHeartRateObserver() {
        guard let healthStore, isAvailable else { return }
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }

        // 先拉取最近一次心率立即显示
        fetchLatestHeartRate()

        let handler: (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void = { [weak self] _, samples, _, _, _ in
            guard let self,
                  let sample = (samples as? [HKQuantitySample])?.last else { return }
            let bpm = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
            Task { @MainActor in
                self.currentHeartRate = bpm
            }
        }

        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: HKQuery.predicateForSamples(withStart: Date(), end: nil, options: .strictStartDate),
            anchor: nil,
            limit: HKObjectQueryNoLimit,
            resultsHandler: handler
        )
        query.updateHandler = handler
        heartRateQuery = query
        healthStore.execute(query)
    }

    private func fetchLatestHeartRate() {
        guard let healthStore, isAvailable else { return }
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: HKQuery.predicateForSamples(
                withStart: Calendar.current.date(byAdding: .hour, value: -1, to: Date()),
                end: Date(),
                options: .strictEndDate
            ),
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, _ in
            guard let self,
                  let sample = (samples as? [HKQuantitySample])?.first else { return }
            let bpm = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
            Task { @MainActor in
                self.currentHeartRate = bpm
            }
        }
        healthStore.execute(query)
    }

    func stopHeartRateObserver() {
        guard let healthStore, let query = heartRateQuery else { return }
        healthStore.stop(query)
        heartRateQuery = nil
        currentHeartRate = 0
    }

    // MARK: - Weekly Steps

    func fetchWeeklySteps() async -> [(date: Date, steps: Double)] {
        guard let healthStore, isAvailable else { return [] }
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return [] }

        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: endDate)) else {
            return []
        }

        var interval = DateComponents()
        interval.day = 1

        let anchorDate = calendar.startOfDay(for: startDate)

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: anchorDate,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, results, error in
                if let error {
                    print("Failed to fetch weekly steps: \(error.localizedDescription)")
                    continuation.resume(returning: [])
                    return
                }

                guard let results else {
                    continuation.resume(returning: [])
                    return
                }

                var dailySteps: [(date: Date, steps: Double)] = []

                results.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    let steps = statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0
                    dailySteps.append((date: statistics.startDate, steps: steps))
                }

                continuation.resume(returning: dailySteps)
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Private Helpers

    private func fetchTodayStatistic(for identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double {
        guard let healthStore, isAvailable else { return 0 }
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else { return 0 }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    print("Failed to fetch \(identifier.rawValue): \(error.localizedDescription)")
                    continuation.resume(returning: 0)
                    return
                }
                let value = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }
}

// MARK: - Workout Activity Type Names

extension HKWorkoutActivityType {
    var commonName: String {
        switch self {
        case .running: return "跑步"
        case .walking: return "步行"
        case .cycling: return "骑行"
        case .swimming: return "游泳"
        case .yoga: return "瑜伽"
        case .functionalStrengthTraining, .traditionalStrengthTraining: return "力量训练"
        case .highIntensityIntervalTraining: return "HIIT"
        case .elliptical: return "椭圆机"
        case .rowing: return "划船"
        case .stairClimbing: return "爬楼梯"
        case .coreTraining: return "核心训练"
        case .dance, .socialDance, .cardioDance: return "舞蹈"
        case .cooldown: return "放松"
        case .jumpRope: return "跳绳"
        case .boxing: return "拳击"
        case .kickboxing: return "搏击"
        case .pilates: return "普拉提"
        case .hiking: return "徒步"
        case .fitnessGaming: return "游戏健身"
        case .mixedCardio: return "混合有氧"
        case .crossTraining: return "交叉训练"
        case .flexibility: return "拉伸"
        case .mindAndBody: return "身心训练"
        case .play: return "自由运动"
        case .preparationAndRecovery: return "恢复训练"
        case .skatingSports: return "滑冰"
        case .snowSports: return "滑雪"
        case .surfingSports: return "冲浪"
        case .waterFitness: return "水中健身"
        case .tennis: return "网球"
        case .badminton: return "羽毛球"
        case .tableTennis: return "乒乓球"
        case .basketball: return "篮球"
        case .soccer: return "足球"
        case .baseball: return "棒球"
        case .volleyball: return "排球"
        case .golf: return "高尔夫"
        case .martialArts: return "武术"
        case .taiChi: return "太极"
        case .wrestling: return "摔跤"
        case .climbing: return "攀岩"
        case .crossCountrySkiing: return "越野滑雪"
        case .downhillSkiing: return "高山滑雪"
        case .paddleSports: return "皮划艇"
        case .trackAndField: return "田径"
        case .other: return "其他运动"
        default:
            // 未映射的类型，从枚举 debug 描述中提取英文名
            let raw = String(describing: self)
            // 驼峰转空格，如 "handCycling" -> "Hand Cycling"
            let spaced = raw.unicodeScalars.reduce("") { result, scalar in
                if CharacterSet.uppercaseLetters.contains(scalar) && !result.isEmpty {
                    return result + " " + String(scalar)
                }
                return result + String(scalar)
            }
            return spaced.prefix(1).uppercased() + spaced.dropFirst()
        }
    }
}
