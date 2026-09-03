//
//  ContentView.swift
//  Lost & Found
//
//  Created by Zyaire Bush on 9/3/26.
//

import SwiftUI

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
            List {
                ForEach(lostItems) { item in
                    NavigationLink(destination: ItemDetailView(item: item)) {
                        LostItemRow(item: item)
                    }
                }
            }
            .navigationTitle("Lost & Found")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {}) {
                        Text("Login")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
        }
    }
}

// MARK: - List Row
struct LostItemRow: View {
    let item: LostItem
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.imageName)
                .font(.largeTitle)
                .foregroundStyle(.blue)
                .frame(width: 50, height: 50)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                Text(item.location)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(item.datePosted)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if !item.comments.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "bubble.right")
                        .font(.caption)
                    Text("\(item.comments.count)")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Detail View
struct ItemDetailView: View {
    let item: LostItem
    @State private var newComment = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Image
                Image(systemName: item.imageName)
                    .font(.system(size: 100))
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 250)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                
                // Item Info
                VStack(alignment: .leading, spacing: 12) {
                    Text(item.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(.red)
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
                
                Divider()
                
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
                
                Divider()
                
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
                                .foregroundStyle(.blue)
                        }
                        .disabled(newComment.isEmpty)
                    }
                }
                
                Spacer(minLength: 20)
            }
            .padding()
        }
        .navigationTitle("Item Details")
        .navigationBarTitleDisplayMode(.inline)
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
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    ContentView()
}
