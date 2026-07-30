//
//  BookCacheService.swift
//  BookShare
//
//  Two-tier cache (memory + disk) for previously-fetched BookMetadata,
//  keyed by ISBN-13. Doubles as the fourth, last-resort "provider" in the
//  fallback chain (a book scanned once works forever, even offline).
//

import Foundation

actor BookCacheService {
    static let shared = BookCacheService()

    private var memoryCache: [String: BookMetadata] = [:]
    private let diskCacheURL: URL
    private let fileManager = FileManager.default

    init() {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskCacheURL = caches.appendingPathComponent("BookMetadataCache", isDirectory: true)
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }

    func metadata(for isbn: ISBN) -> BookMetadata? {
        if let hit = memoryCache[isbn.isbn13] {
            return hit
        }
        guard let onDisk = readFromDisk(isbn: isbn) else { return nil }
        memoryCache[isbn.isbn13] = onDisk
        return onDisk
    }

    func store(_ metadata: BookMetadata, for isbn: ISBN) {
        memoryCache[isbn.isbn13] = metadata
        writeToDisk(metadata, isbn: isbn)
    }

    func clearAll() {
        memoryCache.removeAll()
        try? fileManager.removeItem(at: diskCacheURL)
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }

    // MARK: - Disk I/O

    private func fileURL(for isbn: ISBN) -> URL {
        diskCacheURL.appendingPathComponent("\(isbn.isbn13).json")
    }

    private func readFromDisk(isbn: ISBN) -> BookMetadata? {
        let url = fileURL(for: isbn)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(BookMetadata.self, from: data)
    }

    private func writeToDisk(_ metadata: BookMetadata, isbn: ISBN) {
        guard let data = try? JSONEncoder().encode(metadata) else { return }
        try? data.write(to: fileURL(for: isbn), options: .atomic)
    }
}

/// Wraps `BookCacheService` as a fourth `BookMetadataProvider` so it can sit
/// at the end of the provider array if a caller wants "cache as last resort
/// after a real network attempt" instead of the default "cache first" order
/// used by `BookMetadataService.fetchBook`.
struct CacheOnlyProvider: BookMetadataProvider {
    let name: BookMetadata.Provider = .cache
    let cache: BookCacheService

    func fetch(isbn: ISBN) async throws -> BookMetadata {
        guard let cached = await cache.metadata(for: isbn) else {
            throw BookMetadataError.notFound
        }
        return cached
    }
}
