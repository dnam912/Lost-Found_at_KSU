//
//  CreatePostView.swift
//  Lost & Found
//

import SwiftUI
import UIKit

struct CreatePostView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var location = ""
    @State private var itemImage: UIImage?
    @State private var showSourceDialog = false
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        itemImage != nil && !isSubmitting
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let itemImage {
                        Image(uiImage: itemImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                            .frame(maxWidth: .infinity)
                    }
                    Button {
                        showSourceDialog = true
                    } label: {
                        Label(itemImage == nil ? "Add item photo" : "Change item photo", systemImage: "photo.badge.plus")
                    }
                } header: {
                    Text("Found item photo")
                } footer: {
                    Text("A photo is required so lost-item searches can match against this found item.")
                }

                Section {
                    TextField("Item name", text: $title)
                    TextField("Where was it found?", text: $location)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Item details")
                }

                Section {
                    Text("This development build sends the photo and its on-device MobileCLIP embedding to the FastAPI server used by the website. It is unauthenticated; use test data only.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Post Found Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        submitPost()
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("Post")
                        }
                    }
                    .disabled(!canSubmit)
                }
            }
            .tint(KSU.gold)
            .confirmationDialog("Add Item Photo", isPresented: $showSourceDialog, titleVisibility: .visible) {
                Button("Take Photo") { showCamera = true }
                Button("Choose from Library") { showLibrary = true }
                Button("Cancel", role: .cancel) {}
            }
            .fullScreenCover(isPresented: $showCamera) {
                ImagePicker(sourceType: .camera) { image in itemImage = image }
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $showLibrary) {
                ImagePicker(sourceType: .photoLibrary) { image in itemImage = image }
            }
        }
    }

    private func submitPost() {
        guard let itemImage else { return }
        errorMessage = nil
        isSubmitting = true

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            do {
                let embedding = try await Task.detached(priority: .userInitiated) {
                    try ImageMatcher.mobileCLIPEmbedding(for: itemImage)
                }.value
                try await LocalAPIClient.shared.createFoundItem(
                    title: cleanTitle,
                    location: cleanLocation,
                    description: cleanDescription,
                    image: itemImage,
                    embedding: embedding
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}

#Preview {
    CreatePostView()
}
