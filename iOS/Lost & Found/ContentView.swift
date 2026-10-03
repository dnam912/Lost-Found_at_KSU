//
//  ContentView.swift
//  Lost & Found
//
//  Created by Zyaire Bush on 9/3/26.
//

import SwiftUI
import UIKit

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
enum PostStatus: String, CaseIterable, Identifiable {
    case lost
    case found

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }
}

struct LostItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let imageName: String
    /// Optional asset catalog image name for a real reference photo
    /// (used for on-device Vision image matching). If nil, `imageName`
    /// is treated as an SF Symbol.
    var imageAssetName: String? = nil
    let location: String
    let datePosted: String
    var status: PostStatus = .lost
    var comments: [Comment] = []

    /// The actual reference photo, if this item has one, for use with
    /// Vision's feature print matching.
    var referenceImage: UIImage? {
        guard let imageAssetName else { return nil }
        return UIImage(named: imageAssetName)
    }
}

struct Comment: Identifiable {
    let id = UUID()
    let author: String
    let text: String
    let timestamp: String
}

// MARK: - Main View
struct ContentView: View {
    @State private var showCreatePost = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                KSU.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        HStack(spacing: 12) {
                            Image(systemName: "lock.shield.fill")
                                .font(.title2)
                                .foregroundStyle(KSU.black)
                                .frame(width: 48, height: 48)
                                .background(KSU.gold)
                                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

                            VStack(alignment: .leading, spacing: 3) {
                                Text("KSU LOST & FOUND")
                                    .font(.caption.weight(.bold))
                                    .tracking(1.5)
                                    .foregroundStyle(KSU.gold)
                                Text("Private item matching")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.top, 12)

                        VStack(alignment: .leading, spacing: 18) {
                            Label("PRIVATE BY DESIGN", systemImage: "lock.fill")
                                .font(.caption.weight(.bold))
                                .tracking(1.2)
                                .foregroundStyle(KSU.gold)

                            Text("Find what’s yours.")
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)

                            Text("Upload a photo. If your item has been found and matches, you’ll see it.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)

                            NavigationLink {
                                PhotoMatchTestView()
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "photo.badge.magnifyingglass")
                                    Text("Search with a photo")
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Image(systemName: "arrow.right")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .foregroundStyle(KSU.black)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 15)
                                .background(KSU.gold)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(22)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [KSU.black, Color(red: 0.18, green: 0.18, blue: 0.20)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .overlay(alignment: .topTrailing) {
                            Image(systemName: "viewfinder")
                                .font(.system(size: 88, weight: .ultraLight))
                                .foregroundStyle(.white.opacity(0.05))
                                .padding(18)
                                .accessibilityHidden(true)
                        }

                        Text("Have you found something? Use + to add a found-item post.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.bottom, 12)
                    }
                    .padding(.horizontal)
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
                    Button(action: { showCreatePost = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(KSU.gold)
                    }
                    .accessibilityLabel("Create a found-item post")
                }
            }
        }
        .tint(KSU.gold)
        .sheet(isPresented: $showCreatePost) {
            CreatePostView()
        }
    }

}

// MARK: - List Row
struct LostItemRow: View {
    let item: LostItem
    
    var body: some View {
        HStack(spacing: 14) {
            itemThumbnail
            
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

    @ViewBuilder
    private var itemThumbnail: some View {
        if let referenceImage = item.referenceImage {
            Image(uiImage: referenceImage)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            Image(systemName: item.imageName)
                .font(.title2)
                .foregroundStyle(KSU.black)
                .frame(width: 56, height: 56)
                .background(KSU.gold.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
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
                    if let referenceImage = item.referenceImage {
                        Image(uiImage: referenceImage)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    } else {
                        Image(systemName: item.imageName)
                            .font(.system(size: 90))
                            .foregroundStyle(KSU.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 220)
                            .background(KSU.gold.opacity(0.25))
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    
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
