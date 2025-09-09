import SwiftUI

#Preview {
    OnboardingView()
        .environmentObject(IdeaViewModel())
}

struct OnboardingView: View {
    @EnvironmentObject var vm: IdeaViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("DebugEnabled") private var debugEnabled = false
    
    enum Step: Int, CaseIterable {
        case welcome, intro1, intro2, intro3, devWarning, basics, details, advanced, done
    }
    @State private var step: Step = .welcome
    
    @State private var projectName: String = ""
    @State private var useExistingProject: Bool = false
    @State private var summary: String = ""
    @State private var tagsText: String = ""
    @State private var goals: String = ""
    @State private var audience: String = ""
    @State private var tone: String = ""
    @State private var enableLiveActivity: Bool = true
    @State private var showNameInIsland: Bool = true
    @State private var hasTargetDate: Bool = false
    @State private var targetDate: Date = Date().addingTimeInterval(3600 * 24)
    
    private var nextDisabled: Bool {
        switch step {
        case .basics:
            if useExistingProject {
                return vm.projects.isEmpty
            } else {
                return projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        default:
            return false
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶部标题 + 跳过按钮（仅开发者模式）
                HStack {
                    Text(titleForStep(step))
                        .font(.title2).bold()
                        .foregroundColor(debugEnabled ? .red : .primary)
                    Spacer()
                    if step != .done && debugEnabled {
                        Button("跳过") { finishAndClose() }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                
                ProgressView(value: Double(step.rawValue + 1),
                             total: Double(Step.allCases.count - (debugEnabled ? 0 : 1)))
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                
                TabView(selection: $step) {
                    welcomeView.tag(Step.welcome)
                    introView(icon: "lightbulb", title: "记录你的灵感", text: "随时随地捕捉你的想法和创意，不再担心忘记。").tag(Step.intro1)
                    introView(icon: "square.grid.2x2", title: "可视化管理", text: "用气泡或列表的方式整理你的项目和灵感。").tag(Step.intro2)
                    introView(icon: "bell.badge", title: "智能提醒", text: "设置目标日期，灵动岛和通知帮你按时完成。").tag(Step.intro3)
                    
                    if debugEnabled {
                        devWarningView.tag(Step.devWarning)
                    }
                    
                    basicsView.tag(Step.basics)
                    detailsView.tag(Step.details)
                    advancedView.tag(Step.advanced)
                    doneView.tag(Step.done)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .highPriorityGesture(DragGesture())
                
                HStack {
                    if step != .welcome && step != .done {
                        Button("上一步") { withAnimation { goPrev() } }
                            .buttonStyle(.bordered)
                            .foregroundColor(debugEnabled ? .red : .primary)
                    }
                    Spacer()
                    if step == .done {
                        Button("开始使用") { withAnimation { finishAndClose() } }
                            .buttonStyle(.borderedProminent)
                    } else {
                        Button("下一步") { withAnimation { goNext() } }
                            .buttonStyle(.borderedProminent)
                            .disabled(nextDisabled)
                    }
                }
                .padding()
            }
            .onAppear(perform: prefillFromVM)
        }
    }
    
    // MARK: - 各步骤视图
    
    private var welcomeView: some View {
        VStack {
            Spacer()
            Image("logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(radius: 8)
                .padding(.bottom, 12)
            Text("欢迎使用 IdeaCapture")
                .font(.largeTitle.bold())
            Text("你的灵感捕捉与项目管理助手")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            Spacer()
        }
    }
    
    private func introView(icon: String, title: String, text: String) -> some View {
        VStack {
            Spacer()
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.accentColor)
                .padding(.bottom, 16)
            Text(title)
                .font(.title.bold())
            Text(text)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding()
            Spacer()
        }
    }
    
    private var devWarningView: some View {
        VStack {
            Text("⚠️ 开发者模式已启动")
                .font(.title.bold())
                .foregroundColor(.white)
                .padding(.top, 30)
            Text("请确保你有能力处理错误！")
                .foregroundColor(.white.opacity(0.9))
                .padding(.bottom, 10)
            
            Form {
                Section(header: Text("应用信息").foregroundColor(.red)) {
                    Label("App 名称: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "未知")", systemImage: "app").foregroundColor(.red)
                    Label("Bundle ID: \(Bundle.main.bundleIdentifier ?? "未知")", systemImage: "number").foregroundColor(.red)
                    Label("版本号: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "未知")", systemImage: "tag").foregroundColor(.red)
                    Label("构建号: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "未知")", systemImage: "hammer").foregroundColor(.red)
                    Label("编译时间: \(buildDate)", systemImage: "clock").foregroundColor(.red)
                }
                Section(header: Text("设备信息").foregroundColor(.red)) {
                    Label("设备名称: \(UIDevice.current.name)", systemImage: "iphone").foregroundColor(.red)
                    Label("设备型号: \(UIDevice.current.model)", systemImage: "desktopcomputer").foregroundColor(.red)
                    Label("系统版本: \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)", systemImage: "gearshape").foregroundColor(.red)
                    Label("当前语言: \(Locale.current.identifier)", systemImage: "globe").foregroundColor(.red)
                    Label("区域: \(Locale.current.regionCode ?? "未知")", systemImage: "map").foregroundColor(.red)
                    Label("开发者模式: \(debugEnabled ? "是" : "否")", systemImage: "wrench").foregroundColor(.red)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.red)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.red.ignoresSafeArea())
    }
    
    private var basicsView: some View {
        Form {
            Section(header: Text("创建你的第一个项目")) {
                if debugEnabled {
                    Toggle("使用已有项目", isOn: $useExistingProject).foregroundColor(.red)
                }
                if useExistingProject && debugEnabled {
                    Picker("已有项目", selection: Binding(
                        get: { vm.selectedProject.isEmpty ? vm.projects.first ?? "" : vm.selectedProject },
                        set: { vm.selectedProject = $0 }
                    )) {
                        ForEach(vm.projects, id: \.self) { Text($0).tag($0) }
                    }
                } else {
                    TextField("输入项目名称", text: $projectName)
                        .textInputAutocapitalization(.none)
                        .disableAutocorrection(true)
                }
            }
        }
    }
    
    private var detailsView: some View {
        Form {
            Section(header: Text("项目摘要")) { TextField("一句话描述项目", text: $summary) }
            Section(header: Text("标签（逗号分隔）")) { TextField("例如：效率, 学习, iOS", text: $tagsText) }
            Section(header: Text("目标/产出")) { TextField("你希望达成什么？", text: $goals) }
            Section(header: Text("面向受众")) { TextField("读者/用户是谁？", text: $audience) }
            Section(header: Text("语气/风格")) { TextField("例如：专业、轻松、极简…", text: $tone) }
        }
    }
    
    private var advancedView: some View {
        Form {
            Section(header: Text("实时活动（灵动岛）")) {
                Toggle("启用 Live Activity", isOn: $enableLiveActivity)
                Toggle("灵动岛显示项目名称", isOn: $showNameInIsland)
            }
            Section(header: Text("目标日期")) {
                Toggle("设置目标日期/截止时间", isOn: $hasTargetDate)
                if hasTargetDate {
                    DatePicker("选择时间", selection: $targetDate, displayedComponents: [.date, .hourAndMinute])
                }
            }
        }
    }
    
    private var doneView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
            Text("全部就绪")
                .font(.title.bold())
            Text("点“开始使用”保存设置。你可以稍后在 设置 → 当前项目设置 再修改。")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
        }
    }
    
    // MARK: - 逻辑
    
    private var buildDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: Date())
    }
    
    private func goNext() {
        switch step {
        case .welcome: step = .intro1
        case .intro1: step = .intro2
        case .intro2: step = .intro3
        case .intro3: step = debugEnabled ? .devWarning : .basics
        case .devWarning: step = .basics
        case .basics: step = .details
        case .details: step = .advanced
        case .advanced: step = .done
        case .done: break
        }
    }
    
    private func goPrev() {
        switch step {
        case .welcome: break
        case .intro1: step = .welcome
        case .intro2: step = .intro1
        case .intro3: step = .intro2
        case .devWarning: step = .intro3
        case .basics: step = debugEnabled ? .devWarning : .intro3
        case .details: step = .basics
        case .advanced: step = .details
        case .done: step = .advanced
        }
    }
    
    private func finishAndClose() {
        let finalProject: String
        if useExistingProject {
            finalProject = vm.selectedProject.isEmpty ? (vm.projects.first ?? vm.defaultProjectName) : vm.selectedProject
        } else {
            let name = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
            if name.isEmpty {
                finalProject = vm.selectedProject.isEmpty ? vm.defaultProjectName : vm.selectedProject
            } else {
                finalProject = name
                if !vm.projects.contains(name) { vm.addProject(name) }
            }
        }
        
        let tags = tagsText
            .replacingOccurrences(of: "，", with: ",")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        let meta = ProjectMeta(summary: summary, tags: tags, goals: goals, audience: audience, tone: tone, createdAt: Date())
        vm.setMeta(meta, for: finalProject)
        
        var cfg = vm.ensureConfigExists(for: finalProject)
        cfg.liveActivityEnabled = enableLiveActivity
        cfg.showNameInIsland = showNameInIsland
        cfg.targetDate = hasTargetDate ? targetDate : nil
        vm.setConfig(for: finalProject, cfg)
        
        if enableLiveActivity {
            _ = LiveActivityManager.startOrUpdate(
                projectName: finalProject,
                targetDate: cfg.targetDate,
                showName: showNameInIsland
            )
        }
        
        vm.firstLaunchDone = true
        dismiss()
    }
    
    private func prefillFromVM() {
        let proj = vm.selectedProject.isEmpty ? (vm.projects.first ?? vm.defaultProjectName) : vm.selectedProject
        if proj != vm.defaultProjectName { useExistingProject = true }
        let cfg = vm.config(for: proj)
        enableLiveActivity = cfg.liveActivityEnabled
        showNameInIsland = cfg.showNameInIsland
        if let d = cfg.targetDate {
            hasTargetDate = true
            targetDate = d
        }
        if let m = vm.meta(for: proj) {
            summary = m.summary
            tagsText = m.tags.joined(separator: ", ")
            goals = m.goals
            audience = m.audience
            tone = m.tone
        }
    }
    
    private func titleForStep(_ step: Step) -> String {
        switch step {
        case .welcome: return "欢迎"
        case .intro1: return "记录灵感"
        case .intro2: return "可视化管理"
        case .intro3: return "智能提醒"
        case .devWarning: return "开发者模式"
        case .basics: return "基础信息"
        case .details: return "项目详情"
        case .advanced: return "高级设置"
        case .done: return "全部就绪"
        }
    }
}
