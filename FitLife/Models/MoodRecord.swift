import Foundation
import SwiftData

@Model
final class MoodRecord {
    var id: UUID
    var date: Date
    var moodRaw: String

    var mood: Mood {
        get { Mood(rawValue: moodRaw) ?? .neutral }
        set { moodRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), date: Date = .now, mood: Mood = .neutral) {
        self.id = id
        self.date = date
        self.moodRaw = mood.rawValue
    }
}

enum Mood: String, Codable, CaseIterable, Identifiable {
    // 主要心情（首页显示）
    case happy
    case good
    case neutral
    case sad
    case angry

    // 更多心情（展开后显示）
    case excited
    case anxious
    case surprised
    case playful
    case shy
    case nervous
    case proud
    case upset

    var id: String { rawValue }

    var label: String {
        switch self {
        case .excited:   return "兴奋"
        case .happy:     return "开心"
        case .good:      return "不错"
        case .neutral:   return "一般"
        case .proud:     return "自信"
        case .playful:   return "调皮"
        case .shy:       return "害羞"
        case .surprised: return "惊讶"
        case .anxious:   return "焦虑"
        case .nervous:   return "紧张"
        case .upset:     return "委屈"
        case .sad:       return "难过"
        case .angry:     return "烦躁"
        }
    }

    /// Asset image name in xcassets
    var imageName: String {
        switch self {
        case .excited:   return "mood_01"  // 星星眼
        case .happy:     return "mood_02"  // 笑哭
        case .anxious:   return "mood_03"  // 焦虑
        case .sad:       return "mood_04"  // 大哭
        case .surprised: return "mood_05"  // 惊讶
        case .playful:   return "mood_06"  // 吐舌大笑
        case .shy:       return "mood_07"  // 害羞捂脸
        case .nervous:   return "mood_08"  // 咬牙紧张
        case .proud:     return "mood_09"  // 自信闪闪
        case .upset:     return "mood_11"  // 委屈
        case .angry:     return "mood_12"  // 崩溃
        case .neutral:   return "mood_13"  // 思考
        case .good:      return "mood_14"  // 俏皮微笑
        }
    }

    /// 首页展示的5个主要心情
    static var primary: [Mood] {
        [.happy, .good, .neutral, .sad, .angry]
    }

    /// 展开后显示的所有心情
    static var all: [Mood] {
        [.excited, .happy, .good, .proud, .playful,
         .shy, .neutral, .surprised, .anxious,
         .nervous, .upset, .sad, .angry]
    }
}
