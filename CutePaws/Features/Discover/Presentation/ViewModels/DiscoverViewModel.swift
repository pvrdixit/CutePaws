import Combine
import Foundation

@MainActor
final class DiscoverViewModel: ObservableObject {
    @Published private(set) var items: [MediaItem] = []
    @Published private(set) var state: DiscoverViewState = .loading
    @Published var imageDetailViewModel: ImageDetailViewModel?

    private let repository: DiscoverRepository
    private let userDefaults: UserDefaults
    private let calendar: Calendar

    private var started = false

    private let visibleItemCount: Int
    private let targetStoredItemCount = 40
    private let dailyRefreshCount = 20
    private let lastRefreshDateKey = "discover.lastRefreshDate"

    init(
        repository: DiscoverRepository,
        initialItems: [MediaItem] = [],
        visibleItemCount: Int = 20,
        userDefaults: UserDefaults = .standard,
        calendar: Calendar = .current
    ) {
        self.repository = repository
        self.visibleItemCount = visibleItemCount
        self.userDefaults = userDefaults
        self.calendar = calendar
        items = initialItems
        state = initialItems.isEmpty ? .loading : .loaded
    }

    func start() {
        guard !started else { return }
        started = true

        debugLog("start items=\(items.count) state=\(stateLabel)")

        Task {
            await loadDiscoverItems()
        }
    }

    func retry() {
        debugLog("retry")
        Task {
            await loadDiscoverItems(forceReload: true)
        }
    }

    func showImageDetail(for item: MediaItem) {
        imageDetailViewModel = ImageDetailViewModel(items: items, selectedItemID: item.id)
    }

    func dismissImageDetail() {
        imageDetailViewModel = nil
    }

    private func loadDiscoverItems(forceReload: Bool = false) async {
        debugLog("loadDiscoverItems begin forceReload=\(forceReload) currentItems=\(items.count) state=\(stateLabel)")

        if forceReload {
            state = .loading
            debugLog("state -> loading because forceReload")
        }

        let cachedItems = await repository.loadCached(limit: visibleItemCount)
        debugLog("pre-prepare cachedItems=\(cachedItems.count)")

        if !cachedItems.isEmpty {
            items = cachedItems
            state = .loaded
            debugLog("applied pre-prepare cached items count=\(cachedItems.count)")
        }

        await repository.prepare()
        debugLog("repository.prepare completed")

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
            Task { await fillCacheToTarget() }
            return
        }

        if shouldRefreshToday {
            debugLog("branch -> runDailyRefresh")
            markRefreshedToday()
            Task { await runDailyRefresh() }
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
            Task { await fillCacheToTarget() }
        } catch {
            debugLog("bootstrapInitialItems failed")
            state = .error("Failed to load images. Try again.")
        }
    }

    private func fillCache(untilAtLeast minimumCount: Int) async throws {
        var attempts = 0

        while attempts < 5 {
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
        let shouldRefreshVisibleItems = items.count < visibleItemCount
        var stalledAttempts = 0

        debugLog("fillCacheToTarget begin visibleItems=\(items.count) shouldRefreshVisibleItems=\(shouldRefreshVisibleItems)")

        while stalledAttempts < 3 {
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
        guard let lastRefreshDate = userDefaults.object(forKey: lastRefreshDateKey) as? Date else {
            debugLog("shouldRunDailyRefresh -> true (no stored date)")
            return true
        }

        let result = !calendar.isDate(lastRefreshDate, inSameDayAs: Date())
        debugLog("shouldRunDailyRefresh lastRefreshDate=\(lastRefreshDate) result=\(result)")
        return result
    }

    private func markRefreshedToday() {
        userDefaults.set(Date(), forKey: lastRefreshDateKey)
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

    private func debugLog(_ message: String) {
        #if DEBUG
        print("DiscoverViewModel:", message)
        #endif
    }
}
