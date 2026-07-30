//
//  ImageCache.swift
//  BookShare
//
//  In-memory (NSCache) + on-disk cache for downloaded cover art, so
//  re-opening a book or scrolling Shelf/Discover doesn't re-fetch the same
//  cover image repeatedly.
//

import UIKit

actor ImageCache {
    static let shared = ImageCache()

    private let memoryCache = NSCache<NSURL, UIImage>()
    private let diskCacheURL: URL
    private let fileManager = FileManager.default
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]

    init() {
        memoryCache.countLimit = 200
        memoryCache.totalCostLimit = 100 * 1024 * 1024 // 100 MB

        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskCacheURL = caches.appendingPathComponent("BookCoverCache", isDirectory: true)
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }

    /// Returns a cached image immediately if available, otherwise downloads,
    /// caches, and returns it. Deduplicates concurrent requests for the same URL.
    func image(for url: URL) async -> UIImage? {
        if let cached = memoryCache.object(forKey: url as NSURL) {
            return cached
        }

        if let existing = inFlight[url] {
            return await existing.value
        }

        let task = Task<UIImage?, Never> { [weak self] in
            guard let self else { return nil }
            if let onDisk = await self.readFromDisk(url: url) {
                await self.store(onDisk, url: url, persistToDisk: false)
                return onDisk
            }
            guard let downloaded = await self.download(url: url) else { return nil }
            await self.store(downloaded, url: url, persistToDisk: true)
            return downloaded
        }

        inFlight[url] = task
        let result = await task.value
        inFlight[url] = nil
        return result
    }

    private func download(url: URL) async -> UIImage? {
        guard url.scheme == "https" else { return nil } // HTTPS-only, per security requirements
        guard let (data, response) = try? await URLSession.shared.data(from: url) else { return nil }
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
        return UIImage(data: data)
    }

    private func store(_ image: UIImage, url: URL, persistToDisk: Bool) {
        let cost = Int(image.size.width * image.size.height * 4)
        memoryCache.setObject(image, forKey: url as NSURL, cost: cost)
        if persistToDisk {
            writeToDisk(image, url: url)
        }
    }

    private func diskPath(for url: URL) -> URL {
        let name = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? UUID().uuidString
        return diskCacheURL.appendingPathComponent(name)
    }

    private func readFromDisk(url: URL) async -> UIImage? {
        let path = diskPath(for: url)
        guard let data = try? Data(contentsOf: path) else { return nil }
        return UIImage(data: data)
    }

    private func writeToDisk(_ image: UIImage, url: URL) {
        guard let data = image.jpegData(compressionQuality: 0.9) else { return }
        try? data.write(to: diskPath(for: url), options: .atomic)
    }
}
