//
//  ShelfStateViewModel.swift
//  boringNotch
//
//  Created by Alexander on 2025-10-09.

import Foundation
import AppKit
import Defaults

struct ConversionOffer: Identifiable {
    let id = UUID()
    let items: [ShelfItem]
    let targets: [ConversionTarget]
}

@MainActor
final class ShelfStateViewModel: ObservableObject {
    static let shared = ShelfStateViewModel()

    @Published private(set) var items: [ShelfItem] = [] {
        didSet { ShelfPersistenceService.shared.save(items) }
    }

    @Published var isLoading: Bool = false
    @Published var conversionOffer: ConversionOffer?
    @Published var isConverting: Bool = false

    var isEmpty: Bool { items.isEmpty }

    // Queue for deferred bookmark updates to avoid publishing during view updates
    private var pendingBookmarkUpdates: [ShelfItem.ID: Data] = [:]
    private var updateTask: Task<Void, Never>?

    private init() {
        items = ShelfPersistenceService.shared.load()
    }


    func add(_ newItems: [ShelfItem]) {
        guard !newItems.isEmpty else { return }
        var merged = items
        // Deduplicate by identityKey while preserving order (existing first)
        var seen: Set<String> = Set(merged.map { $0.identityKey })
        for it in newItems {
            let key = it.identityKey
            if !seen.contains(key) {
                merged.append(it)
                seen.insert(key)
            }
        }
        items = merged
    }

    func remove(_ item: ShelfItem) {
        item.cleanupStoredData()
        items.removeAll { $0.id == item.id }
    }

    func updateBookmark(for item: ShelfItem, bookmark: Data) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        if case .file = items[idx].kind {
            items[idx].kind = .file(bookmark: bookmark)
        }
    }

    private func scheduleDeferredBookmarkUpdate(for item: ShelfItem, bookmark: Data) {
        pendingBookmarkUpdates[item.id] = bookmark
        
        // Cancel existing task and schedule a new one
        updateTask?.cancel()
        updateTask = Task { @MainActor [weak self] in
            await Task.yield()
            
            guard let self = self else { return }
            
            for (itemID, bookmarkData) in self.pendingBookmarkUpdates {
                if let idx = self.items.firstIndex(where: { $0.id == itemID }),
                   case .file = self.items[idx].kind {
                    self.items[idx].kind = .file(bookmark: bookmarkData)
                }
            }
            
            self.pendingBookmarkUpdates.removeAll()
        }
    }


    func load(_ providers: [NSItemProvider]) {
        guard !providers.isEmpty else { return }
        isLoading = true
        Task { [weak self] in
            let dropped = await ShelfDropService.items(from: providers)
            await MainActor.run {
                self?.add(dropped)
                self?.isLoading = false
                self?.offerConversion(for: dropped)
            }
        }
    }

    // MARK: - Conversion offer

    private func offerConversion(for dropped: [ShelfItem]) {
        guard Defaults[.offerConversionOnDrop], !dropped.isEmpty else { return }
        let fileItems = dropped.filter { if case .file = $0.kind { return true } else { return false } }
        // Only offer when everything dropped is a file; mixed drops stay untouched
        guard fileItems.count == dropped.count else { return }

        let urls = resolveFileURLs(for: fileItems)
        guard urls.count == fileItems.count else { return }
        let targets = FileConversionService.shared.targets(for: urls)
        guard !targets.isEmpty else { return }

        let offer = ConversionOffer(items: fileItems, targets: targets)
        conversionOffer = offer

        Task { [weak self] in
            try? await Task.sleep(for: .seconds(15))
            guard let self, self.conversionOffer?.id == offer.id, !self.isConverting else { return }
            self.conversionOffer = nil
        }
    }

    func dismissConversionOffer() {
        conversionOffer = nil
    }

    func convert(_ offer: ConversionOffer, to target: ConversionTarget) {
        guard !isConverting else { return }
        isConverting = true
        let urls = resolveFileURLs(for: offer.items)

        Task { [weak self] in
            defer {
                self?.isConverting = false
                self?.conversionOffer = nil
            }
            do {
                let outputs = try await urls.accessSecurityScopedResources { scoped in
                    try await FileConversionService.shared.convert(scoped, to: target)
                }
                let newItems: [ShelfItem] = outputs.compactMap { url in
                    guard let bookmark = try? Bookmark(url: url) else { return nil }
                    return ShelfItem(kind: .file(bookmark: bookmark.data), isTemporary: true)
                }
                self?.add(newItems)
            } catch {
                let alert = NSAlert()
                alert.messageText = "Conversion failed"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.runModal()
            }
        }
    }

    func cleanupInvalidItems() {
        Task { [weak self] in
            guard let self else { return }
            var keep: [ShelfItem] = []
            for item in self.items {
                switch item.kind {
                case .file(let data):
                    let bookmark = Bookmark(data: data)
                    if await bookmark.validate() {
                        keep.append(item)
                    } else {
                        item.cleanupStoredData()
                    }
                default:
                    keep.append(item)
                }
            }
            await MainActor.run { self.items = keep }
        }
    }


    func resolveFileURL(for item: ShelfItem) -> URL? {
        guard case .file(let bookmarkData) = item.kind else { return nil }
        let bookmark = Bookmark(data: bookmarkData)
        let result = bookmark.resolve()
        if let refreshed = result.refreshedData, refreshed != bookmarkData {
            NSLog("Bookmark for \(item) stale; refreshing")
            scheduleDeferredBookmarkUpdate(for: item, bookmark: refreshed)
        }
        return result.url
    }

    func resolveAndUpdateBookmark(for item: ShelfItem) -> URL? {
        guard case .file(let bookmarkData) = item.kind else { return nil }
        let bookmark = Bookmark(data: bookmarkData)
        let result = bookmark.resolve()
        if let refreshed = result.refreshedData, refreshed != bookmarkData {
            NSLog("Bookmark for \(item) stale; refreshing")
            updateBookmark(for: item, bookmark: refreshed)
        }
        return result.url
    }

    func resolveFileURLs(for items: [ShelfItem]) -> [URL] {
        var urls: [URL] = []
        for it in items {
            if let u = resolveFileURL(for: it) { urls.append(u) }
        }
        return urls
    }
}
