/// Represents a goal's frequency type
enum GoalFrequency: String, CaseIterable {
    case daily
    case weekly
    case monthly
    
    var label: String {
        switch self {
        case .daily: return "day"
        case .weekly: return "week"
        case .monthly: return "month"
        }
    }
}
