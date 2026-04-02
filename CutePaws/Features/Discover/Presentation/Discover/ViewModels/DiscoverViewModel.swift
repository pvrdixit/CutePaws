import Foundation

@MainActor
@Observable
final class DiscoverViewModel {
    private(set) var items: [MediaItem] = []
    var miniMoments: [MiniMomentItem] = []
    var spotlightImagePath: String?
    var spotlightAspectRatio: Double?
    private(set) var state: DiscoverViewState = .loading
    var imageDetailViewModel: ImageDetailViewModel?
    var favoritesViewModel: FavoritesViewModel?

    private let repository: DiscoverRepository
    let spotlightRepository: SpotlightRepository
    let miniMomentRepository: MiniMomentRepository
    let breedGalleryRepository: BreedGalleryRepository
    let favoriteRepository: FavoriteRepository
    let userDefaults: UserDefaults
    let calendar: Calendar

    private var started = false

    private let dailyPicksVisibleCount: Int
    private let dailyPicksImageLimit: Int
    let spotlightImageLimit: Int
    /// Max items persisted / filled by background fetch.
    let miniMomentsStoreLimit: Int
    /// Max thumbnails on the Discover horizontal rail.
    let miniMomentsRailVisibleLimit: Int

    private var loadTask: Task<Void, Never>?
    var spotlightTask: Task<Void, Never>?
    var miniMomentsTask: Task<Void, Never>?
    private var breedGalleryTask: Task<Void, Never>?

    init(
        repository: DiscoverRepository,
        spotlightRepository: SpotlightRepository,
        miniMomentRepository: MiniMomentRepository,
        breedGalleryRepository: BreedGalleryRepository,
        favoriteRepository: FavoriteRepository,
        initialItems: [MediaItem] = [],
        initialSpotlightImagePath: String? = nil,
        initialSpotlightAspectRatio: Double? = nil,
        initialMiniMoments: [MiniMomentItem] = [],
        dailyPicksVisibleCount: Int = 20,
        dailyPicksImageLimit: Int = 20,
        spotlightImageLimit: Int = 2,
        miniMomentsStoreLimit: Int = 50,
        miniMomentsRailVisibleLimit: Int = 10,
        userDefaults: UserDefaults = .standard,
        calendar: Calendar = .current
    ) {
        self.repository = repository
        self.spotlightRepository = spotlightRepository
        self.miniMomentRepository = miniMomentRepository
        self.breedGalleryRepository = breedGalleryRepository
        self.favoriteRepository = favoriteRepository
        self.dailyPicksVisibleCount = dailyPicksVisibleCount
        self.dailyPicksImageLimit = dailyPicksImageLimit
        self.spotlightImageLimit = spotlightImageLimit
        self.miniMomentsStoreLimit = miniMomentsStoreLimit
        self.miniMomentsRailVisibleLimit = miniMomentsRailVisibleLimit
        self.userDefaults = userDefaults
        self.calendar = calendar
        items = initialItems
        miniMoments = initialMiniMoments
        spotlightImagePath = initialSpotlightImagePath
        spotlightAspectRatio = initialSpotlightAspectRatio
        state = initialItems.isEmpty ? .loading : .loaded
    }

    var miniMomentsForRail: [MiniMomentItem] {
        let saved = Array(miniMoments.prefix(miniMomentsRailVisibleLimit))
        if !saved.isEmpty { return saved }
        if let preview = MiniMomentsPreviewVideo.placeholderItem {
            return [preview]
        }
        return []
    }

    /// True while the rail is showing the bundled preview because nothing is cached yet.
    var showsMiniMomentsPreviewCaption: Bool {
        miniMoments.isEmpty && MiniMomentsPreviewVideo.placeholderItem != nil
    }

    func start() {
        guard !started else { return }
        started = true

        debugLog("start items=\(items.count) state=\(stateLabel)")
        runLoad(forceReload: false)
        startBreedGallerySync()
    }

    func retry() {
        debugLog("retry")
        runLoad(forceReload: true)
    }

    func showImageDetail(for item: MediaItem) {
        let detailItems = items.map {
            DetailMediaItem(
                id: $0.id,
                sourceID: $0.id,
                displayName: BreedExploreDisplayName.dailyPickLabel(fromDogCeoImageURL: $0.remoteURL),
                mediaType: FavoriteMediaType.inferred(fromURL: $0.remoteURL),
                imagePath: $0.localFilePath
            )
        }
        imageDetailViewModel = ImageDetailViewModel(
            items: detailItems,
            selectedItemID: item.id,
            flow: .dailyPicks,
            favoriteRepository: favoriteRepository
        )
    }

    func showSpotlightImageDetail() {
        Task { [weak self] in
            guard let self else { return }
            guard let context = await spotlightDetailContext() else { return }

            let detailItems = context.galleryOrder.map {
                DetailMediaItem(
                    id: $0.id,
                    sourceID: $0.id,
                    displayName: "",
                    mediaType: FavoriteMediaType.inferred(fromURL: $0.remoteURL),
                    imagePath: $0.localFilePath
                )
            }
            imageDetailViewModel = ImageDetailViewModel(
                items: detailItems,
                selectedItemID: context.selected.id,
                flow: .spotlight,
                favoriteRepository: favoriteRepository
            )
        }
    }

    func showMiniMomentDetail(item: MiniMomentItem) {
        Task { [weak self] in
            guard let self else { return }
            if MiniMomentsPreviewVideo.matches(item), let preview = MiniMomentsPreviewVideo.placeholderItem {
                let detail = DetailMediaItem(
                    id: preview.id,
                    sourceID: preview.id,
                    displayName: "",
                    mediaType: .video,
                    imagePath: preview.localFilePath
                )
                imageDetailViewModel = ImageDetailViewModel(
                    items: [detail],
                    selectedItemID: detail.id,
                    flow: .miniMoments,
                    favoriteRepository: favoriteRepository
                )
                return
            }

            let all = await miniMomentRepository.loadCached(limit: Int.max)
            guard all.contains(where: { $0.id == item.id }) else { return }

            // Detail reads the full cache here; the rail uses `miniMoments`, which could be stale if
            // background fills finished without publishing. Reconcile so the horizontal rail matches
            // the same newest-first list (avoids one old card on Discover while pager shows 1…50).
            await publishMiniMomentsFromRepository(note: "detail open reconcile")

            let detailItems = all.map {
                DetailMediaItem(
                    id: $0.id,
                    sourceID: $0.id,
                    displayName: "",
                    mediaType: .video,
                    imagePath: $0.localFilePath
                )
            }
            imageDetailViewModel = ImageDetailViewModel(
                items: detailItems,
                selectedItemID: item.id,
                flow: .miniMoments,
                favoriteRepository: favoriteRepository
            )
        }
    }

    func dismissImageDetail() {
        imageDetailViewModel = nil
    }

    func showFavorites() {
        favoritesViewModel = FavoritesViewModel(favoriteRepository: favoriteRepository)
    }

    func dismissFavoritesView() {
        favoritesViewModel = nil
    }

    private func startBreedGallerySync() {
        breedGalleryTask?.cancel()
        breedGalleryTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.breedGalleryRepository.syncAllThumbnails()
            } catch {
                if error is CancellationError { return }
                self.debugLog("breedGallery sync failed \(error.localizedDescription)")
            }
        }
    }

    private func runLoad(forceReload: Bool) {
        loadTask?.cancel()
        spotlightTask?.cancel()
        miniMomentsTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            await self.loadDiscoverItems(forceReload: forceReload)
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

// MARK: - Daily picks cache flow

private extension DiscoverViewModel {
    func loadDiscoverItems(forceReload: Bool = false) async {
        debugLog("loadDiscoverItems begin forceReload=\(forceReload) currentItems=\(items.count) state=\(stateLabel)")

        if forceReload {
            state = .loading
            debugLog("state -> loading because forceReload")
        }

        startSpotlight(forceReload: forceReload)
        startMiniMoments(forceReload: forceReload)
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
                markRefreshedToday(forKey: AppDefaults.dailyPicksLastRefreshDateKey)
            }
            await fillCacheToTarget()
            return
        }

        if shouldRefreshDailyPicks {
            debugLog("branch -> runDailyRefresh")
            markRefreshedToday(forKey: AppDefaults.dailyPicksLastRefreshDateKey)
            await runDailyRefresh()
        } else {
            debugLog("branch -> no fetch needed")
        }
    }

    func bootstrapInitialItems() async {
        debugLog("bootstrapInitialItems begin")
        do {
            try await fillCache(untilAtLeast: dailyPicksVisibleCount)
            items = await repository.loadCached(limit: dailyPicksVisibleCount)
            state = .loaded
            debugLog("bootstrapInitialItems loaded visible items count=\(items.count)")
            markRefreshedToday(forKey: AppDefaults.dailyPicksLastRefreshDateKey)
            await fillCacheToTarget()
        } catch let error {
            guard !(error is CancellationError) else { return }
            debugLog("bootstrapInitialItems failed")
            state = .error("Failed to load images. Try again.")
        }
    }

    func fillCache(untilAtLeast minimumCount: Int) async throws {
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

    func fillCacheToTarget() async {
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

    func runDailyRefresh() async {
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
}
