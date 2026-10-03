//
//  PhotoMatchTestView.swift
//  Lost & Found
//
//  A quick test harness for the on-device image matching pipeline.
//  Lets you snap/pick a photo and compares it (via Vision feature
//  prints) against found items that have a reference photo, showing
//  a % match for each.
//

import SwiftUI

struct MatchResult: Identifiable {
    let match: ServerMatch

    var id: Int { match.id }
    var percentage: Int { Int((match.similarity * 100).rounded()) }
}

struct PhotoMatchTestView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var capturedImage: UIImage?
    @State private var showSourceDialog = false
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var isProcessing = false
    @State private var results: [MatchResult] = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                KSU.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        photoPreview

                        Button {
                            showSourceDialog = true
                        } label: {
                            Label(
                                capturedImage == nil ? "Take or Choose Photo" : "Retake Photo",
                                systemImage: "camera.fill"
                            )
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(KSU.black)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        if let capturedImage {
                            Button {
                                runMatch(against: capturedImage)
                            } label: {
                                if isProcessing {
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                } else {
                                    Label("Check Against System", systemImage: "sparkle.magnifyingglass")
                                        .font(.headline)
                                        .foregroundStyle(KSU.black)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                }
                            }
                            .background(KSU.gold)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .disabled(isProcessing)
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }

                        if !results.isEmpty {
                            resultsList
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Find My Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Add a Photo", isPresented: $showSourceDialog, titleVisibility: .visible) {
                Button("Take Photo") { showCamera = true }
                Button("Choose from Library") { showLibrary = true }
                Button("Cancel", role: .cancel) {}
            }
            .fullScreenCover(isPresented: $showCamera) {
                ImagePicker(sourceType: .camera) { image in
                    capturedImage = image
                    results = []
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showLibrary) {
                ImagePicker(sourceType: .photoLibrary) { image in
                    capturedImage = image
                    results = []
                }
            }
        }
        .tint(KSU.gold)
    }

    private var photoPreview: some View {
        Group {
            if let capturedImage {
                Image(uiImage: capturedImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 240)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No photo yet")
                        .foregroundStyle(.secondary)
                }
                .frame(height: 240)
                .frame(maxWidth: .infinity)
                .background(KSU.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
    }

    private var resultsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Matches (75% or higher)")
                .font(.headline)

            ForEach(results) { result in
                NavigationLink(destination: ServerMatchDetailView(match: result.match)) {
                    HStack {
                        matchThumbnail(for: result.match)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.match.category ?? "Found item")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(result.match.location)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(result.percentage)%")
                                .font(.title3.bold())
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(12)
                    .background(KSU.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func matchThumbnail(for match: ServerMatch) -> some View {
        if let imageURL = LocalAPIClient.shared.imageURL(for: match.imagePath) {
            AsyncImage(url: imageURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "shippingbox")
                    .foregroundStyle(KSU.black)
                    .frame(width: 52, height: 52)
                    .background(KSU.gold.opacity(0.25))
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func runMatch(against image: UIImage) {
        errorMessage = nil
        isProcessing = true
        results = []

        DispatchQueue.global(qos: .userInitiated).async {
            let embedding: [Float]
            do {
                embedding = try ImageMatcher.mobileCLIPEmbedding(for: image)
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = (error as? ImageMatcherError)?.errorDescription
                        ?? "Couldn't create an image embedding: \(error.localizedDescription)"
                    self.isProcessing = false
                }
                return
            }

            Task { @MainActor in
                do {
                    let matches = try await LocalAPIClient.shared.searchFoundItems(embedding: embedding)
                    let qualified = matches.filter {
                        $0.similarity >= Double(ImageMatcher.disclosureSimilarityThreshold)
                    }
                    if qualified.isEmpty {
                        self.errorMessage = "No items reached the 75% image-match requirement. Try a clearer photo or another angle."
                    } else {
                        self.results = qualified.map(MatchResult.init(match:))
                    }
                } catch {
                    self.errorMessage = error.localizedDescription
                }
                self.isProcessing = false
            }
        }
    }
}

#Preview {
    PhotoMatchTestView()
}

private struct ServerMatchDetailView: View {
    let match: ServerMatch

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let imageURL = LocalAPIClient.shared.imageURL(for: match.imagePath) {
                    AsyncImage(url: imageURL) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        ProgressView().frame(maxWidth: .infinity, minHeight: 220)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                Text(match.category ?? "Found item")
                    .font(.title2.bold())
                Label(match.location, systemImage: "mappin.circle.fill")
                    .foregroundStyle(.secondary)
                Text("Image similarity: \(Int((match.similarity * 100).rounded()))%")
                    .font(.headline)
                    .foregroundStyle(.green)
                if let description = match.descriptionRaw, !description.isEmpty {
                    Text(description)
                }
            }
            .padding()
        }
        .background(KSU.background)
        .navigationTitle("Possible Match")
        .navigationBarTitleDisplayMode(.inline)
    }
}
