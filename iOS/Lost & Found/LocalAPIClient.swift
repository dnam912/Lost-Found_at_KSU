import Foundation
import UIKit

private struct CredentialsRequest: Encodable {
    let email: String
    let password: String
}

struct ServerMatch: Decodable, Identifiable {
    let id: Int
    let status: String
    let location: String
    let category: String?
    let descriptionRaw: String?
    let imagePath: String?
    let createdAt: String?
    let similarity: Double

    enum CodingKeys: String, CodingKey {
        case id, status, location, category, similarity
        case descriptionRaw = "description_raw"
        case imagePath = "image_path"
        case createdAt = "created_at"
    }
}

private struct MatchResponse: Decodable {
    let threshold: Double
    let matches: [ServerMatch]
}

private struct MatchRequest: Encodable {
    let embedding: [Float]
}

struct LocalAPIError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

final class LocalAPIClient {
    static let shared = LocalAPIClient()

    private let baseURL: URL = {
        let configured = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String
        return URL(string: configured ?? "https://lost-and-found-ksu.taildfefb3.ts.net")!
    }()

    private init() {}

    func imageURL(for relativePath: String?) -> URL? {
        guard let relativePath else { return nil }
        return URL(string: relativePath, relativeTo: baseURL)?.absoluteURL
    }

    func searchFoundItems(embedding: [Float]) async throws -> [ServerMatch] {
        var request = URLRequest(url: baseURL.appending(path: "/api/match"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try addAuthorization(to: &request)
        request.httpBody = try JSONEncoder().encode(MatchRequest(embedding: embedding))

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(MatchResponse.self, from: data).matches
    }

    func createFoundItem(
        title: String,
        location: String,
        description: String,
        image: UIImage,
        embedding: [Float]
    ) async throws {
        guard let imageData = image.jpegData(compressionQuality: 0.85) else {
            throw LocalAPIError(message: "Couldn't prepare the item photo.")
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: baseURL.appending(path: "/api/found"))
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        try addAuthorization(to: &request)

        var body = Data()
        appendField("title", value: title, boundary: boundary, to: &body)
        appendField("location", value: location, boundary: boundary, to: &body)
        appendField("description", value: description, boundary: boundary, to: &body)
        let embeddingData = try JSONEncoder().encode(embedding)
        appendField("embedding", value: String(decoding: embeddingData, as: UTF8.self), boundary: boundary, to: &body)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"found-item.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
    }

    func signUp(email: String, password: String) async throws -> AuthTokens {
        try await authenticate(path: "/api/auth/signup", email: email, password: password)
    }

    func signIn(email: String, password: String) async throws -> AuthTokens {
        try await authenticate(path: "/api/auth/login", email: email, password: password)
    }

    func currentUser(token: String) async throws -> AuthUser {
        var request = URLRequest(url: baseURL.appending(path: "/api/auth/me"))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(AuthUser.self, from: data)
    }

    func signOut(token: String) async throws {
        var request = URLRequest(url: baseURL.appending(path: "/api/auth/logout"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
    }

    private func authenticate(path: String, email: String, password: String) async throws -> AuthTokens {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(CredentialsRequest(email: email, password: password))
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(AuthTokens.self, from: data)
    }

    private func addAuthorization(to request: inout URLRequest) throws {
        guard let token = try SessionTokenStore.read() else {
            throw LocalAPIError(message: "Please sign in to continue.")
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    private func appendField(_ name: String, value: String, boundary: String, to body: inout Data) {
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        body.append(value.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LocalAPIError(message: "The server returned an invalid response.")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let detail = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["detail"] as? String
            throw LocalAPIError(message: detail ?? "Server request failed (HTTP \(httpResponse.statusCode)).")
        }
    }
}
