import Foundation
import Combine

// 远程 DTO（与服务端字段对齐）
struct RemoteIdeaDTO: Codable {
    let id: String
    let content: String
    let project: String
    let createdAt: String
    let fontName: String
    let fontSize: Double
    let colorHex: String
    let isArchived: Bool
    
    init(_ idea: Idea) {
        self.id = idea.id.uuidString
        self.content = idea.content
        self.project = idea.project
        self.createdAt = ISO8601DateFormatter().string(from: idea.createdAt)
        self.fontName = idea.fontName
        self.fontSize = Double(idea.fontSize)
        self.colorHex = idea.colorHex
        self.isArchived = idea.isArchived
    }
    
    func toIdea() -> Idea {
        let date = ISO8601DateFormatter().date(from: createdAt) ?? Date()
        return Idea(
            id: UUID(uuidString: id) ?? UUID(),
            content: content,
            project: project,
            createdAt: date,
            fontName: fontName,
            fontSize: CGFloat(fontSize),
            colorHex: colorHex,
            isArchived: isArchived
        )
    }
}

final class APIService {
    static let shared = APIService()
    private init() {}
    
//    private let baseURL = "https://ideaapi.jackiezyd.top/index.php"
    private let baseURL = "Wirte your URL here..." //This is the server which for login and decate the account is it can open developer mode

    private func makeRequest(
        path: String,
        method: String = "GET",
        body: Encodable? = nil,
        authorized: Bool = true
    ) throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if authorized,
           let token = UserDefaults.standard.string(forKey: "authToken"),
           !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body = body {
            req.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }

        // ✅ 把拼好的请求信息保存到 UserDefaults
        UserDefaults.standard.set("\(method) \(url.absoluteString)", forKey: "lastRequestInfo")

        return req
    }

    
    private func debugResponse(_ data: Data, _ response: URLResponse) {
        if let http = response as? HTTPURLResponse {
            print("\n---- API Response ----")
            print("Status Code: \(http.statusCode)")
        }
        if let jsonString = String(data: data, encoding: .utf8) {
            print("Response Body: \(jsonString)")
        }
        print("----------------------\n")
    }
    
    // MARK: - Auth
    func login(email: String, password: String) -> AnyPublisher<String, Error> {
        struct LoginBody: Encodable { let email: String; let password: String }
        let body = LoginBody(email: email, password: password)
        
        do {
            var req = try makeRequest(path: "/auth/login", method: "POST", body: body, authorized: false)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            return URLSession.shared.dataTaskPublisher(for: req)
                .handleEvents(receiveOutput: { [weak self] data, resp in
                    self?.debugResponse(data, resp)
                })
                .tryMap { data, response -> String in
                    guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
                    guard (200...299).contains(http.statusCode) else {
                        let bodyText = String(data: data, encoding: .utf8) ?? "无返回内容"
                        throw NSError(domain: "", code: http.statusCode,
                                      userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(bodyText)"])
                    }
                    let json = (try? JSONSerialization.jsonObject(with: data)) as? [String:Any]
                    guard let token = json?["token"] as? String else { throw URLError(.cannotParseResponse) }
                    UserDefaults.standard.set(token, forKey: "authToken")
                    return token
                }
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
        
    
    
    // MARK: - DEV_MODE 检查
    func fetchUserInfo(token: String) -> AnyPublisher<[String: Any], Error> {
        guard let url = URL(string: "\(baseURL)/user/info") else {
            return Fail(error: URLError(.badURL))
                .eraseToAnyPublisher()
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        return URLSession.shared.dataTaskPublisher(for: request)
            .handleEvents(receiveOutput: { [weak self] data, resp in
                self?.debugResponse(data, resp)
            })
            .tryMap { data, response -> [String: Any] in
                guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
                guard (200...299).contains(http.statusCode) else {
                    let bodyText = String(data: data, encoding: .utf8) ?? "无返回内容"
                    throw NSError(domain: "", code: http.statusCode,
                                  userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(bodyText)"])
                }
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                return json ?? [:]
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Projects
    func fetchProjects() -> AnyPublisher<[String], Error> {
        do {
            let req = try makeRequest(path: "/projects", method: "GET")
            return URLSession.shared.dataTaskPublisher(for: req)
                .handleEvents(receiveOutput: { [weak self] data, resp in
                    self?.debugResponse(data, resp)
                })
                .tryMap { data, response -> [String] in
                    guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
                    guard (200...299).contains(http.statusCode) else {
                        let bodyText = String(data: data, encoding: .utf8) ?? "无返回内容"
                        throw NSError(domain: "", code: http.statusCode,
                                      userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(bodyText)"])
                    }
                    return try JSONDecoder().decode([String].self, from: data)
                }
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    func fetchIdeas(project: String) -> AnyPublisher<[Idea], Error> {
        let q = project.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? project
        do {
            let req = try makeRequest(path: "/ideas?project=\(q)", method: "GET")
            return URLSession.shared.dataTaskPublisher(for: req)
                .handleEvents(receiveOutput: { [weak self] data, resp in
                    self?.debugResponse(data, resp)
                })
                .tryMap { data, response -> [Idea] in
                    guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
                    guard (200...299).contains(http.statusCode) else {
                        let bodyText = String(data: data, encoding: .utf8) ?? "无返回内容"
                        throw NSError(domain: "", code: http.statusCode,
                                      userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(bodyText)"])
                    }
                    let dtos = try JSONDecoder().decode([RemoteIdeaDTO].self, from: data)
                    return dtos.map { $0.toIdea() }
                }
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    func uploadIdeas(project: String, ideas: [Idea]) -> AnyPublisher<Bool, Error> {
        struct Payload: Encodable {
            let project: String
            let ideas: [RemoteIdeaDTO]
        }
        let payload = Payload(project: project, ideas: ideas.map(RemoteIdeaDTO.init))
        
        do {
            let req = try makeRequest(path: "/ideas/batch", method: "POST", body: payload)
            return URLSession.shared.dataTaskPublisher(for: req)
                .handleEvents(receiveOutput: { [weak self] data, resp in
                    self?.debugResponse(data, resp)
                })
                .tryMap { data, response -> Bool in
                    guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
                    guard (200...299).contains(http.statusCode) else {
                        let bodyText = String(data: data, encoding: .utf8) ?? "无返回内容"
                        throw NSError(domain: "", code: http.statusCode,
                                      userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(bodyText)"])
                    }
                    return true
                }
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    func uploadProjectsAndOpinions(projects: [[String: Any]], opinions: [[String: Any]]) -> AnyPublisher<Bool, Error> {
        struct Payload: Encodable {
            let projects: [[String: AnyEncodable]]
            let opinions: [[String: AnyEncodable]]
        }

        // 自动补全 projects 的 id
        var fixedProjects = projects.map { dict -> [String: Any] in
            var d = dict
            if d["id"] == nil {
                d["id"] = UUID().uuidString
            }
            return d
        }

        // 自动补全 opinions 的 id 和 project_id
        var fixedOpinions = opinions.map { dict -> [String: Any] in
            var d = dict
            if d["id"] == nil {
                d["id"] = UUID().uuidString
            }
            if d["project_id"] == nil, let projectId = fixedProjects.first?["id"] {
                d["project_id"] = projectId
            }
            return d
        }

        let encodableProjects = fixedProjects.map { $0.mapValues { AnyEncodable($0) } }
        let encodableOpinions = fixedOpinions.map { $0.mapValues { AnyEncodable($0) } }

        let payload = Payload(projects: encodableProjects, opinions: encodableOpinions)

        do {
            let req = try makeRequest(path: "/projects", method: "POST", body: payload)
            return URLSession.shared.dataTaskPublisher(for: req)
                .handleEvents(receiveOutput: { [weak self] data, resp in
                    self?.debugResponse(data, resp)
                })
                .tryMap { data, response -> Bool in
                    guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
                    guard (200...299).contains(http.statusCode) else {
                        let bodyText = String(data: data, encoding: .utf8) ?? "无返回内容"
                        throw NSError(domain: "", code: http.statusCode,
                                      userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(bodyText)"])
                    }
                    return true
                }
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
}

private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    init(_ value: Any) {
        if let encodable = value as? Encodable {
            self._encode = { try encodable.encode(to: $0) }
        } else {
            self._encode = { encoder in
                var container = encoder.singleValueContainer()
                try container.encodeNil()
            }
        }
    }
    func encode(to encoder: Encoder) throws { try _encode(encoder) }
}


func uploadProjectsAndOpinions(
    projects: [[String: Any]],
    opinions: [[String: Any]]
) -> AnyPublisher<Bool, Error> {
    guard let token = UserDefaults.standard.string(forKey: "authToken") else {
        return Fail(error: URLError(.userAuthenticationRequired))
            .eraseToAnyPublisher()
    }
    guard let url = URL(string: "https://ideaapi.jackiezyd.top/index.php/projects") else {
        return Fail(error: URLError(.badURL))
            .eraseToAnyPublisher()
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    
    let body: [String: Any] = [
        "projects": projects,
        "opinions": opinions
    ]
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)
    
    return URLSession.shared.dataTaskPublisher(for: request)
        .tryMap { data, response -> Bool in
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }
            return true
        }
        .eraseToAnyPublisher()
    // ✅ 新增：同时上传 Projects 和 Opinions
    func uploadProjectsAndOpinions(projects: [[String: Any]], opinions: [[String: Any]]) -> AnyPublisher<Bool, Error> {
        guard let token = UserDefaults.standard.string(forKey: "authToken") else {
            return Fail(error: URLError(.userAuthenticationRequired)).eraseToAnyPublisher()
        }

        let url = URL(string: "https://ideaapi.jackiezyd.top/index.php/projects")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "projects": projects,
            "opinions": opinions
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                return true
            }
            .eraseToAnyPublisher()
    }

}
