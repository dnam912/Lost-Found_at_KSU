//
//  PostRepository.swift
//  Lost & Found
//

import Foundation
import Combine

// MARK: - Post Storage Boundary

/// The app only depends on these operations, so the in-memory implementation
/// can later be replaced with a Supabase-backed repository.
protocol PostRepository {
    func fetchPosts() -> [LostItem]
    func createPost(_ post: LostItem)
}

final class InMemoryPostRepository: PostRepository {
    private var storedPosts: [LostItem]

    init(posts: [LostItem]? = nil) {
        storedPosts = posts ?? Self.samplePosts
    }

    func fetchPosts() -> [LostItem] {
        storedPosts
    }

    func createPost(_ post: LostItem) {
        storedPosts.insert(post, at: 0)
    }

    private static let samplePosts: [LostItem] = [
        LostItem(
            title: "Silver Backpack",
            description: "Lost near the library with textbooks inside",
            imageName: "square.and.pencil",
            location: "Library - Building A",
            datePosted: "Today at 2:30 PM",
            comments: [
                Comment(author: "John", text: "I saw something like this near the cafe", timestamp: "1h ago"),
                Comment(author: "Sarah", text: "Check lost and found at Student Center", timestamp: "30m ago")
            ]
        ),
        LostItem(
            title: "Blue Airpods Case",
            description: "Lost Airpods Pro case in blue color",
            imageName: "airpodsmax",
            location: "Student Center",
            datePosted: "Yesterday at 5:00 PM",
            comments: [
                Comment(author: "Mike", text: "Found something similar, DM me!", timestamp: "2h ago")
            ]
        ),
        LostItem(
            title: "Blue Jacket",
            description: "Navy blue winter jacket with Columbia logo",
            imageName: "square.and.pencil",
            location: "Gym - Locker Room",
            datePosted: "2 days ago",
            comments: []
        ),
        LostItem(
            title: "White AirPods Case (Found)",
            description: "Found on a desk, plain white AirPods case",
            imageName: "airpodsmax",
            imageAssetName: "foundAirpodsCase",
            location: "Turned in at Student Center Front Desk",
            datePosted: "Today at 11:15 AM",
            status: .found,
            comments: []
        )
    ]
}

@MainActor
final class PostStore: ObservableObject {
    @Published private(set) var posts: [LostItem]
    private let repository: PostRepository

    init(repository: PostRepository? = nil) {
        let repository = repository ?? InMemoryPostRepository()
        self.repository = repository
        posts = repository.fetchPosts()
    }

    func createPost(_ post: LostItem) {
        repository.createPost(post)
        posts = repository.fetchPosts()
    }
}
