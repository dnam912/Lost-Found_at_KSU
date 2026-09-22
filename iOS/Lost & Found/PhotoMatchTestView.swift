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
import Vision

struct MatchResult: Identifiable {
    let id = UUID()
    let item: LostItem
    let score: ImageMatcher.CombinedMatchScore

    var percentage: Int { score.overallPercentage }
}

struct PhotoMatchTestView: View {
    let candidateItems: [LostItem]

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
            .navigationTitle("Match Test")
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
            Text("Results")
                .font(.headline)

            ForEach(results) { result in
                NavigationLink(destination: ItemDetailView(item: result.item)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.item.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(result.item.location)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(result.percentage)%")
                                .font(.title3.bold())
                                .foregroundStyle(result.percentage >= 70 ? .green : (result.percentage >= 40 ? KSU.gold : .secondary))
                            #if DEBUG
                            Text("color: \(result.score.colorPercentage)% · shape: \(result.score.visionPercentage)%")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("d: \(String(format: "%.2f", result.score.visionDistance)) / c: \(String(format: "%.2f", result.score.colorDistance))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            #endif
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

    private func runMatch(against image: UIImage) {
        errorMessage = nil
        isProcessing = true
        results = []

        DispatchQueue.global(qos: .userInitiated).async {
            let newSubject: ImageMatcher.AnalyzedSubject
            do {
                newSubject = try ImageMatcher.analyze(image)
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = (error as? ImageMatcherError)?.errorDescription
                        ?? "Couldn't analyze that photo: \(error.localizedDescription)"
                    self.isProcessing = false
                }
                return
            }

            var computed: [MatchResult] = []
            for item in candidateItems {
                guard
                    let referenceImage = item.referenceImage,
                    let referenceSubject = try? ImageMatcher.analyze(referenceImage),
                    let score = ImageMatcher.compare(newSubject, referenceSubject)
                else { continue }

                computed.append(MatchResult(item: item, score: score))
            }

            computed.sort { $0.percentage > $1.percentage }

            DispatchQueue.main.async {
                if computed.isEmpty {
                    self.errorMessage = "No found items with reference photos to compare against yet."
                } else {
                    self.results = computed
                }
                self.isProcessing = false
            }
        }
    }
}

#Preview {
    PhotoMatchTestView(candidateItems: [])
}
