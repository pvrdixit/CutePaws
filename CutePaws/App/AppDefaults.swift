import Foundation

enum AppDefaults {
    static let dailyPicksLastRefreshDateKey = "discover.lastRefreshDate"
    static let spotlightLastRefreshDateKey = "spotlight.lastRefreshDate"
    /// Remote-URL ids defining spotlight cycle order (first moves to last when a fetch for the “next” image fails).
    static let spotlightCycleOrderIDsKey = "spotlight.cycleOrderIDs"
    static let miniMomentsLastRefreshDateKey = "miniMoments.lastRefreshDate"
}
