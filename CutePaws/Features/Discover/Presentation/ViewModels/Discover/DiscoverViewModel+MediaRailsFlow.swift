import Foundation

extension DiscoverViewModel {
    func startMiniMoments(forceReload: Bool) {
        miniMomentsTask?.cancel()
        miniMomentsTask = Task { [weak self] in
            guard let self else { return }
            await self.loadMiniMoments(forceReload: forceReload)
        }
    }

    func startGifs(forceReload: Bool) {
        gifsTask?.cancel()
        gifsTask = Task { [weak self] in
            guard let self else { return }
            await self.loadGifs(forceReload: forceReload)
        }
    }

    private func loadMiniMoments(forceReload: Bool) async {
        await miniMomentRepository.prepare()
        guard !Task.isCancelled else { return }

        let cachedItems = await miniMomentRepository.loadCached(limit: miniMomentsImageLimit)
        if !cachedItems.isEmpty {
            miniMoments = cachedItems
        }

        let cachedCount = await miniMomentRepository.cachedCount()
        let shouldRefresh = shouldRunDailyRefresh(forKey: AppDefaults.miniMomentsLastRefreshDateKey)

        if cachedCount == 0 {
            await bootstrapMiniMoments()
            return
        }

        if cachedCount < miniMomentsImageLimit {
            if shouldRefresh {
                markRefreshedToday(forKey: AppDefaults.miniMomentsLastRefreshDateKey)
            }
            await fillMiniMomentsToTarget()
            return
        }

        if shouldRefresh || forceReload {
            markRefreshedToday(forKey: AppDefaults.miniMomentsLastRefreshDateKey)
            await refreshMiniMomentsDaily()
        }
    }

    private func loadGifs(forceReload: Bool) async {
        await animatedGifRepository.prepare()
        guard !Task.isCancelled else { return }

        let cachedItems = await animatedGifRepository.loadCached(limit: gifsImageLimit)
        if !cachedItems.isEmpty {
            gifs = cachedItems
        }

        let cachedCount = await animatedGifRepository.cachedCount()
        let shouldRefresh = shouldRunDailyRefresh(forKey: AppDefaults.gifsLastRefreshDateKey)

        if cachedCount == 0 {
            await bootstrapGifs()
            return
        }

        if cachedCount < gifsImageLimit {
            if shouldRefresh {
                markRefreshedToday(forKey: AppDefaults.gifsLastRefreshDateKey)
            }
            await fillGifsToTarget()
            return
        }

        if shouldRefresh || forceReload {
            markRefreshedToday(forKey: AppDefaults.gifsLastRefreshDateKey)
            await refreshGifsDaily()
        }
    }

    private func bootstrapMiniMoments() async {
        do {
            try await fillMiniMoments(untilAtLeast: 1)
            guard !Task.isCancelled else { return }
            miniMoments = await miniMomentRepository.loadCached(limit: miniMomentsImageLimit)
            markRefreshedToday(forKey: AppDefaults.miniMomentsLastRefreshDateKey)
            await fillMiniMomentsToTarget()
        } catch {
            debugLog("bootstrapMiniMoments failed")
        }
    }

    private func bootstrapGifs() async {
        do {
            try await fillGifs(untilAtLeast: 1)
            guard !Task.isCancelled else { return }
            gifs = await animatedGifRepository.loadCached(limit: gifsImageLimit)
            markRefreshedToday(forKey: AppDefaults.gifsLastRefreshDateKey)
            await fillGifsToTarget()
        } catch {
            debugLog("bootstrapGifs failed")
        }
    }

    private func fillMiniMoments(untilAtLeast minimumCount: Int) async throws {
        var attempts = 0
        while attempts < 5 {
            guard !Task.isCancelled else { throw CancellationError() }
            let currentCount = await miniMomentRepository.cachedCount()
            guard currentCount < minimumCount else { return }
            try await miniMomentRepository.fetchAndStore(count: minimumCount - currentCount)
            attempts += 1
        }

        if await miniMomentRepository.cachedCount() < minimumCount {
            throw URLError(.cannotLoadFromNetwork)
        }
    }

    private func fillGifs(untilAtLeast minimumCount: Int) async throws {
        var attempts = 0
        while attempts < 5 {
            guard !Task.isCancelled else { throw CancellationError() }
            let currentCount = await animatedGifRepository.cachedCount()
            guard currentCount < minimumCount else { return }
            try await animatedGifRepository.fetchAndStore(count: minimumCount - currentCount)
            attempts += 1
        }

        if await animatedGifRepository.cachedCount() < minimumCount {
            throw URLError(.cannotLoadFromNetwork)
        }
    }

    private func fillMiniMomentsToTarget() async {
        var stalledAttempts = 0
        while stalledAttempts < 3 {
            guard !Task.isCancelled else { return }
            let currentCount = await miniMomentRepository.cachedCount()
            guard currentCount < miniMomentsImageLimit else { break }

            do {
                try await miniMomentRepository.fetchAndStore(
                    count: min(miniMomentsImageLimit, miniMomentsImageLimit - currentCount)
                )
            } catch {
                return
            }

            let updatedCount = await miniMomentRepository.cachedCount()
            stalledAttempts = updatedCount <= currentCount ? stalledAttempts + 1 : 0
        }

        guard !Task.isCancelled else { return }
        miniMoments = await miniMomentRepository.loadCached(limit: miniMomentsImageLimit)
    }

    private func fillGifsToTarget() async {
        var stalledAttempts = 0
        while stalledAttempts < 3 {
            guard !Task.isCancelled else { return }
            let currentCount = await animatedGifRepository.cachedCount()
            guard currentCount < gifsImageLimit else { break }

            do {
                try await animatedGifRepository.fetchAndStore(
                    count: min(gifsImageLimit, gifsImageLimit - currentCount)
                )
            } catch {
                return
            }

            let updatedCount = await animatedGifRepository.cachedCount()
            stalledAttempts = updatedCount <= currentCount ? stalledAttempts + 1 : 0
        }

        guard !Task.isCancelled else { return }
        gifs = await animatedGifRepository.loadCached(limit: gifsImageLimit)
    }

    private func refreshMiniMomentsDaily() async {
        do {
            try await miniMomentRepository.fetchAndStore(count: miniMomentsImageLimit)
            await miniMomentRepository.trimToLatest(maxCount: miniMomentsImageLimit)
            guard !Task.isCancelled else { return }
            miniMoments = await miniMomentRepository.loadCached(limit: miniMomentsImageLimit)
        } catch {
            return
        }
    }

    private func refreshGifsDaily() async {
        do {
            try await animatedGifRepository.fetchAndStore(count: gifsImageLimit)
            await animatedGifRepository.trimToLatest(maxCount: gifsImageLimit)
            guard !Task.isCancelled else { return }
            gifs = await animatedGifRepository.loadCached(limit: gifsImageLimit)
        } catch {
            return
        }
    }
}

