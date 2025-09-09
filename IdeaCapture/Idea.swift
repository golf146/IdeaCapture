import Foundation
import SwiftUI
import Combine

// MARK: - Model
struct Idea: Identifiable, Codable, Hashable {
    let id: UUID
    var content: String
    var project: String
    var createdAt: Date
    var fontName: String
    var fontSize: CGFloat
    var colorHex: String
    var isArchived: Bool = false
    
    
    init(id: UUID = UUID(), content: String, project: String, createdAt: Date = Date(),
         fontName: String? = nil, fontSize: CGFloat? = nil, colorHex: String? = nil, isArchived: Bool = false) {
        self.id = id
        self.content = content
        self.project = project
        self.createdAt = createdAt
        self.fontName = fontName ?? ["HelveticaNeue-Bold", "Arial-BoldMT", "Courier-Bold"].randomElement()!
        self.fontSize = fontSize ?? CGFloat.random(in: 18...26)
        self.colorHex = colorHex ?? ["#000000", "#FF0000", "#0000FF", "#FFA500", "#800080", "#008000"].randomElement()!
        self.isArchived = isArchived
    }
}

// MARK: - Per-project structures used by Settings/Onboarding
struct ProjectConfig: Codable, Equatable {
    var color: String = "#0000FF"
    var deadline: Date? = nil

    var targetDate: Date? = nil
    var liveActivityEnabled: Bool = true
    var showNameInIsland: Bool = true
    var importToCalendar: Bool = false
    var notifyEnabled: Bool = true
    var calendarEventIdentifier: String? = nil

    var createdAt: Date = Date()
}

struct ProjectMeta: Codable, Equatable {
    var summary: String
    var tags: [String]
    var goals: String
    var audience: String
    var tone: String
    var createdAt: Date
    var id: String
    
    init(id: String = UUID().uuidString,
         summary: String,
         tags: [String],
         goals: String,
         audience: String,
         tone: String,
         createdAt: Date = Date()) {
        self.id = id
        self.summary = summary
        self.tags = tags
        self.goals = goals
        self.audience = audience
        self.tone = tone
        self.createdAt = createdAt
    }
}

// MARK: - ViewModel
final class IdeaViewModel: ObservableObject {
    private let ideasKey = "IdeaBubble.ideas.v1"
    private let projectsKey = "IdeaBubble.projects.v1"
    private let selectedProjectKey = "IdeaBubble.selectedProject.v1"
    private let firstLaunchKey = "IdeaBubble.firstLaunchDone.v1"
    private let projectConfigsKey = "IdeaBubble.projectConfigs.v1"
    private let projectMetasKey = "IdeaBubble.projectMetas.v1"

    let defaultProjectName = "默认项目"

    @Published var ideas: [Idea] = [] { didSet { saveIdeas() } }
    @Published var projects: [String] = [] { didSet { saveProjects() } }
    @Published var selectedProject: String = "" { didSet { UserDefaults.standard.set(selectedProject, forKey: selectedProjectKey) } }
    @Published var firstLaunchDone: Bool = false { didSet { UserDefaults.standard.set(firstLaunchDone, forKey: firstLaunchKey) } }

    @Published private(set) var projectConfigs: [String: ProjectConfig] = [:] { didSet { saveProjectConfigs() } }
    @Published private(set) var projectMetas: [String: ProjectMeta] = [:] { didSet { saveProjectMetas() } }
    
    // ✅ 同步状态
    @Published var isSyncing: Bool = false
    @Published var syncMessage: String?

    private var cancellables = Set<AnyCancellable>()

    init() {
        loadProjects()
        loadIdeas()
        loadSelectedProject()
        loadFirstLaunch()
        loadProjectConfigs()
        loadProjectMetas()
        ensureDefaultProjectExists()
    }
    @Published private(set) var projectIDs: [String: String] = [:]
    private let projectIDsKey = "IdeaBubble.projectIDs.v1"

    private func saveProjectIDs() {
        UserDefaults.standard.set(projectIDs, forKey: projectIDsKey)
    }

    private func loadProjectIDs() {
        if let dict = UserDefaults.standard.dictionary(forKey: projectIDsKey) as? [String: String] {
            projectIDs = dict
        }
    }


    // MARK: - Ideas
    func addIdea(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !selectedProject.isEmpty else { return }

        let colors: [Color] = [.primary, .blue, .red, .purple, .orange, .green]
        let fonts: [String] = ["HelveticaNeue-Bold", "Courier-Bold", "Avenir-Black", "ChalkboardSE-Bold"]
        let randomFont = fonts.randomElement()!
        let randomSize = CGFloat.random(in: 18...26)

        ideas.append(Idea(content: trimmed,
                          project: selectedProject,
                          fontName: randomFont,
                          fontSize: randomSize))
    }

    func deleteIdea(_ idea: Idea) {
        ideas.removeAll { $0.id == idea.id }
    }

    func archiveIdea(_ idea: Idea) {
        if let index = ideas.firstIndex(of: idea) {
            ideas[index].isArchived = true
            saveIdeas()
        }
    }

    // MARK: - Projects
    func addProject(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !projects.contains(trimmed) else { return }
        projects.append(trimmed)
        selectedProject = trimmed
        if projectConfigs[trimmed] == nil { projectConfigs[trimmed] = ProjectConfig() }
        if projectMetas[trimmed] == nil {
            projectMetas[trimmed] = ProjectMeta(
                id: UUID().uuidString,
                summary: "",
                tags: [],
                goals: "",
                audience: "",
                tone: "",
                createdAt: Date()
            )

            


            
        }
    }


    func deleteProject(named name: String) {
        guard !(projects.count == 1 && name == defaultProjectName) else { return }
        ideas.removeAll { $0.project == name }
        projects.removeAll { $0 == name }
        projectConfigs.removeValue(forKey: name)
        projectMetas.removeValue(forKey: name)
        if !projects.contains(selectedProject) {
            selectedProject = projects.first ?? defaultProjectName
        }
        NotificationManager.clear(projectName: name)
        LiveActivityManager.end(projectName: name)
        if let id = projectConfigs[name]?.calendarEventIdentifier {
            CalendarManager().removeEvent(id: id)
        }
    }

    func renameProject(from old: String, to new: String) {
        let trimmed = new.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let idx = projects.firstIndex(of: old) else { return }
        guard !projects.contains(trimmed) else { return }

        projects[idx] = trimmed
        for i in ideas.indices where ideas[i].project == old {
            ideas[i].project = trimmed
        }
        if selectedProject == old { selectedProject = trimmed }

        if let cfg = projectConfigs.removeValue(forKey: old) {
            projectConfigs[trimmed] = cfg
        }
        if let meta = projectMetas.removeValue(forKey: old) {
            projectMetas[trimmed] = meta
        }
    }

    var isOnlyDefaultProject: Bool { projects.count == 1 && projects.first == defaultProjectName }
    var shouldShowOnboarding: Bool { !firstLaunchDone || isOnlyDefaultProject }

    // MARK: - Config / Meta
    func ensureConfigExists(for project: String) -> ProjectConfig {
        if let c = projectConfigs[project] { return c }
        let c = ProjectConfig()
        projectConfigs[project] = c
        return c
    }
    func config(for project: String) -> ProjectConfig {
        projectConfigs[project] ?? ProjectConfig()
    }
    func setConfig(for project: String, _ config: ProjectConfig) {
        projectConfigs[project] = config
    }

    func meta(for project: String) -> ProjectMeta? {
        projectMetas[project]
    }
    func setMeta(_ meta: ProjectMeta, for project: String) {
        projectMetas[project] = meta
    }

    // MARK: - 应用项目设置（通知 + 日历 + 灵动岛）
    func applyProjectSettings(for project: String) {
        let cfg = ensureConfigExists(for: project)
        if cfg.notifyEnabled, let date = cfg.targetDate {
            NotificationManager.requestAuthorization { ok in
                if ok { NotificationManager.scheduleCountdownNotifications(projectName: project, target: date) }
            }
        } else {
            NotificationManager.clear(projectName: project)
        }
        if cfg.importToCalendar, let date = cfg.targetDate {
            let cm = CalendarManager()
            cm.requestAccess { granted in
                if granted {
                    let id = cm.upsertEvent(title: "\(project) 倒计时",
                                            notes: "由 IdeaCapture 导入",
                                            date: date,
                                            existingId: cfg.calendarEventIdentifier)
                    var updated = cfg
                    updated.calendarEventIdentifier = id
                    self.setConfig(for: project, updated)
                }
            }
        } else if let id = cfg.calendarEventIdentifier {
            CalendarManager().removeEvent(id: id)
        }
        if cfg.liveActivityEnabled {
            _ = LiveActivityManager.startOrUpdate(projectName: project,
                                                  targetDate: cfg.targetDate,
                                                  showName: cfg.showNameInIsland)
        } else {
            LiveActivityManager.end(projectName: project)
        }
    }

    // MARK: - 云同步（下载 / 上传）
    /// 下载服务器上的“项目列表”，并替换本地项目（保留默认项目）
    func downloadProjects() {
        guard hasToken else {
            self.syncMessage = "未登录，无法同步项目。"
            return
        }
        isSyncing = true
        APIService.shared.fetchProjects()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isSyncing = false
                if case .failure(let e) = completion {
                    self?.syncMessage = "获取项目失败：\(e.localizedDescription)"
                }
            } receiveValue: { [weak self] serverProjects in
                guard let self = self else { return }
                var new = serverProjects
                if !new.contains(self.defaultProjectName) {
                    new.insert(self.defaultProjectName, at: 0)
                }
                self.projects = new
                if !new.contains(self.selectedProject) {
                    self.selectedProject = new.first ?? self.defaultProjectName
                }
                self.syncMessage = "已下载项目（\(new.count)）"
            }
            .store(in: &cancellables)
    }
    
    /// 下载“当前项目”的点子并覆盖本地
    func downloadIdeasForCurrentProject() {
        guard hasToken else {
            self.syncMessage = "未登录，无法下载点子。"
            return
        }
        let proj = selectedProject
        guard !proj.isEmpty else { return }
        
        isSyncing = true
        APIService.shared.fetchIdeas(project: proj)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isSyncing = false
                if case .failure(let e) = completion {
                    self?.syncMessage = "下载失败：\(e.localizedDescription)"
                }
            } receiveValue: { [weak self] serverIdeas in
                guard let self = self else { return }
                // 覆盖本地该项目的点子
                self.ideas.removeAll { $0.project == proj }
                self.ideas.append(contentsOf: serverIdeas)
                self.syncMessage = "已下载「\(proj)」点子（\(serverIdeas.count) 条）"
            }
            .store(in: &cancellables)
    }
    
    /// 上传“当前项目”的点子（覆盖云端）
    func uploadIdeasForCurrentProject() {
        guard hasToken else {
            self.syncMessage = "未登录，无法上传点子。"
            return
        }
        let proj = selectedProject
        guard !proj.isEmpty else { return }
        let payload = ideas.filter { $0.project == proj }
        
        isSyncing = true
        APIService.shared.uploadIdeas(project: proj, ideas: payload)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isSyncing = false
                if case .failure(let e) = completion {
                    self?.syncMessage = "上传失败：\(e.localizedDescription)"
                }
            } receiveValue: { [weak self] ok in
                self?.syncMessage = ok ? "已上传「\(proj)」点子（\(payload.count) 条）" : "上传未成功"
            }
            .store(in: &cancellables)
    }
    
    /// 全量下载（先项目，再逐项目点子，覆盖本地）
    func downloadAll() {
        guard hasToken else { self.syncMessage = "未登录，无法同步。"; return }
        isSyncing = true
        APIService.shared.fetchProjects()
            .flatMap { projs -> AnyPublisher<([String], [[Idea]]), Error> in
                let streams = projs.map { APIService.shared.fetchIdeas(project: $0) }
                // 并发取回全部项目点子
                return Publishers.MergeMany(streams)
                    .collect()
                    .map { (projs, $0) }
                    .eraseToAnyPublisher()
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isSyncing = false
                if case .failure(let e) = completion {
                    self?.syncMessage = "全量下载失败：\(e.localizedDescription)"
                }
            } receiveValue: { [weak self] (projs, ideasGroup) in
                guard let self = self else { return }
                var allIdeas: [Idea] = []
                for ideas in ideasGroup { allIdeas += ideas }
                var finalProjects = projs
                if !finalProjects.contains(self.defaultProjectName) {
                    finalProjects.insert(self.defaultProjectName, at: 0)
                }
                self.projects = finalProjects
                self.ideas = allIdeas
                if !finalProjects.contains(self.selectedProject) {
                    self.selectedProject = finalProjects.first ?? self.defaultProjectName
                }
                self.syncMessage = "全量下载完成：项目 \(finalProjects.count)，点子 \(allIdeas.count)"
            }
            .store(in: &cancellables)
    }
    
    /// 全量上传（把本地所有项目分别覆盖上传）
    /// 全量上传（项目 + 观点）
    func uploadAll() {
        
        guard hasToken else { self.syncMessage = "未登录，无法同步。"; return }
        isSyncing = true

        // 构造项目数据
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        var projectIdMap: [String: String] = [:]
        let projectsPayload: [[String: Any]] = projects.map { name in
            let id = projectMetas[name]?.id ?? UUID().uuidString
            projectIdMap[name] = id
            let meta = projectMetas[name]
            return [
                "id": id,
                "name": name,
                "summary": meta?.summary ?? "",
                "tags": meta?.tags ?? [],
                "goals": meta?.goals ?? "",
                "audience": meta?.audience ?? "",
                "created_at": dateFormatter.string(from: meta?.createdAt ?? Date()),
                "updated_at": dateFormatter.string(from: Date()),
                "created_device_udid": UIDevice.current.identifierForVendor?.uuidString ?? "",
                "updated_device_udid": UIDevice.current.identifierForVendor?.uuidString ?? "",
                "current_opinion_id": NSNull()
            ]
        }

        // 构造观点数据
        let opinionsPayload: [[String: Any]] = ideas.map { idea in
            [
                "id": UUID().uuidString,
                "project_id": projectIdMap[idea.project] ?? "",
                "version": 1,
                "opinion": idea.content,
                "prev_opinion_id": NSNull(),
                "created_at": dateFormatter.string(from: idea.createdAt),
                "device_udid": UIDevice.current.identifierForVendor?.uuidString ?? ""
            ]
        }
        // 🔹 调试模式：输出上传 JSON
        if UserDefaults.standard.bool(forKey: "showUploadJSON") {
            if let jsonData = try? JSONSerialization.data(
                withJSONObject: ["projects": projectsPayload, "opinions": opinionsPayload],
                options: .prettyPrinted
            ), let jsonString = String(data: jsonData, encoding: .utf8) {
                print("📤 即将上传的 JSON:\n\(jsonString)")
            }
        }


        APIService.shared.uploadProjectsAndOpinions(
            projects: projectsPayload,
            opinions: opinionsPayload
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] completion in
            self?.isSyncing = false
            if case .failure(let e) = completion {
                self?.syncMessage = "全量上传失败：\(e.localizedDescription)"
            }
        } receiveValue: { [weak self] ok in
            self?.syncMessage = ok ? "全量上传成功" : "上传未成功"
        }
        .store(in: &cancellables)
    }

    //has token 函数
    
    private var hasToken: Bool {
        (UserDefaults.standard.string(forKey: "authToken") ?? "").isEmpty == false
    }

    // MARK: - Persistence
    private func saveIdeas() {
        do { UserDefaults.standard.set(try JSONEncoder().encode(ideas), forKey: ideasKey) }
        catch { print("❌ saveIdeas failed:", error) }
    }
    private func saveProjects() {
        do { UserDefaults.standard.set(try JSONEncoder().encode(projects), forKey: projectsKey) }
        catch { print("❌ saveProjects failed:", error) }
    }
    private func loadIdeas() {
        if let data = UserDefaults.standard.data(forKey: ideasKey),
           let arr = try? JSONDecoder().decode([Idea].self, from: data) {
            self.ideas = arr
        } else { self.ideas = [] }
    }
    private func loadProjects() {
        if let data = UserDefaults.standard.data(forKey: projectsKey),
           let arr = try? JSONDecoder().decode([String].self, from: data),
           !arr.isEmpty {
            self.projects = arr
        } else { self.projects = [defaultProjectName] }
    }
    private func loadSelectedProject() {
        if let sel = UserDefaults.standard.string(forKey: selectedProjectKey),
           projects.contains(sel) {
            self.selectedProject = sel
        } else { self.selectedProject = projects.first ?? defaultProjectName }
    }
    private func loadFirstLaunch() {
        self.firstLaunchDone = UserDefaults.standard.bool(forKey: firstLaunchKey)
    }
    private func ensureDefaultProjectExists() {
        if projects.isEmpty { projects = [defaultProjectName] }
        if !projects.contains(defaultProjectName) {
            projects.insert(defaultProjectName, at: 0)
        }
        if selectedProject.isEmpty { selectedProject = projects.first ?? defaultProjectName }
        if projectConfigs[defaultProjectName] == nil {
            projectConfigs[defaultProjectName] = ProjectConfig()
        }
    }
    private func saveProjectConfigs() {
        do { UserDefaults.standard.set(try JSONEncoder().encode(projectConfigs), forKey: projectConfigsKey) }
        catch { print("❌ saveProjectConfigs failed:", error) }
    }
    private func saveProjectMetas() {
        do { UserDefaults.standard.set(try JSONEncoder().encode(projectMetas), forKey: projectMetasKey) }
        catch { print("❌ saveProjectMetas failed:", error) }
    }
    private func loadProjectConfigs() {
        if let data = UserDefaults.standard.data(forKey: projectConfigsKey),
           let dict = try? JSONDecoder().decode([String: ProjectConfig].self, from: data) {
            self.projectConfigs = dict
        } else { self.projectConfigs = [:] }
    }
    private func loadProjectMetas() {
        if let data = UserDefaults.standard.data(forKey: projectMetasKey),
           let dict = try? JSONDecoder().decode([String: ProjectMeta].self, from: data) {
            self.projectMetas = dict
        } else { self.projectMetas = [:] }
    }
}

// MARK: - Color <-> Hex
extension Color {
    init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexSanitized.hasPrefix("#") {
            hexSanitized.removeFirst()
        }
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }

    func toHex() -> String? {
        let uiColor = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return String(format: "#%02X%02X%02X",
                      Int(r * 255),
                      Int(g * 255),
                      Int(b * 255))
    }
}

extension Idea: Equatable {
    static func == (lhs: Idea, rhs: Idea) -> Bool {
        lhs.id == rhs.id && lhs.content == rhs.content
    }
}
