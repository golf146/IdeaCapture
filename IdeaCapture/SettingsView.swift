// SettingsView.swift
import SwiftUI
import UIKit
import Combine

class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock: UIInterfaceOrientationMask = .all
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
}

// MARK: - ViewModel
class SettingsViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var isLoggedIn: Bool = false
    @Published var loginMessage: String?
    @Published var devModeAllowed: Bool = false   // ✅ 新增：DEV_MODE 权限标志
    
    var cancellables = Set<AnyCancellable>()
    
    init() {
        // 恢复登录态
        if let token = UserDefaults.standard.string(forKey: "authToken"), !token.isEmpty {
            self.isLoggedIn = true
            self.email = UserDefaults.standard.string(forKey: "authEmail") ?? ""
            self.loginMessage = "已登录"
            checkDevMode() // ✅ 恢复时检查 DEV_MODE
        }
    }

    func login() {
        APIService.shared.login(email: email, password: password)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    DispatchQueue.main.async {
                        self.loginMessage = "登录失败: \(error.localizedDescription)"
                        self.isLoggedIn = false
                        self.devModeAllowed = false
                    }
                }
            }, receiveValue: { token in
                DispatchQueue.main.async {
                    self.isLoggedIn = true
                    self.loginMessage = "登录成功"
                    UserDefaults.standard.set(token, forKey: "authToken")
                    UserDefaults.standard.set(self.email, forKey: "authEmail")
                    print("保存的 Token: \(token)")
                    self.checkDevMode() // ✅ 登录成功后检查 DEV_MODE
                }
            })
            .store(in: &cancellables)
    }
    
    /// ✅ 检查 DEV_MODE 权限
    private func checkDevMode() {
        guard let token = UserDefaults.standard.string(forKey: "authToken"), !token.isEmpty else { return }
        APIService.shared.fetchUserInfo(token: token)
            .sink(receiveCompletion: { _ in }, receiveValue: { info in
                if let dev = info["DEV_MODE"] as? Bool {
                    DispatchQueue.main.async {
                        self.devModeAllowed = dev
                        print("DEV_MODE 权限：\(dev)")
                    }
                } else {
                    DispatchQueue.main.async {
                        self.devModeAllowed = false
                    }
                }
            })
            .store(in: &cancellables)
    }


    func logout() {
        UserDefaults.standard.removeObject(forKey: "authToken")
        UserDefaults.standard.removeObject(forKey: "authEmail")
        isLoggedIn = false
        devModeAllowed = false
        loginMessage = "已退出登录"
    }
}

struct SettingsView: View {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @EnvironmentObject var vm: IdeaViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settingsVM = SettingsViewModel()

    // 常规设置
    @AppStorage("showUploadJSON") private var showUploadJSON: Bool = false
    @AppStorage("useBubbleScene") private var useBubbleScene: Bool = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @AppStorage("shouldShowProjectGuideOnNextLaunch") private var shouldShowProjectGuideOnNextLaunch = false
    @State private var showEditProjects = false
    @State private var showProjectSettings = false
    @State private var showOnboarding = false

    // 开发者模式
    @AppStorage("DebugUnlocked") private var debugUnlocked: Bool = false
//    @AppStorage("DebugEnabled")  private var debugEnabled: Bool  = false
    @AppStorage("DebugEnabled")  private var debugEnabled: Bool  = true


    // BubbleScene
    @AppStorage("bubbleMode") private var bubbleModeRaw: String = BubbleMode.dvd.rawValue
    @AppStorage("bubbleSpeed") private var bubbleSpeed: Double = 1.0

    // UI
    @State private var versionTapCount = 0
    @State private var toast: String?
    @State private var showDevLockConfirm = false
    @State private var showDevWarning = false
    @State private var showAlert = false   // ✅ 新增：弹窗开关
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    private let versionString: String = {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "v\(v) (\(b))"
    }()

    var body: some View {
        NavigationView {
            Form {
                // MARK: - 用户登录
                Section(header: Text("用户登录")) {
                    if settingsVM.isLoggedIn {
                        Text("已登录: \(settingsVM.email)").foregroundColor(.green)
                        Button("退出登录") { settingsVM.logout() }
                    } else {
                        TextField("邮箱", text: $settingsVM.email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                        SecureField("密码", text: $settingsVM.password)
                        Button("登录") { settingsVM.login() }
                    }
                    if let msg = settingsVM.loginMessage {
                        Text(msg).foregroundColor(.secondary)
                    }
                }
                
                // MARK: - 云同步
                Section(header: Text("云同步（下载 / 上传）")) {
                    if vm.isSyncing {
                        HStack {
                            ProgressView().padding(.trailing, 6)
                            Text("同步中…")
                        }
                    }
                    Button("下载项目列表（覆盖本地）") {
                        vm.downloadProjects()
                        showToast("开始下载项目…")
                    }
                    Button("下载当前项目点子（覆盖本地）") {
                        vm.downloadIdeasForCurrentProject()
                        showToast("开始下载点子…")
                    }
                    Button("上传当前项目点子（覆盖云端）") {
                        vm.uploadIdeasForCurrentProject()
                        showToast("开始上传点子…")
                    }
                    Button("全量下载（项目+点子，覆盖本地）") {
                        vm.downloadAll()
                        showToast("开始全量下载…")
                    }
                    Button("全量上传（覆盖云端）") {
                        vm.uploadAll()
                        showToast("开始全量上传…")
                    }
                    if let m = vm.syncMessage, !m.isEmpty {
                        Text(m).font(.footnote).foregroundStyle(.secondary)
                    }
                }

                // MARK: - 显示设置
                Section(header: Text("显示设置")) {
                    Toggle("使用 BubbleScene 动画", isOn: $useBubbleScene)
                    Button { showEditProjects = true } label: {
                        Label("编辑项目列表", systemImage: "folder")
                    }
                }

                // MARK: - 项目
                Section(header: Text("项目")) {
                    HStack {
                        Text("当前项目")
                        Spacer()
                        Text(vm.selectedProject.isEmpty ? "未选择" : vm.selectedProject)
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        guard !vm.selectedProject.isEmpty else { return }
                        showProjectSettings = true
                    } label: {
                        Label("当前项目设置", systemImage: "gearshape")
                    }
                    .disabled(vm.selectedProject.isEmpty)
                }

                // MARK: - 关于
                Section(header: Text("关于")) {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text(versionString).foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        versionTapCount += 1
                        if versionTapCount >= 7 {
                            debugUnlocked = true
                            versionTapCount = 0
                            showToast("开发者模式已解锁")
                        }
                    }
                    if debugUnlocked {
                        Toggle("Enable Debug Menu", isOn: Binding(
                            get: { debugEnabled },
                            set: { newValue in
                                if newValue {
                                    if !settingsVM.devModeAllowed {
                                        alertTitle = "无法开启"
                                        alertMessage = "您的账户未开启开发者权限，请联系管理员。"
                                        showAlert = true
                                        debugEnabled = false
                                    } else {
                                        showDevWarning = true
                                    }
                                } else {
                                    debugEnabled = false
                                }
                            })
                        )
                        .tint(.red)
                        .alert(alertTitle, isPresented: $showAlert) {
                            Button("确定", role: .cancel) {}
                        } message: {
                            Text(alertMessage)
                        }

                        Button(role: .destructive) {
                            showDevLockConfirm = true
                        } label: {
                            Label("关闭开发者模式", systemImage: "lock.fill")
                        }
                        .confirmationDialog(
                            "关闭开发者模式？",
                            isPresented: $showDevLockConfirm,
                            titleVisibility: .visible
                        ) {
                            Button("关闭", role: .destructive) {
                                debugEnabled = false
                                debugUnlocked = false
                                versionTapCount = 0
                                showToast("开发者模式已关闭")
                            }
                            Button("取消", role: .cancel) {}
                        }
                    }
                }

                // MARK: - Developer
                if debugUnlocked && debugEnabled {
                    Section(header: Text("Developer · General")) {
                        Toggle("使用 SpriteKit Bubble Scene（同上开关）", isOn: $useBubbleScene)
                        Button("重置引导已完成标记") {
                            hasCompletedOnboarding = false
                            showToast("已重置引导页状态")
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                    NotificationCenter.default.post(name: .triggerOnboarding, object: nil)
                                }
                            }
                        }
                        Button("初始化项目引导（下次打开弹出）") {
                            shouldShowProjectGuideOnNextLaunch = true
                            showToast("已设置：下次打开弹出“首次项目引导”")
                        }
                    }
                    Section(header: Text("Developer · BubbleScene")) {
                        Picker("气泡模式", selection: Binding(
                            get: { BubbleMode(rawValue: bubbleModeRaw) ?? .dvd },
                            set: { bubbleModeRaw = $0.rawValue }
                        )) {
                            Text("DVD 弹跳").tag(BubbleMode.dvd)
                            Text("重力").tag(BubbleMode.gravity)
                        }
                        .pickerStyle(.segmented)
                        HStack {
                            Text("运行速度")
                            Slider(value: $bubbleSpeed, in: 0.2...2.0, step: 0.1)
                            Text(String(format: "%.1fx", bubbleSpeed))
                                .font(.caption).monospacedDigit()
                                .frame(width: 44, alignment: .trailing)
                        }
                    }
                    Section(header: Text("DEBUG")) {
                        Toggle("显示上传 JSON", isOn: $showUploadJSON)
                        Button("测试通知（当前项目）") {
                            guard !vm.selectedProject.isEmpty else {
                                showToast("请先选择一个项目")
                                return
                            }
                            NotificationManager.requestAuthorization { ok in
                                if ok {
                                    NotificationManager.testFireNow(projectName: vm.selectedProject)
                                    showToast("已创建测试通知")
                                } else {
                                    showToast("未获得通知权限")
                                }
                            }
                        }
                        Button("测试灵动岛（当前项目）") {
                            guard !vm.selectedProject.isEmpty else {
                                showToast("请先选择一个项目")
                                return
                            }
                            _ = LiveActivityManager.startOrUpdate(
                                projectName: vm.selectedProject,
                                targetDate: Date().addingTimeInterval(60 * 60),
                                showName: true
                            )
                            showToast("已尝试启动/更新灵动岛")
                        }
                        Button("结束灵动岛") {
                            guard !vm.selectedProject.isEmpty else {
                                showToast("请先选择一个项目")
                                return
                            }
                            LiveActivityManager.end(projectName: vm.selectedProject)
                            showToast("已尝试结束灵动岛")
                        }
                        Button { showOnboarding = true } label: {
                            Label("打开引导页（OnboardingView）", systemImage: "sparkles")
                            
                            }
                        Section(header: Text("最近请求")) {
                            Text(UserDefaults.standard.string(forKey: "lastRequestInfo") ?? "暂无请求")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                    }
                }
            }
            .navigationTitle("设置")
            .sheet(isPresented: $showEditProjects) {
                ProjectEditorView().environmentObject(vm)
            }
            .sheet(isPresented: $showProjectSettings) {
                ProjectSettingsView(project: vm.selectedProject).environmentObject(vm)
            }
            .sheet(isPresented: $showOnboarding) {
                OnboardingView().environmentObject(vm)
            }
            .overlay(alignment: .bottom) {
                if let t = toast {
                    Text(t)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.thinMaterial, in: Capsule())
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .fullScreenCover(isPresented: $showDevWarning) {
            DevModeWarningView(
                onCancel: {
                    showDevWarning = false
                    debugEnabled = false
                },
                onConfirm: {
                    showDevWarning = false
                    debugEnabled = true
                    showToast("已开启开发者模式")
                }
            )
            
            
        }
        .onAppear { applyOrientationLockForCurrentMode() }
        .onChange(of: bubbleModeRaw) { _ in applyOrientationLockForCurrentMode() }
    }

    private func applyOrientationLockForCurrentMode() {
        let mode = BubbleMode(rawValue: bubbleModeRaw) ?? .dvd
        if mode == .gravity {
            AppDelegate.orientationLock = .portrait
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
            UIViewController.attemptRotationToDeviceOrientation()
        } else {
            AppDelegate.orientationLock = .all
            UIViewController.attemptRotationToDeviceOrientation()
        }
    }

    private func showToast(_ text: String) {
        withAnimation { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation { toast = nil }
        }
    }
}

private struct DevModeWarningView: View {
    var onCancel: () -> Void
    var onConfirm: () -> Void
    @Environment(\.colorScheme) private var scheme
    @State private var ack1 = false
    @State private var ack2 = false
    var body: some View {
        ZStack {
            (scheme == .dark ? Color.black : Color.white).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.yellow)
                Text("开启开发者模式")
                    .font(.title)
                    .bold()
                VStack(spacing: 8) {
                    Text("此模式包含仍在测试阶段的 Features。").multilineTextAlignment(.center)
                    Text("这些功能可能存在不稳定性，包括应用闪退、无法启动、功能异常或数据丢失等问题。").multilineTextAlignment(.center)
                    Text("仅建议有相关经验的用户或开发者在非生产环境中使用。普通用户请谨慎启用。").multilineTextAlignment(.center)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                VStack(alignment: .leading, spacing: 14) {
                    Toggle(isOn: $ack1) { Text("我已了解：该模式可能导致未知错误与不稳定。") }
                    Toggle(isOn: $ack2) { Text("我同意自行承担因该模式产生的风险。") }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                Spacer(minLength: 10)
                VStack(spacing: 12) {
                    Button {
                        onConfirm()
                    } label: {
                        Text("我已了解风险，继续开启")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(ack1 && ack2 ? Color.red : Color.gray.opacity(0.4))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .disabled(!(ack1 && ack2))
                    Button(role: .cancel) { onCancel() } label: {
                        Text("取消").frame(maxWidth: .infinity).padding()
                    }
                }
                .padding(.horizontal)
            }
            .padding()
        }
    }
}



