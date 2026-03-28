import Foundation

extension DiscoverViewModel {
    private func currentSpotlightDisplayItem() async -> SpotlightItem? {
        // Store returns newest-first; taking `last` gives FIFO display from oldest.
        await spotlightRepository.loadCached(limit: spotlightImageLimit).last
    }

    func startSpotlight(forceReload: Bool) {
        spotlightTask?.cancel()
        spotlightTask = Task { [weak self] in
            guard let self else { return }
            await self.loadSpotlight(forceReload: forceReload)
        }
    }

    func loadSpotlight(forceReload: Bool) async {
        await spotlightRepository.prepare()
        guard !Task.isCancelled else { return }

        if let firstItem = await currentSpotlightDisplayItem() {
            guard !Task.isCancelled else { return }
            spotlightImagePath = firstItem.localFilePath
            spotlightAspectRatio = firstItem.aspectRatio
        }

        let cachedCount = await spotlightRepository.cachedCount()
        let shouldRefreshToday = shouldRunDailyRefresh(forKey: AppDefaults.spotlightLastRefreshDateKey)

        if cachedCount == 0 {
            await bootstrapSpotlight()
            return
        }

        if cachedCount < spotlightImageLimit {
            if shouldRefreshToday {
                markRefreshedToday(forKey: AppDefaults.spotlightLastRefreshDateKey)
            }
            await fillSpotlightCacheToTarget()
            return
        }

        if shouldRefreshToday || forceReload {
            markRefreshedToday(forKey: AppDefaults.spotlightLastRefreshDateKey)
            await runSpotlightDailyRefresh()
        }
    }

    func bootstrapSpotlight() async {
        do {
            try await fillSpotlightCache(untilAtLeast: 1)
            guard !Task.isCancelled else { return }
            let first = await currentSpotlightDisplayItem()
            spotlightImagePath = first?.localFilePath
            spotlightAspectRatio = first?.aspectRatio
            markRefreshedToday(forKey: AppDefaults.spotlightLastRefreshDateKey)
            await fillSpotlightCacheToTarget()
        } catch {
            debugLog("bootstrapSpotlight failed")
        }
    }

    func fillSpotlightCache(untilAtLeast minimumCount: Int) async throws {
        var attempts = 0
        while attempts < 5 {
            guard !Task.isCancelled else { throw CancellationError() }
            let currentCount = await spotlightRepository.cachedCount()
            guard currentCount < minimumCount else { return }
            try await spotlightRepository.fetchAndStore(count: minimumCount - currentCount)
            attempts += 1
        }

        if await spotlightRepository.cachedCount() < minimumCount {
            throw URLError(.cannotLoadFromNetwork)
        }
    }

    func fillSpotlightCacheToTarget() async {
        var stalledAttempts = 0
        while stalledAttempts < 3 {
            guard !Task.isCancelled else { return }
            let currentCount = await spotlightRepository.cachedCount()
            guard currentCount < spotlightImageLimit else { break }

            do {
                try await spotlightRepository.fetchAndStore(
                    count: min(spotlightImageLimit, spotlightImageLimit - currentCount)
                )
            } catch {
                return
            }

            let updatedCount = await spotlightRepository.cachedCount()
            stalledAttempts = updatedCount <= currentCount ? stalledAttempts + 1 : 0
        }

        guard !Task.isCancelled else { return }
        let first = await currentSpotlightDisplayItem()
        spotlightImagePath = first?.localFilePath
        spotlightAspectRatio = first?.aspectRatio
    }

    func runSpotlightDailyRefresh() async {
        guard !Task.isCancelled else { return }
        do {
            try await spotlightRepository.fetchAndStore(count: spotlightImageLimit)
            await spotlightRepository.trimToLatest(maxCount: spotlightImageLimit)
            guard !Task.isCancelled else { return }
            let first = await currentSpotlightDisplayItem()
            spotlightImagePath = first?.localFilePath
            spotlightAspectRatio = first?.aspectRatio
        } catch {
            return
        }
    }
}

