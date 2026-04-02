import Foundation

extension DiscoverViewModel {
    /// Newest-first from the store → oldest-first baseline when building cycle order.
    static func orderedSpotlightItems(_ items: [SpotlightItem]) -> [SpotlightItem] {
        Array(items.reversed())
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

        let cachedCount = await spotlightRepository.cachedCount()
        let shouldRefreshToday = shouldRunDailyRefresh(forKey: AppDefaults.spotlightLastRefreshDateKey)

        if cachedCount == 0 {
            await bootstrapSpotlight()
            await applySpotlightForToday()
            return
        }

        await applySpotlightForToday()

        if cachedCount < spotlightImageLimit {
            if shouldRefreshToday {
                markRefreshedToday(forKey: AppDefaults.spotlightLastRefreshDateKey)
            }
            await fillSpotlightCacheToTarget()
            await applySpotlightForToday()
            return
        }

        if shouldRefreshToday || forceReload {
            markRefreshedToday(forKey: AppDefaults.spotlightLastRefreshDateKey)
            await runSpotlightDailyRefresh()
        }

        await applySpotlightForToday()
    }

    func bootstrapSpotlight() async {
        do {
            try await fillSpotlightCache(untilAtLeast: 1)
            guard !Task.isCancelled else { return }
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
                rotateSpotlightCycleFirstToLast()
                await applySpotlightForToday()
                return
            }

            let updatedCount = await spotlightRepository.cachedCount()
            stalledAttempts = updatedCount <= currentCount ? stalledAttempts + 1 : 0
        }

        guard !Task.isCancelled else { return }
        await applySpotlightForToday()
    }

    func runSpotlightDailyRefresh() async {
        guard !Task.isCancelled else { return }
        do {
            try await spotlightRepository.fetchAndStore(count: spotlightImageLimit)
            await spotlightRepository.trimToLatest(maxCount: spotlightImageLimit)
            guard !Task.isCancelled else { return }
            await applySpotlightForToday()
        } catch {
            rotateSpotlightCycleFirstToLast()
            await applySpotlightForToday()
        }
    }

    /// Today’s spotlight + gallery order for the detail flow.
    func spotlightDetailContext() async -> (selected: SpotlightItem, galleryOrder: [SpotlightItem])? {
        let items = await spotlightRepository.loadCached(limit: spotlightImageLimit)
        guard !items.isEmpty else { return nil }
        let byId = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        let orderIDs = mergedSpotlightCycleOrderIDs(cachedItems: items)
        guard !orderIDs.isEmpty else { return nil }
        let galleryOrder = orderIDs.compactMap { byId[$0] }
        guard let selectedId = spotlightTodaySelectedID(orderIDs: orderIDs), let selected = byId[selectedId] else {
            return nil
        }
        return (selected, galleryOrder)
    }

    // MARK: - Daily pick + cycle order

    private func applySpotlightForToday() async {
        let items = await spotlightRepository.loadCached(limit: spotlightImageLimit)
        guard !items.isEmpty else {
            spotlightImagePath = nil
            spotlightAspectRatio = nil
            return
        }
        let byId = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        let orderIDs = mergedSpotlightCycleOrderIDs(cachedItems: items)
        guard !orderIDs.isEmpty, let selectedId = spotlightTodaySelectedID(orderIDs: orderIDs), let item = byId[selectedId] else {
            return
        }
        spotlightImagePath = item.localFilePath
        spotlightAspectRatio = item.aspectRatio
    }

    private func spotlightTodaySelectedID(orderIDs: [String]) -> String? {
        guard !orderIDs.isEmpty else { return nil }
        let slot = spotlightDaySlotIndex(itemCount: orderIDs.count)
        return orderIDs[slot]
    }

    /// Stable for the whole calendar day: same slot until midnight, then advances with the day index.
    private func spotlightDaySlotIndex(itemCount: Int) -> Int {
        guard itemCount > 0 else { return 0 }
        let todayStart = calendar.startOfDay(for: Date())
        let refStart = calendar.startOfDay(for: Date(timeIntervalSince1970: 0))
        let days = calendar.dateComponents([.day], from: refStart, to: todayStart).day ?? 0
        let slot = days % itemCount
        return slot >= 0 ? slot : slot + itemCount
    }

    /// Keeps saved order in sync with cache; new items append in oldest-first order.
    private func mergedSpotlightCycleOrderIDs(cachedItems: [SpotlightItem]) -> [String] {
        let byId = Dictionary(uniqueKeysWithValues: cachedItems.map { ($0.id, $0) })
        var order = userDefaults.stringArray(forKey: AppDefaults.spotlightCycleOrderIDsKey) ?? []
        order = order.filter { byId[$0] != nil }

        let oldestFirst = Self.orderedSpotlightItems(cachedItems)
        for item in oldestFirst where !order.contains(item.id) {
            order.append(item.id)
        }

        userDefaults.set(order, forKey: AppDefaults.spotlightCycleOrderIDsKey)
        return order
    }

    private func rotateSpotlightCycleFirstToLast() {
        var order = userDefaults.stringArray(forKey: AppDefaults.spotlightCycleOrderIDsKey) ?? []
        guard order.count > 1 else { return }
        let first = order.removeFirst()
        order.append(first)
        userDefaults.set(order, forKey: AppDefaults.spotlightCycleOrderIDsKey)
    }
}
