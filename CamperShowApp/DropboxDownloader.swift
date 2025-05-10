import Foundation

class DropboxDownloader {
    static let shared = DropboxDownloader()
    
    private let refreshToken = "OzJvhNOXLRsAAAAAAAAAAa_ux4-sAyxujqutSZ8c4ikksftmFYDAI28efTJ6wI1I"
    private let appKey = "h30yr3o0n2wy4ms"
    private let appSecret = "fq0p9zejwpw2nxg"
    
    private func getAccessToken(completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "https://api.dropboxapi.com/oauth2/token") else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let params = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": appKey,
            "client_secret": appSecret
        ]
        
        request.httpBody = params
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let token = json["access_token"] as? String else {
                completion(nil)
                return
            }
            completion(token)
        }.resume()
    }
    
    func downloadAssignments(completion: @escaping (Result<Data, Error>) -> Void) {
        // Adjust this to match your actual Dropbox path
        let dropboxPath = "/RONNIE SHOW SHORTCUT FOLDER/Lester Show Logs/Assignments/Camper_Assignments.csv"
        
        getAccessToken { token in
            guard let token = token else {
                completion(.failure(NSError(domain: "Dropbox", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get token"])))
                return
            }
            
            guard let url = URL(string: "https://content.dropboxapi.com/2/files/download") else {
                completion(.failure(NSError(domain: "Dropbox", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid download URL"])))
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("{\"path\": \"\(dropboxPath)\"}", forHTTPHeaderField: "Dropbox-API-Arg")
            
            URLSession.shared.dataTask(with: request) { data, _, error in
                if let error = error {
                    completion(.failure(error))
                } else if let data = data {
                    print("✅ Assignments CSV downloaded from Dropbox")
                    completion(.success(data))
                } else {
                    completion(.failure(NSError(domain: "Dropbox", code: -3, userInfo: [NSLocalizedDescriptionKey: "Unknown download failure"])))
                }
            }.resume()
        }
    }
    
    
    func download(from dropboxPath: String, completion: @escaping (URL?) -> Void) {
        getAccessToken { token in
            guard let token = token else {
                completion(nil)
                return
            }
            
            guard let url = URL(string: "https://content.dropboxapi.com/2/files/download") else {
                completion(nil)
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("{\"path\": \"\(dropboxPath)\"}", forHTTPHeaderField: "Dropbox-API-Arg")
            
            URLSession.shared.downloadTask(with: request) { tempURL, response, error in
                guard let tempURL = tempURL, error == nil else {
                    print("❌ Download failed: \(error?.localizedDescription ?? "unknown error")")
                    completion(nil)
                    return
                }
                
                // Check if the response is JSON (meaning it's probably an error)
                if let data = try? Data(contentsOf: tempURL),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   json["error_summary"] != nil {
                    print("❌ Dropbox returned error JSON:\n\(json)")
                    completion(nil)
                    return
                }
                
                // Move to temp location
                let destinationURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent((dropboxPath as NSString).lastPathComponent)
                
                do {
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.moveItem(at: tempURL, to: destinationURL)
                    print("✅ Downloaded to \(destinationURL.lastPathComponent)")
                    completion(destinationURL)
                } catch {
                    print("❌ File move failed: \(error.localizedDescription)")
                    completion(nil)
                }
            }.resume()
        }
    }
}
