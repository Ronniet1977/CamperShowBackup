import Foundation

class DropboxUploader {
    static let shared = DropboxUploader()
    
    private let refreshToken = Secrets.dropboxRefreshToken
    private let appKey = Secrets.dropboxAppKey
    private let appSecret = Secrets.dropboxAppSecret

    
    private var accessToken: String?
    
    func createDropboxFolder(path: String, accessToken: String, completion: (() -> Void)? = nil) {
        guard let url = URL(string: "https://api.dropboxapi.com/2/files/create_folder_v2") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["path": path, "autorename": false] as [String : Any]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { _, _, error in
            if let error = error {
                print("❌ Folder creation error: \(error.localizedDescription)")
            } else {
                print("📁 Folder created or already exists: \(path)")
            }
            completion?()
        }.resume()
    }
    
    func upload(localURL: URL, to dropboxPath: String) {
        getAccessToken { token in
            guard let token = token else {
                print("❌ Failed to get access token")
                return
            }

            // Get the folder from the dropbox path
            let folderPath = (dropboxPath as NSString).deletingLastPathComponent

            self.createDropboxFolder(path: folderPath, accessToken: token) {
                self.uploadFile(localURL: localURL, dropboxPath: dropboxPath, accessToken: token)
            }
        }
    }

    
    

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
            self.accessToken = token
            completion(token)
        }.resume()
    }
    
    
    
    private func uploadFile(localURL: URL, dropboxPath: String, accessToken: String) {
        guard let fileData = try? Data(contentsOf: localURL) else {
            print("❌ Couldn't load file data")
            return
        }
        
        guard let url = URL(string: "https://content.dropboxapi.com/2/files/upload") else {
            print("❌ Invalid upload URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        let apiArg = """
        {"path": "\(dropboxPath)", "mode": "overwrite", "autorename": false, "mute": true}
        """
        request.setValue(apiArg, forHTTPHeaderField: "Dropbox-API-Arg")
        
        URLSession.shared.uploadTask(with: request, from: fileData) { data, response, error in
            if let error = error {
                print("❌ Upload error: \(error)")
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    print("✅ Uploaded \(dropboxPath)")
                } else {
                    print("⚠️ Upload failed with status: \(httpResponse.statusCode)")
                    if let data = data, let body = String(data: data, encoding: .utf8) {
                        print("🔍 Server said:", body)
                    }
                }
            }
        }.resume()
    }
    
    func moveFile(from fromPath: String, to toPath: String) {
        getAccessToken { token in
            guard let token = token else {
                print("❌ Failed to get access token for move")
                return
            }

            guard let url = URL(string: "https://api.dropboxapi.com/2/files/move_v2") else {
                print("❌ Invalid Dropbox move URL")
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = [
                "from_path": fromPath,
                "to_path": toPath,
                "allow_shared_folder": true,
                "autorename": false,
                "allow_ownership_transfer": false
            ]

            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("❌ Move error: \(error)")
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        print("✅ Moved file from \(fromPath) to \(toPath)")
                    } else {
                        print("⚠️ Move failed with status: \(httpResponse.statusCode)")
                        if let data = data, let message = String(data: data, encoding: .utf8) {
                            print("🔍 Dropbox said: \(message)")
                        }
                    }
                }
            }.resume()
        }
    }

    
    func moveFileToArchive(from oldPath: String, to archiveFolder: String = "/RONNIE SHOW SHORTCUT FOLDER/Lester Show Logs/Archived Shows") {
        getAccessToken { token in
            guard let token = token else {
                print("❌ Failed to get access token for archive move")
                return
            }

            guard let url = URL(string: "https://api.dropboxapi.com/2/files/move_v2") else { return }

            let fileName = (oldPath as NSString).lastPathComponent
            let newPath = "\(archiveFolder)/\(fileName)"

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = [
                "from_path": oldPath,
                "to_path": newPath,
                "allow_shared_folder": true,
                "autorename": false,
                "allow_ownership_transfer": false
            ]

            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("❌ Move to archive failed: \(error)")
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        print("📦 Moved to archive: \(newPath)")
                    } else {
                        print("⚠️ Move failed with status: \(httpResponse.statusCode)")
                        if let data = data, let body = String(data: data, encoding: .utf8) {
                            print("🔍 Server said:", body)
                        }
                    }
                }
            }.resume()
        }
    }
}

