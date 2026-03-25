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

    private let visibleItemCount = 25
    private let targetStoredItemCount = 100
    private let dailyRefreshCount = 25
    private let lastRefreshDateKey = "discover.lastRefreshDate"

    init(
        repository: DiscoverRepository,
        userDefaults: UserDefaults = .standard,
        calendar: Calendar = .current
    ) {
        self.repository = repository
        self.userDefaults = userDefaults
        self.calendar = calendar
    }

    func start() {
        guard !started else { return }
        started = true

        Task {
            await loadDiscoverItems()
        }
    }

    func retry() {
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

    func clearRefreshDateForTesting() {
        userDefaults.removeObject(forKey: lastRefreshDateKey)
    }

    private func loadDiscoverItems(forceReload: Bool = false) async {
        if forceReload {
            state = .loading
        }

        await repository.prepare()

        let cachedCount = await repository.cachedCount()
        let cachedItems = await repository.loadCached(limit: visibleItemCount)

        if cachedCount >= visibleItemCount {
            items = cachedItems
            state = .loaded

            if cachedCount < targetStoredItemCount {
                Task { await completeBootstrapBackfill() }
            } else if shouldRunDailyRefresh() {
                Task { await runDailyRefresh() }
            }

            return
        }

        await bootstrapInitialItems()
    }

    private func bootstrapInitialItems() async {
        do {
            try await fillCache(untilAtLeast: visibleItemCount)
            items = await repository.loadCached(limit: visibleItemCount)
            state = .loaded
            Task { await completeBootstrapBackfill(markRefreshDate: true) }
        } catch {
            state = .error("Failed to load images. Try again.")
        }
    }

    private func fillCache(untilAtLeast minimumCount: Int) async throws {
        var attempts = 0

        while attempts < 5 {
            let currentCount = await repository.cachedCount()
            guard currentCount < minimumCount else { return }

            try await repository.fetchAndStore(count: minimumCount - currentCount)
            attempts += 1
        }

        if await repository.cachedCount() < minimumCount {
            throw URLError(.cannotLoadFromNetwork)
        }
    }

    private func completeBootstrapBackfill(markRefreshDate: Bool = false) async {
        var stalledAttempts = 0

        while stalledAttempts < 3 {
            let currentCount = await repository.cachedCount()
            guard currentCount < targetStoredItemCount else { break }

            do {
                try await repository.fetchAndStore(count: min(dailyRefreshCount, targetStoredItemCount - currentCount))
            } catch {
                return
            }

            let updatedCount = await repository.cachedCount()
            stalledAttempts = updatedCount <= currentCount ? stalledAttempts + 1 : 0
        }

        items = await repository.loadCached(limit: visibleItemCount)

        if markRefreshDate, await repository.cachedCount() >= targetStoredItemCount {
            userDefaults.set(Date(), forKey: lastRefreshDateKey)
        }
    }

    private func runDailyRefresh() async {
        do {
            try await repository.fetchAndStore(count: dailyRefreshCount)
            await repository.trimToLatest(maxCount: targetStoredItemCount)
            items = await repository.loadCached(limit: visibleItemCount)
            userDefaults.set(Date(), forKey: lastRefreshDateKey)
        } catch {
            return
        }
    }

    private func shouldRunDailyRefresh() -> Bool {
        guard let lastRefreshDate = userDefaults.object(forKey: lastRefreshDateKey) as? Date else {
            return true
        }

        return !calendar.isDate(lastRefreshDate, inSameDayAs: Date())
    }
}
