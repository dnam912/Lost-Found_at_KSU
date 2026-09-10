//
//  ContentView.swift
//  Lost & Found
//
//  Created by Zyaire Bush on 9/3/26.
//

import SwiftUI

// MARK: - Theme
enum KSU {
    static let gold = Color(red: 1.0, green: 0.78, blue: 0.0)
    static let black = Color(red: 0.08, green: 0.08, blue: 0.09)
    static let cardBackground = Color(.secondarySystemBackground)
    static let background = LinearGradient(
        colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Models
struct LostItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let imageName: String
    let location: String
    let datePosted: String
    var comments: [Comment] = []
}

struct Comment: Identifiable {
    let id = UUID()
    let author: String
    let text: String
    let timestamp: String
}

// MARK: - Main View
struct ContentView: View {
    @State private var lostItems: [LostItem] = [
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
        )
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                KSU.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header banner
                        VStack(alignment: .leading, spacing: 4) {
                            Text("KSU LOST & FOUND")
                                .font(.caption)
                                .fontWeight(.bold)
                                .tracking(2)
                                .foregroundStyle(KSU.gold)
                            Text("Reunite items with owners")
                                .font(.title2.bold())
                                .foregroundStyle(.primary)
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)

                        LazyVStack(spacing: 14) {
                            ForEach(lostItems) { item in
                                NavigationLink(destination: ItemDetailView(item: item)) {
                                    LostItemRow(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {}) {
                        Text("Login")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(KSU.black)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(KSU.gold)
                    }
                }
            }
        }
        .tint(KSU.gold)
    }
}

// MARK: - List Row
struct LostItemRow: View {
    let item: LostItem
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: item.imageName)
                .font(.title2)
                .foregroundStyle(KSU.black)
                .frame(width: 56, height: 56)
                .background(KSU.gold.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(KSU.gold)
                    Text(item.location)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(item.datePosted)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(spacing: 6) {
                if !item.comments.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right.fill")
                            .font(.caption2)
                        Text("\(item.comments.count)")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(KSU.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(KSU.gold.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Detail View
struct ItemDetailView: View {
    let item: LostItem
    @State private var newComment = ""
    
    var body: some View {
        ZStack {
            KSU.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Image
                    Image(systemName: item.imageName)
                        .font(.system(size: 90))
                        .foregroundStyle(KSU.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .background(KSU.gold.opacity(0.25))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    
                    // Item Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text(item.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        HStack(spacing: 8) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(KSU.gold)
                            Text(item.location)
                                .foregroundStyle(.secondary)
                        }
                        
                        Text(item.description)
                            .font(.body)
                            .lineLimit(nil)
                        
                        Text(item.datePosted)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(KSU.cardBackground)
                    )
                    
                    // Comments Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Comments (\(item.comments.count))")
                            .font(.headline)
                        
                        if item.comments.isEmpty {
                            Text("No comments yet. Be the first to help!")
                                .foregroundStyle(.secondary)
                                .font(.body)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(item.comments) { comment in
                                    CommentView(comment: comment)
                                }
                            }
                        }
                    }
                    
                    // Add Comment
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Leave a Comment")
                            .font(.headline)
                        
                        HStack(spacing: 8) {
                            TextField("Did you find it?", text: $newComment)
                                .textFieldStyle(.roundedBorder)
                            
                            Button(action: {
                                newComment = ""
                            }) {
                                Image(systemName: "paperplane.fill")
                                    .foregroundStyle(.white)
                                    .padding(10)
                                    .background(KSU.gold)
                                    .clipShape(Circle())
                            }
                            .disabled(newComment.isEmpty)
                            .opacity(newComment.isEmpty ? 0.5 : 1)
                        }
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
        }
        .navigationTitle("Item Details")
        .navigationBarTitleDisplayMode(.inline)
        .tint(KSU.gold)
    }
}

// MARK: - Comment View
struct CommentView: View {
    let comment: Comment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(comment.author)
                    .fontWeight(.semibold)
                Spacer()
                Text(comment.timestamp)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Text(comment.text)
                .foregroundStyle(.primary)
        }
        .padding(12)
        .background(KSU.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(KSU.gold.opacity(0.15), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    ContentView()
}
