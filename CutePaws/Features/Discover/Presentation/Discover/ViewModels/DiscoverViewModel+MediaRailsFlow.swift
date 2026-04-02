import Foundation
import os

private enum DiscoverRailsLog {
    static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "CutePaws", category: "DiscoverRails")
}

extension DiscoverViewModel {
    func startMiniMoments(forceReload: Bool) {
        miniMomentsTask?.cancel()
        DiscoverRailsLog.log.info("MiniMoments task scheduled forceReload=\(forceReload) targetStore=\(self.miniMomentsStoreLimit)")
        miniMomentsTask = Task { [weak self] in
            guard let self else { return }
            await self.loadMiniMoments(forceReload: forceReload)
        }
    }

    private func loadMiniMoments(forceReload: Bool) async {
        DiscoverRailsLog.log.info("MiniMoments pipeline begin")
        await miniMomentRepository.prepare()
        guard !Task.isCancelled else { return }

        let cachedItems = await miniMomentRepository.loadCached(limit: miniMomentsStoreLimit)
        if !cachedItems.isEmpty {
            await publishMiniMoments(cachedItems, note: "show cached")
        }

        let cachedCount = await miniMomentRepository.cachedCount()
        let shouldRefresh = shouldRunDailyRefresh(forKey: AppDefaults.miniMomentsLastRefreshDateKey)

        if cachedCount == 0 {
            await bootstrapMiniMoments()
            return
        }

        if cachedCount < miniMomentsStoreLimit {
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

        let finalStore = await miniMomentRepository.cachedCount()
        DiscoverRailsLog.log.info("MiniMoments pipeline idle published=\(self.miniMoments.count) store=\(finalStore) targetStore=\(self.miniMomentsStoreLimit)")
    }

    private func publishMiniMoments(_ items: [MiniMomentItem], note: String) async {
        miniMoments = items
        let store = await miniMomentRepository.cachedCount()
        let railSlots = min(items.count, miniMomentsRailVisibleLimit)
        DiscoverRailsLog.log.info(
            "MiniMoments [\(note)] published=\(items.count) railSlots=\(railSlots) store=\(store) targetStore=\(self.miniMomentsStoreLimit)"
        )
    }

    private func bootstrapMiniMoments() async {
        do {
            try await fillMiniMoments(untilAtLeast: 1)
            guard !Task.isCancelled else { return }
            await publishMiniMoments(
                await miniMomentRepository.loadCached(limit: miniMomentsStoreLimit),
                note: "bootstrap load"
            )
            markRefreshedToday(forKey: AppDefaults.miniMomentsLastRefreshDateKey)
            await fillMiniMomentsToTarget()
        } catch {
            debugLog("bootstrapMiniMoments failed")
            DiscoverRailsLog.log.error("MiniMoments bootstrap failed")
        }
    }

    private func fillMiniMoments(untilAtLeast minimumCount: Int) async throws {
        var attempts = 0
        while attempts < 5 {
            guard !Task.isCancelled else { throw CancellationError() }
            let currentCount = await miniMomentRepository.cachedCount()
            guard currentCount < minimumCount else { return }
            DiscoverRailsLog.log.info("MiniMoments fetchAndStore need=\(minimumCount - currentCount)")
            try await miniMomentRepository.fetchAndStore(count: minimumCount - currentCount)
            attempts += 1
        }

        if await miniMomentRepository.cachedCount() < minimumCount {
            throw URLError(.cannotLoadFromNetwork)
        }
    }

    private func fillMiniMomentsToTarget() async {
        var stalledAttempts = 0
        while stalledAttempts < 3 {
            guard !Task.isCancelled else { return }
            let currentCount = await miniMomentRepository.cachedCount()
            guard currentCount < miniMomentsStoreLimit else { break }

            let batch = min(miniMomentsStoreLimit, miniMomentsStoreLimit - currentCount)
            DiscoverRailsLog.log.info("MiniMoments fillToTarget fetchAndStore count=\(batch)")
            do {
                try await miniMomentRepository.fetchAndStore(count: batch)
            } catch {
                DiscoverRailsLog.log.error("MiniMoments fillToTarget fetch failed")
                return
            }

            let updatedCount = await miniMomentRepository.cachedCount()
            stalledAttempts = updatedCount <= currentCount ? stalledAttempts + 1 : 0

            // Publish after each successful batch so the rail grows while downloads run (avoids “nothing then 50” confusion).
            await publishMiniMoments(
                await miniMomentRepository.loadCached(limit: miniMomentsStoreLimit),
                note: "fillToTarget progress"
            )
        }

        guard !Task.isCancelled else { return }
        await publishMiniMoments(
            await miniMomentRepository.loadCached(limit: miniMomentsStoreLimit),
            note: "fillToTarget done"
        )
    }

    private func refreshMiniMomentsDaily() async {
        DiscoverRailsLog.log.info("MiniMoments daily refresh fetch count=\(self.miniMomentsStoreLimit)")
        do {
            try await miniMomentRepository.fetchAndStore(count: miniMomentsStoreLimit)
            await miniMomentRepository.trimToLatest(maxCount: miniMomentsStoreLimit)
            guard !Task.isCancelled else { return }
            await publishMiniMoments(
                await miniMomentRepository.loadCached(limit: miniMomentsStoreLimit),
                note: "daily refresh"
            )
        } catch {
            DiscoverRailsLog.log.error("MiniMoments daily refresh failed")
            return
        }
    }

    /// Reloads `miniMoments` from SwiftData (same source as detail). Used so the rail cannot stay stale while the pager shows the full cache.
    func publishMiniMomentsFromRepository(note: String) async {
        await publishMiniMoments(
            await miniMomentRepository.loadCached(limit: miniMomentsStoreLimit),
            note: note
        )
    }
}
