import Foundation

enum ExerciseCategory: String, Codable, CaseIterable {
    case chest
    case back
    case shoulder
    case legs
    case arms
    case core

    var label: String {
        switch self {
        case .chest: return "胸部"
        case .back: return "背部"
        case .shoulder: return "肩部"
        case .legs: return "腿部"
        case .arms: return "手臂"
        case .core: return "核心"
        }
    }
}

enum EquipmentType: String, Codable, CaseIterable {
    case dumbbell
    case machine
    case bodyweight

    var label: String {
        switch self {
        case .dumbbell: return "哑铃"
        case .machine: return "固定器械"
        case .bodyweight: return "徒手"
        }
    }
}

struct Exercise: Identifiable {
    let id = UUID()
    let name: String
    let category: ExerciseCategory
    let equipment: EquipmentType
    let description: String
    let steps: [String]
    let tips: [String]

    static let allExercises: [Exercise] = [
        // MARK: - 胸部 (Chest)
        Exercise(
            name: "哑铃卧推",
            category: .chest,
            equipment: .dumbbell,
            description: "哑铃卧推是锻炼胸大肌的经典动作，能够有效增加胸部的厚度和宽度。",
            steps: [
                "仰卧在平板凳上，双脚踩稳地面",
                "双手各握一只哑铃，掌心朝前，手臂伸直于胸部上方",
                "缓慢下放哑铃至胸部两侧，大臂与身体成约75度角",
                "用力推起哑铃回到起始位置，在顶部短暂停留"
            ],
            tips: [
                "下放时吸气，推起时呼气",
                "保持肩胛骨收紧贴在凳面上",
                "避免手腕过度弯曲，保持中立位"
            ]
        ),
        Exercise(
            name: "器械蝴蝶夹胸",
            category: .chest,
            equipment: .machine,
            description: "蝴蝶夹胸是一个孤立训练胸肌的动作，特别针对胸肌内侧。",
            steps: [
                "坐在蝴蝶机上，调整座椅高度使手柄与胸部同高",
                "双臂打开握住手柄，保持微弯",
                "用胸肌的力量将手柄向前合拢",
                "缓慢地将手柄回到起始位置"
            ],
            tips: [
                "动作全程保持手肘微弯，不要完全锁死",
                "合拢时在中间位置挤压胸肌1-2秒",
                "注意控制回放速度，不要让重量拉着走"
            ]
        ),
        Exercise(
            name: "俯卧撑",
            category: .chest,
            equipment: .bodyweight,
            description: "俯卧撑是最经典的徒手胸部训练动作，同时锻炼三头肌和前三角肌。",
            steps: [
                "双手撑地，手掌略宽于肩，身体保持一条直线",
                "收紧核心，缓慢弯曲手肘下降身体",
                "胸部接近地面时短暂停留",
                "用力推起身体回到起始位置"
            ],
            tips: [
                "全程保持身体呈一条直线，避免塌腰或撅臀",
                "手肘不要过度外展，保持约45度角",
                "初学者可以从跪姿俯卧撑开始"
            ]
        ),

        // MARK: - 背部 (Back)
        Exercise(
            name: "哑铃单臂划船",
            category: .back,
            equipment: .dumbbell,
            description: "单臂哑铃划船能有效刺激背阔肌，同时改善左右背部肌肉的不平衡。",
            steps: [
                "一只手和同侧膝盖撑在平板凳上，另一只手握住哑铃",
                "保持背部平直，核心收紧",
                "将哑铃沿体侧向上拉至腰部位置",
                "缓慢放下哑铃至手臂完全伸展"
            ],
            tips: [
                "拉起时注意用背部发力，而非手臂",
                "保持躯干稳定，避免身体旋转借力",
                "顶部时挤压背部肌肉1-2秒"
            ]
        ),
        Exercise(
            name: "高位下拉",
            category: .back,
            equipment: .machine,
            description: "高位下拉主要锻炼背阔肌，是引体向上的替代动作，适合各水平训练者。",
            steps: [
                "坐在高位下拉器上，调整大腿垫固定身体",
                "宽握横杆，掌心朝前",
                "挺胸收肩，将横杆下拉至上胸部",
                "缓慢回放至手臂完全伸展"
            ],
            tips: [
                "下拉时身体可以略微后倾，但不要过度",
                "注意用背部肌肉发力，想象用手肘拉动重量",
                "避免耸肩，保持肩膀下沉"
            ]
        ),
        Exercise(
            name: "引体向上",
            category: .back,
            equipment: .bodyweight,
            description: "引体向上是最有效的背部训练动作之一，全面刺激背部肌群。",
            steps: [
                "双手正握单杠，握距略宽于肩",
                "身体自然悬挂，收紧核心",
                "用背部力量将身体拉起，直到下巴超过杠面",
                "缓慢下放身体至起始位置"
            ],
            tips: [
                "避免利用惯性甩动身体",
                "初学者可以使用弹力带辅助",
                "拉起时呼气，下放时吸气"
            ]
        ),

        // MARK: - 肩部 (Shoulder)
        Exercise(
            name: "哑铃肩推",
            category: .shoulder,
            equipment: .dumbbell,
            description: "哑铃肩推是锻炼三角肌前束和中束的核心动作，有助于增加肩部宽度。",
            steps: [
                "坐在有靠背的凳上，双手各持一只哑铃于肩部两侧",
                "掌心朝前，手肘弯曲约90度",
                "用力将哑铃向上推起至手臂几乎伸直",
                "缓慢下放至起始位置"
            ],
            tips: [
                "推举过程中不要过度弓背",
                "顶部不要完全锁死手肘",
                "选择适当重量，避免借力"
            ]
        ),
        Exercise(
            name: "器械反向飞鸟",
            category: .shoulder,
            equipment: .machine,
            description: "反向飞鸟主要锻炼三角肌后束和上背部肌群，改善肩部圆润度。",
            steps: [
                "面对蝴蝶机坐下，调整手柄到与肩同高",
                "双手握住手柄，手臂微弯",
                "用力向后展开双臂，挤压肩胛骨",
                "缓慢回到起始位置"
            ],
            tips: [
                "动作要慢，注意感受后三角肌的发力",
                "避免用过大重量导致借力",
                "保持手肘高度始终与肩同高"
            ]
        ),
        Exercise(
            name: "侧平举",
            category: .shoulder,
            equipment: .dumbbell,
            description: "哑铃侧平举专门针对三角肌中束，是打造宽肩的必练动作。",
            steps: [
                "站立，双手各持一只哑铃于体侧",
                "保持手肘微弯，将哑铃向两侧抬起",
                "抬至手臂与地面平行时停顿",
                "缓慢放下至起始位置"
            ],
            tips: [
                "不要耸肩，保持肩膀下沉",
                "抬起时小指微微高于拇指，更好地刺激中束",
                "使用较轻的重量，注重肌肉感受"
            ]
        ),

        // MARK: - 腿部 (Legs)
        Exercise(
            name: "哑铃深蹲",
            category: .legs,
            equipment: .dumbbell,
            description: "哑铃深蹲是全面锻炼下肢的复合动作，主要刺激股四头肌和臀大肌。",
            steps: [
                "双脚与肩同宽站立，双手持哑铃于体侧",
                "挺胸收腹，臀部向后坐下",
                "下蹲至大腿与地面平行或略低",
                "用力蹬地站起回到起始位置"
            ],
            tips: [
                "膝盖方向与脚尖方向保持一致",
                "下蹲时重心放在脚后跟",
                "保持背部挺直，不要弯腰"
            ]
        ),
        Exercise(
            name: "腿举机",
            category: .legs,
            equipment: .machine,
            description: "腿举是安全有效的腿部训练动作，适合大重量训练股四头肌和臀部。",
            steps: [
                "坐在腿举机上，双脚踩在踏板上与肩同宽",
                "释放安全锁，缓慢弯曲膝盖",
                "下放至膝盖弯曲约90度",
                "用力蹬起踏板至腿部几乎伸直"
            ],
            tips: [
                "不要完全锁死膝盖",
                "下放时保持下背部紧贴靠背",
                "调整脚的位置可以侧重不同肌群"
            ]
        ),
        Exercise(
            name: "徒手箭步蹲",
            category: .legs,
            equipment: .bodyweight,
            description: "箭步蹲能有效锻炼股四头肌、臀肌和大腿后侧，同时提高平衡能力。",
            steps: [
                "双脚并拢站立，双手叉腰或自然下垂",
                "一只脚向前迈出一大步",
                "弯曲双膝下蹲，后膝接近地面",
                "前腿发力蹬起，回到起始位置，换腿重复"
            ],
            tips: [
                "前膝不要超过脚尖太多",
                "保持上身直立，核心收紧",
                "步幅要足够大以确保正确的膝盖角度"
            ]
        ),

        // MARK: - 手臂 (Arms)
        Exercise(
            name: "哑铃弯举",
            category: .arms,
            equipment: .dumbbell,
            description: "哑铃弯举是锻炼肱二头肌最经典的动作，能有效增加手臂围度。",
            steps: [
                "站立，双手各持一只哑铃于体侧，掌心朝前",
                "保持上臂固定不动，弯曲肘关节将哑铃举起",
                "举至肱二头肌完全收缩，短暂停顿",
                "缓慢放下至起始位置"
            ],
            tips: [
                "上臂始终紧贴身体两侧",
                "避免借助身体晃动来举起重量",
                "可以交替进行，更好地专注每一侧"
            ]
        ),
        Exercise(
            name: "绳索下压",
            category: .arms,
            equipment: .machine,
            description: "绳索下压是锻炼肱三头肌的经典动作，能很好地孤立刺激三头肌。",
            steps: [
                "站在龙门架前，双手握住绳索或直杆",
                "上臂固定于体侧，肘关节弯曲约90度",
                "用力向下伸展前臂，直到手臂完全伸直",
                "缓慢回到起始位置"
            ],
            tips: [
                "全程保持上臂不动，只活动前臂",
                "伸直时挤压三头肌1-2秒",
                "身体略微前倾，保持稳定"
            ]
        ),
        Exercise(
            name: "钻石俯卧撑",
            category: .arms,
            equipment: .bodyweight,
            description: "钻石俯卧撑通过窄距手位重点刺激肱三头肌，同时锻炼胸肌内侧。",
            steps: [
                "俯卧撑姿势，双手靠拢放在胸部下方，拇指和食指组成钻石形状",
                "收紧核心，身体保持一条直线",
                "弯曲手肘，缓慢下降身体",
                "胸部接近手背时，用力推起回到起始位置"
            ],
            tips: [
                "手肘尽量贴近身体两侧",
                "如果太难，可以先从跪姿开始",
                "下降速度要慢，注意感受三头肌发力"
            ]
        ),

        // MARK: - 核心 (Core)
        Exercise(
            name: "哑铃俄罗斯转体",
            category: .core,
            equipment: .dumbbell,
            description: "俄罗斯转体是锻炼腹斜肌的经典动作，能有效增强核心旋转力量。",
            steps: [
                "坐在地上，膝盖弯曲，双脚可离地或着地",
                "上身后倾约45度，双手持一只哑铃于胸前",
                "转动躯干将哑铃移向身体一侧",
                "再转向另一侧，交替进行"
            ],
            tips: [
                "转动来自躯干而非手臂",
                "保持背部挺直，不要弯曲",
                "动作要有控制，不要依靠惯性"
            ]
        ),
        Exercise(
            name: "器械卷腹",
            category: .core,
            equipment: .machine,
            description: "器械卷腹通过固定的运动轨迹安全有效地锻炼腹直肌。",
            steps: [
                "坐在卷腹机上，调整座椅和重量",
                "双脚固定在脚垫下，双手握住手柄",
                "用腹肌的力量向前卷曲身体",
                "缓慢回到起始位置"
            ],
            tips: [
                "注意用腹肌发力，而非手臂拉动",
                "卷曲时呼气，回放时吸气",
                "动作幅度不需要太大，注重腹肌收缩感"
            ]
        ),
        Exercise(
            name: "平板支撑",
            category: .core,
            equipment: .bodyweight,
            description: "平板支撑是最基础的核心稳定性训练，能全面激活深层核心肌群。",
            steps: [
                "前臂和脚尖撑地，身体保持一条直线",
                "收紧腹部，臀部不要上翘或下沉",
                "保持均匀呼吸",
                "维持姿势至规定时间"
            ],
            tips: [
                "目视地面，颈部保持中立位",
                "初学者可从30秒开始，逐渐增加时间",
                "感觉腰部酸痛时应立即停止"
            ]
        )
    ]
}
