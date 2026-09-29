import SwiftUI

// MARK: - API Client
class NetworkManager {
    static let shared = NetworkManager()
    
    // Tailscale Funnel base URL for the FastAPI backend.
    private let baseURL = "https://lost-and-found-ksu.taildfefb3.ts.net"
    
    // MARK: - Submit Report
    // This example sends only the basic report fields.
    // Add the remaining form fields based on the FastAPI handler in process.py.
    // See process.py for the full request fields and response payload
    func processReport(
        status: String,
        location: String,
        dateString: String, // Expected format: MM/DD/YYYY
        category: String,
        image: UIImage?,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/api/process") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        func appendFormField(name: String, value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        // These field names must match the FastAPI form parameters in /api/process.
        appendFormField(name: "status", value: status)
        appendFormField(name: "location", value: location)
        appendFormField(name: "date", value: dateString)
        appendFormField(name: "category", value: category)
        
        // Optional image upload. The backend hashes and caches the image file.
        if let image = image, let imageData = image.jpegData(compressionQuality: 0.8) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"image\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else { return }
            
            // 409 means the backend found a duplicate image hash and reused the cached file.
            if httpResponse.statusCode == 409 {
                print("Duplicate image found in the backend cache.")
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // The response may include detail.existing_image_path.
                    print("Duplicate image details:", json)
                }
                let customError = NSError(domain: "", code: 409, userInfo: [NSLocalizedDescriptionKey: "Duplicate image."])
                completion(.failure(customError))
                return
            }
            
            if httpResponse.statusCode == 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    completion(.success(json))
                }
            } else {
                let statusError = NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error."])
                completion(.failure(statusError))
            }
        }.resume()
    }
    
    // MARK: - Image URL
    func getFullImageURL(relativePath: String) -> URL? {
        // The backend returns a relative path like "/uploaded_images/uuid.jpg".
        return URL(string: "\(baseURL)\(relativePath)")
    }
}

// MARK: - Cached Backend Image View
struct ReportImageView: View {
    let relativeImagePath: String // Backend image_path, such as "/uploaded_images/..."
    
    var body: some View {
        if let imageURL = NetworkManager.shared.getFullImageURL(relativePath: relativeImagePath) {
            // AsyncImage downloads the backend image URL and keeps its own in-memory view cache.
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                case .failure:
                    Image(systemName: "photo")
                        .foregroundColor(.gray)
                @unknown default:
                    EmptyView()
                }
            }
        }
    }
}
