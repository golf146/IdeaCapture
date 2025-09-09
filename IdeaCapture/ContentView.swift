import SwiftUI
import SpriteKit
import Combine
import Foundation
import UIKit

extension Notification.Name {
    static let triggerOnboarding = Notification.Name("triggerOnboarding")
}

struct ContentView: View {
    @EnvironmentObject var vm: IdeaViewModel
    @AppStorage("useBubbleScene") private var useBubbleScene = false
    @AppStorage("bubbleMode") private var bubbleModeRaw: String = BubbleMode.dvd.rawValue
    @AppStorage("bubbleSpeed") private var bubbleSpeed: Double = 1.0
    @AppStorage("DebugEnabled") private var debugEnabled = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("shouldShowProjectGuideOnNextLaunch") private var shouldShowProjectGuideOnNextLaunch = false

    @State private var showFirstRun = false
    @State private var showProjectGuide = false
    @Environment(\.scenePhase) private var scenePhase

    @State private var newIdea = ""
    @State private var isEditing = false
    @State private var showAllIdeas = false
    @State private var showNewProjectAlert = false
    @State private var newProjectName = ""
    @State private var bubbleScene = BubbleScene(size: .zero)

    // 侧栏
    @State private var sidebarOffset: CGFloat = 0
    @State private var isSidebarOpen = false
    @State private var showProjectEditor = false

    @State private var keyboardHeight: CGFloat = 0

    // 用于立即更新 UI 的数据源
    @State private var displayedIdeas: [Idea] = []
    
    // 拖拽起点
    @State private var dragStartX: CGFloat? = nil

    private var filteredIdeas: [Idea] {
        vm.ideas.filter { $0.project == vm.selectedProject }
    }
    private var sidebarWidth: CGFloat {
        min(320, UIScreen.main.bounds.width * 0.82)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // 侧栏
                VStack(alignment: .leading) {
                    Text("项目列表")
                        .font(.headline)
                        .padding(.top, 20)
                    ForEach(vm.projects, id: \.self) { proj in
                        Button {
                            vm.selectedProject = proj
                            closeSidebar()
                        } label: {
                            HStack {
                                Text(proj)
                                if proj == vm.selectedProject {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    Divider()
                    Button {
                        newProjectName = ""
                        showNewProjectAlert = true
                    } label: {
                        Label("新建项目", systemImage: "plus")
                    }
                    Button {
                        showProjectEditor = true
                    } label: {
                        Label("编辑项目", systemImage: "pencil")
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .frame(width: sidebarWidth, height: geo.size.height)
                .background(.ultraThinMaterial)
                .offset(x: sidebarOffset - sidebarWidth)
                .zIndex(1)

                // 主界面
                NavigationStack {
                    ZStack {
                        if useBubbleScene {
                            SpriteView(scene: bubbleScene)
                                .ignoresSafeArea()
                                .onAppear(perform: configureScene)
                                .onChange(of: filteredIdeas.map(\.content)) { _ in
                                    bubbleScene.setBubbleTexts(filteredIdeas.map(\.content))
                                }
                                .onChange(of: bubbleModeRaw) { _ in bubbleScene.reloadConfig() }
                                .onChange(of: bubbleSpeed) { _ in bubbleScene.reloadConfig() }
                        }

                        VStack(spacing: 12) {
                            Picker("选择项目", selection: $vm.selectedProject) {
                                ForEach(vm.projects, id: \.self) { Text($0).tag($0) }
                            }
                            .pickerStyle(.menu)
                            .padding(.horizontal)

                            Text("🧠 今天又想到什么点子了？")
                                .font(.title3)
                                .padding(.top, 6)

                            if !useBubbleScene {
                                BubbleCanvas(
                                    ideas: displayedIdeas,
                                    isEditing: $isEditing,
                                    onDelete: { idea in
                                        vm.deleteIdea(idea)
                                        displayedIdeas.removeAll { $0.id == idea.id }
                                    }
                                )
                            }
                            Spacer()
                        }
                    }
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                openSidebar()
                            } label: {
                                Image(systemName: "sidebar.left")
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button { showAllIdeas = true } label: {
                                Image(systemName: "list.bullet.rectangle")
                            }
                        }
                    }
                    .alert("新建项目", isPresented: $showNewProjectAlert) {
                        TextField("输入项目名称", text: $newProjectName)
                        Button("取消", role: .cancel) {}
                        Button("确定") {
                            let name = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !name.isEmpty { vm.addProject(name) }
                        }
                    }
                    .navigationDestination(isPresented: $showAllIdeas) {
                        AllIdeasView().environmentObject(vm)
                    }
                    .sheet(isPresented: $showProjectEditor) {
                        ProjectEditorView().environmentObject(vm)
                    }
                    .safeAreaInset(edge: .bottom) { inputBar }
                    .overlay(alignment: .top) {
                        if debugEnabled {
                            let h = UIScreen.main.bounds.height / 10
                            ZStack {
                                Color.yellow
                                Text("开发者模式已启用")
                                    .font(.caption2)
                                    .foregroundStyle(.black.opacity(0.75))
                                    .padding(.top, 6)
                            }
                            .frame(height: h)
                            .ignoresSafeArea(edges: .top)
                            .allowsHitTesting(false)
                        }
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .background(Color(.systemBackground))
                .offset(x: sidebarOffset)
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if dragStartX == nil {
                            dragStartX = value.startLocation.x
                        }
                        // 只有起点在左边 20px 内才允许打开
                        if dragStartX ?? 0 > 20 && !isSidebarOpen {
                            return
                        }
                        let dragX = value.translation.width
                        if dragX > 0 {
                            sidebarOffset = min(dragX + (isSidebarOpen ? sidebarWidth : 0), sidebarWidth)
                        } else {
                            sidebarOffset = max(sidebarWidth + dragX, 0)
                        }
                    }
                    .onEnded { _ in
                        if dragStartX ?? 0 > 20 && !isSidebarOpen {
                            dragStartX = nil
                            return
                        }
                        let shouldOpen = sidebarOffset > sidebarWidth * 0.4
                        withAnimation(.spring()) {
                            isSidebarOpen = shouldOpen
                            sidebarOffset = shouldOpen ? sidebarWidth : 0
                        }
                        dragStartX = nil
                    }
            )
            .onReceive(Publishers.keyboardHeight) { h in
                withAnimation(.easeOut(duration: 0.25)) {
                    keyboardHeight = h
                }
            }
            .onChange(of: filteredIdeas) { newValue in
                displayedIdeas = newValue
            }
            .onAppear {
                displayedIdeas = filteredIdeas
                if !hasCompletedOnboarding { showFirstRun = true }
            }
            .ignoresSafeArea(.keyboard)
        }
        .onReceive(NotificationCenter.default.publisher(for: .triggerOnboarding)) { _ in
            showFirstRun = true
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active, shouldShowProjectGuideOnNextLaunch {
                shouldShowProjectGuideOnNextLaunch = false
                showProjectGuide = true
            }
        }
        .fullScreenCover(isPresented: $showFirstRun, onDismiss: {
            hasCompletedOnboarding = true
        }) {
            OnboardingView().environmentObject(vm)
        }
    }

    // 输入栏
    @ViewBuilder
    private var inputBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                TextField("写下你的点子...", text: $newIdea, axis: .vertical)
                    .lineLimit(1...3)
                    .submitLabel(.send)
                    .onSubmit(sendIdea)

                if keyboardHeight > 0 {
                    Button {
                        hideKeyboard()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 0.7)
            )
            .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)

            Button(action: sendIdea) {
                Image(systemName: "paperplane.fill")
                    .imageScale(.medium)
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, 14)
                    .frame(height: 44)
            }
            .buttonStyle(.plain)
            .background(Color.blue.opacity(0.85), in: Capsule())
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 25) // 固定底边距
        .background(Color.clear)
    }

    private func sendIdea() {
        let text = newIdea.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        vm.addIdea(text)
        newIdea = ""

        if useBubbleScene {
            bubbleScene.setBubbleTexts(filteredIdeas.map(\.content) + [text])
        } else {
            displayedIdeas.append(Idea(id: UUID(), content: text, project: vm.selectedProject))
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func configureScene() {
        bubbleScene.size = UIScreen.main.bounds.size
        bubbleScene.scaleMode = .resizeFill
        bubbleScene.setBubbleTexts(filteredIdeas.map(\.content))
        bubbleScene.reloadConfig()
    }

    private func openSidebar() {
        withAnimation(.spring()) {
            isSidebarOpen = true
            sidebarOffset = sidebarWidth
        }
    }

    private func closeSidebar() {
        withAnimation(.spring()) {
            isSidebarOpen = false
            sidebarOffset = 0
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}


