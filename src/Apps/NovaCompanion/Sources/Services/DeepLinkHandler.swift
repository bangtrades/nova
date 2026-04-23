import Foundation
import Combine

/// Deep link and universal link handler for Nova Companion.
public class DeepLinkHandler: ObservableObject {
    public static let shared = DeepLinkHandler()

    @Published public var activeDestination: DeepLinkDestination?

    private init() {}

    /// Handle a URL and return the destination if valid.
    public func handle(url: URL) -> DeepLinkDestination? {
        // Handle nova:// scheme
        if url.scheme == "nova" {
            return handleNovaScheme(url)
        }

        // Handle universal links (https://nova-app.local/...)
        if url.scheme == "https" || url.scheme == "http" {
            return handleUniversalLink(url)
        }

        return nil
    }

    // MARK: - Private Methods

    private func handleNovaScheme(_ url: URL) -> DeepLinkDestination? {
        guard let host = url.host else { return nil }

        switch host {
        case "lesson":
            return handleLessonLink(url)
        case "dashy":
            return .dashy
        case "progress":
            return handleProgressLink(url)
        case "settings":
            return .settings
        case "curriculum":
            return .curriculum
        default:
            return nil
        }
    }

    private func handleUniversalLink(_ url: URL) -> DeepLinkDestination? {
        let path = url.path.lowercased()

        if path.contains("lesson") {
            return handleLessonLink(url)
        } else if path.contains("dashy") {
            return .dashy
        } else if path.contains("progress") {
            return handleProgressLink(url)
        } else if path.contains("settings") {
            return .settings
        } else if path.contains("curriculum") {
            return .curriculum
        }

        return nil
    }

    private func handleLessonLink(_ url: URL) -> DeepLinkDestination? {
        // nova://lesson/:id or /lesson/abc123
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        if let lastComponent = pathComponents.last {
            return .lesson(id: lastComponent)
        }

        // Try query parameter
        if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems {
            if let idParam = queryItems.first(where: { $0.name == "id" })?.value {
                return .lesson(id: idParam)
            }
        }

        return nil
    }

    private func handleProgressLink(_ url: URL) -> DeepLinkDestination? {
        // nova://progress/:childId or /progress/child123
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        if let lastComponent = pathComponents.last {
            return .progress(childId: lastComponent)
        }

        // Try query parameter
        if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems {
            if let childIdParam = queryItems.first(where: { $0.name == "childId" })?.value {
                return .progress(childId: childIdParam)
            }
        }

        return nil
    }
}

/// Represents a deep link destination.
public enum DeepLinkDestination: Equatable {
    case lesson(id: String)
    case dashy
    case progress(childId: String)
    case settings
    case curriculum
}

// MARK: - SwiftUI Integration

import SwiftUI

public extension View {
    /// Add deep link handling to a view.
    func withDeepLinkHandler() -> some View {
        self
            .onOpenURL { url in
                if let destination = DeepLinkHandler.shared.handle(url: url) {
                    DeepLinkHandler.shared.activeDestination = destination
                }
            }
    }
}
