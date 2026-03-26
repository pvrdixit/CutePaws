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

    private let visibleItemCount: Int
    private let targetStoredItemCount = 40
    private let dailyRefreshCount = 20
    private let lastRefreshDateKey = "discover.lastRefreshDate"
    let spotlightLastRefreshDateKey = "spotlight.lastRefreshDate"
    let spotlightTargetStoredItemCount = 2
    let spotlightDailyRefreshCount = 1

    private var loadTask: Task<Void, Never>?
    var spotlightTask: Task<Void, Never>?

    init(
        repository: DiscoverRepository,
        spotlightRepository: SpotlightRepository,
        initialItems: [MediaItem] = [],
        initialSpotlightImagePath: String? = nil,
        initialSpotlightAspectRatio: Double? = nil,
        visibleItemCount: Int = 20,
        userDefaults: UserDefaults = .standard,
        calendar: Calendar = .current
    ) {
        self.repository = repository
        self.spotlightRepository = spotlightRepository
        self.visibleItemCount = visibleItemCount
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

        let cachedItems = await repository.loadCached(limit: visibleItemCount)
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
        let refreshedCachedItems = await repository.loadCached(limit: visibleItemCount)
        let shouldRefreshToday = shouldRunDailyRefresh()
        debugLog("post-prepare cachedCount=\(cachedCount) refreshedVisible=\(refreshedCachedItems.count) shouldRefreshToday=\(shouldRefreshToday)")

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

        if cachedCount < targetStoredItemCount {
            debugLog("branch -> fillCacheToTarget currentCount=\(cachedCount) target=\(targetStoredItemCount)")
            if shouldRefreshToday {
                markRefreshedToday()
            }
            await fillCacheToTarget()
            return
        }

        if shouldRefreshToday {
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
            try await fillCache(untilAtLeast: visibleItemCount)
            items = await repository.loadCached(limit: visibleItemCount)
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
        let shouldRefreshVisibleItems = items.count < visibleItemCount
        var stalledAttempts = 0

        debugLog("fillCacheToTarget begin visibleItems=\(items.count) shouldRefreshVisibleItems=\(shouldRefreshVisibleItems)")

        while stalledAttempts < 3 {
            guard !Task.isCancelled else { return }
            let currentCount = await repository.cachedCount()
            debugLog("fillCacheToTarget loop currentCount=\(currentCount) target=\(targetStoredItemCount) stalledAttempts=\(stalledAttempts)")
            guard currentCount < targetStoredItemCount else { break }

            do {
                try await repository.fetchAndStore(count: min(dailyRefreshCount, targetStoredItemCount - currentCount))
            } catch {
                debugLog("fillCacheToTarget fetch failed")
                return
            }

            let updatedCount = await repository.cachedCount()
            debugLog("fillCacheToTarget updatedCount=\(updatedCount)")
            stalledAttempts = updatedCount <= currentCount ? stalledAttempts + 1 : 0
        }

        if shouldRefreshVisibleItems {
            items = await repository.loadCached(limit: visibleItemCount)
            debugLog("fillCacheToTarget refreshed visible items count=\(items.count)")
        }

        debugLog("fillCacheToTarget end")
    }

    private func runDailyRefresh() async {
        guard !Task.isCancelled else { return }
        debugLog("runDailyRefresh begin dailyRefreshCount=\(dailyRefreshCount)")
        do {
            try await repository.fetchAndStore(count: dailyRefreshCount)
            await repository.trimToLatest(maxCount: targetStoredItemCount)
            userDefaults.set(Date(), forKey: lastRefreshDateKey)
            let finalCount = await repository.cachedCount()
            debugLog("runDailyRefresh end finalCount=\(finalCount)")
        } catch {
            debugLog("runDailyRefresh failed")
            return
        }
    }

    private func shouldRunDailyRefresh() -> Bool {
        shouldRunDailyRefresh(forKey: lastRefreshDateKey)
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
        markRefreshedToday(forKey: lastRefreshDateKey)
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
