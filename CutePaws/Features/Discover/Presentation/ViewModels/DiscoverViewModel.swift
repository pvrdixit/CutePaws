import Combine
import Foundation

@MainActor
final class DiscoverViewModel: ObservableObject {
    @Published private(set) var items: [MediaItem] = []
    @Published var spotlightImagePath: String?
    @Published var spotlightAspectRatio: Double?
    @Published private(set) var state: DiscoverViewState = .loading
    @Published var imageDetailViewModel: ImageDetailViewModel?

    private let repository: DiscoverRepository
    let spotlightRepository: SpotlightRepository
    let userDefaults: UserDefaults
    let calendar: Calendar

    private var started = false

    private let dailyPicksVisibleCount: Int
    private let dailyPicksImageLimit: Int
    let spotlightImageLimit: Int

    private var loadTask: Task<Void, Never>?
    var spotlightTask: Task<Void, Never>?

    init(
        repository: DiscoverRepository,
        spotlightRepository: SpotlightRepository,
        initialItems: [MediaItem] = [],
        initialSpotlightImagePath: String? = nil,
        initialSpotlightAspectRatio: Double? = nil,
        dailyPicksVisibleCount: Int = 20,
        dailyPicksImageLimit: Int = 20,
        spotlightImageLimit: Int = 2,
        userDefaults: UserDefaults = .standard,
        calendar: Calendar = .current
    ) {
        self.repository = repository
        self.spotlightRepository = spotlightRepository
        self.dailyPicksVisibleCount = dailyPicksVisibleCount
        self.dailyPicksImageLimit = dailyPicksImageLimit
        self.spotlightImageLimit = spotlightImageLimit
        self.userDefaults = userDefaults
        self.calendar = calendar
        items = initialItems
        spotlightImagePath = initialSpotlightImagePath
        spotlightAspectRatio = initialSpotlightAspectRatio
        state = initialItems.isEmpty ? .loading : .loaded
    }

    func start() {
        guard !started else { return }
        started = true

        debugLog("start items=\(items.count) state=\(stateLabel)")
        runLoad(forceReload: false)
    }

    func retry() {
        debugLog("retry")
        runLoad(forceReload: true)
    }

    func showImageDetail(for item: MediaItem) {
        imageDetailViewModel = ImageDetailViewModel(items: items, selectedItemID: item.id)
    }

    func dismissImageDetail() {
        imageDetailViewModel = nil
    }

    private func runLoad(forceReload: Bool) {
        loadTask?.cancel()
        spotlightTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            await self.loadDiscoverItems(forceReload: forceReload)
        }
    }

    private func loadDiscoverItems(forceReload: Bool = false) async {
        debugLog("loadDiscoverItems begin forceReload=\(forceReload) currentItems=\(items.count) state=\(stateLabel)")

        if forceReload {
            state = .loading
            debugLog("state -> loading because forceReload")
        }

        startSpotlight(forceReload: forceReload)
        guard !Task.isCancelled else { return }

        let cachedItems = await repository.loadCached(limit: dailyPicksVisibleCount)
        debugLog("pre-prepare cachedItems=\(cachedItems.count)")
        guard !Task.isCancelled else { return }

        if !cachedItems.isEmpty {
            items = cachedItems
            state = .loaded
            debugLog("applied pre-prepare cached items count=\(cachedItems.count)")
        }

        await repository.prepare()
        debugLog("repository.prepare completed")
        guard !Task.isCancelled else { return }

        let cachedCount = await repository.cachedCount()
        let refreshedCachedItems = await repository.loadCached(limit: dailyPicksVisibleCount)
        let shouldRefreshDailyPicks = shouldRunDailyRefresh(forKey: AppDefaults.dailyPicksLastRefreshDateKey)
        debugLog("post-prepare cachedCount=\(cachedCount) refreshedVisible=\(refreshedCachedItems.count) shouldRefreshDailyPicks=\(shouldRefreshDailyPicks)")

        if !refreshedCachedItems.isEmpty {
            items = refreshedCachedItems
            state = .loaded
            debugLog("applied post-prepare cached items count=\(refreshedCachedItems.count)")
        }

        if cachedCount == 0 {
            debugLog("branch -> bootstrapInitialItems")
            await bootstrapInitialItems()
            return
        }

        if cachedCount < dailyPicksImageLimit {
            debugLog("branch -> fillCacheToTarget currentCount=\(cachedCount) target=\(dailyPicksImageLimit)")
            if shouldRefreshDailyPicks {
                markRefreshedToday()
            }
            await fillCacheToTarget()
            return
        }

        if shouldRefreshDailyPicks {
            debugLog("branch -> runDailyRefresh")
            markRefreshedToday()
            await runDailyRefresh()
        } else {
            debugLog("branch -> no fetch needed")
        }
    }

    private func bootstrapInitialItems() async {
        debugLog("bootstrapInitialItems begin")
        do {
            try await fillCache(untilAtLeast: dailyPicksVisibleCount)
            items = await repository.loadCached(limit: dailyPicksVisibleCount)
            state = .loaded
            debugLog("bootstrapInitialItems loaded visible items count=\(items.count)")
            markRefreshedToday()
            await fillCacheToTarget()
        } catch let error {
            guard !(error is CancellationError) else { return }
            debugLog("bootstrapInitialItems failed")
            state = .error("Failed to load images. Try again.")
        }
    }

    private func fillCache(untilAtLeast minimumCount: Int) async throws {
        var attempts = 0

        while attempts < 5 {
            guard !Task.isCancelled else { throw CancellationError() }
            let currentCount = await repository.cachedCount()
            debugLog("fillCache attempt=\(attempts + 1) currentCount=\(currentCount) minimum=\(minimumCount)")
            guard currentCount < minimumCount else { return }

            try await repository.fetchAndStore(count: minimumCount - currentCount)
            attempts += 1
        }

        if await repository.cachedCount() < minimumCount {
            throw URLError(.cannotLoadFromNetwork)
        }
    }

    private func fillCacheToTarget() async {
        guard !Task.isCancelled else { return }
        let shouldRefreshVisibleItems = items.count < dailyPicksVisibleCount
        var stalledAttempts = 0

        debugLog("fillCacheToTarget begin visibleItems=\(items.count) shouldRefreshVisibleItems=\(shouldRefreshVisibleItems)")

        while stalledAttempts < 3 {
            guard !Task.isCancelled else { return }
            let currentCount = await repository.cachedCount()
            debugLog("fillCacheToTarget loop currentCount=\(currentCount) target=\(dailyPicksImageLimit) stalledAttempts=\(stalledAttempts)")
            guard currentCount < dailyPicksImageLimit else { break }

            do {
                try await repository.fetchAndStore(count: min(dailyPicksImageLimit, dailyPicksImageLimit - currentCount))
            } catch {
                debugLog("fillCacheToTarget fetch failed")
                return
            }

            let updatedCount = await repository.cachedCount()
            debugLog("fillCacheToTarget updatedCount=\(updatedCount)")
            stalledAttempts = updatedCount <= currentCount ? stalledAttempts + 1 : 0
        }

        if shouldRefreshVisibleItems {
            items = await repository.loadCached(limit: dailyPicksVisibleCount)
            debugLog("fillCacheToTarget refreshed visible items count=\(items.count)")
        }

        debugLog("fillCacheToTarget end")
    }

    private func runDailyRefresh() async {
        guard !Task.isCancelled else { return }
        debugLog("runDailyRefresh begin dailyPicksImageLimit=\(dailyPicksImageLimit)")
        do {
            try await repository.fetchAndStore(count: dailyPicksImageLimit)
            await repository.trimToLatest(maxCount: dailyPicksImageLimit)
            userDefaults.set(Date(), forKey: AppDefaults.dailyPicksLastRefreshDateKey)
            let finalCount = await repository.cachedCount()
            debugLog("runDailyRefresh end finalCount=\(finalCount)")
        } catch {
            debugLog("runDailyRefresh failed")
            return
        }
    }

    func shouldRunDailyRefresh(forKey key: String) -> Bool {
        guard let lastRefreshDate = userDefaults.object(forKey: key) as? Date else {
            debugLog("shouldRunDailyRefresh -> true (no stored date)")
            return true
        }

        let result = !calendar.isDate(lastRefreshDate, inSameDayAs: Date())
        debugLog("shouldRunDailyRefresh lastRefreshDate=\(lastRefreshDate) result=\(result)")
        return result
    }

    private func markRefreshedToday() {
        markRefreshedToday(forKey: AppDefaults.dailyPicksLastRefreshDateKey)
    }

    func markRefreshedToday(forKey key: String) {
        userDefaults.set(Date(), forKey: key)
        debugLog("markRefreshedToday")
    }

    private var stateLabel: String {
        switch state {
        case .loading:
            "loading"
        case .loaded:
            "loaded"
        case .error:
            "error"
        }
    }

    func debugLog(_ message: String) {
        #if DEBUG
        print("DiscoverViewModel:", message)
        #endif
    }
}
