//
//  AnimatedGIFView.swift
//  Droppy
//
//  A SwiftUI view that displays animated GIFs from a URL.
//

import SwiftUI
import AppKit

/// A view that displays an animated GIF from a URL
struct AnimatedGIFView: NSViewRepresentable {
    let url: URL?
    
    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.animates = true
        imageView.canDrawSubviewsIntoLayer = true
        return imageView
    }
    
    func updateNSView(_ nsView: NSImageView, context: Context) {
        guard let url = url else { return }
        
        // Check cache first
        if let cached = AnimatedGIFCache.shared.image(for: url) {
            nsView.image = cached
            return
        }
        
        // Load async
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = NSImage(data: data) {
                    AnimatedGIFCache.shared.cache(image, for: url)
                    await MainActor.run {
                        nsView.image = image
                    }
                }
            } catch {
                // Silently fail - view will be empty
            }
        }
    }
}

/// Cache for animated GIF images
final class AnimatedGIFCache {
    static let shared = AnimatedGIFCache()
    private var cache: [URL: NSImage] = [:]
    private let lock = NSLock()
    
    func image(for url: URL) -> NSImage? {
        lock.lock()
        defer { lock.unlock() }
        return cache[url]
    }
    
    func cache(_ image: NSImage, for url: URL) {
        lock.lock()
        defer { lock.unlock() }
        cache[url] = image
    }
}
