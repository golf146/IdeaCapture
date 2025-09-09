import SwiftUI
import UniformTypeIdentifiers

struct AllIdeasView: View {
    @EnvironmentObject var vm: IdeaViewModel
    @State private var showProjectSettings = false   // 当前项目子设置
    @State private var filter: Filter = .active      // 未归档/已归档/全部
    @State private var searchText = ""               // 搜索关键词
    @State private var sortOrder: SortOrder = .newest // 排序方式

    enum Filter: String, CaseIterable, Identifiable {
        case active = "未归档"
        case archived = "已归档"
        case all = "全部"
        var id: String { rawValue }
    }

    enum SortOrder: String, CaseIterable, Identifiable {
        case newest = "最新优先"
        case oldest = "最旧优先"
        case alphabetical = "按字母排序"
        var id: String { rawValue }
    }

    // 过滤 + 搜索 + 排序
    private var currentIdeas: [Idea] {
        var base = vm.ideas.filter { $0.project == vm.selectedProject }
        switch filter {
        case .active:   base = base.filter { !$0.isArchived }
        case .archived: base = base.filter {  $0.isArchived }
        case .all:      break
        }

        // 搜索
        if !searchText.isEmpty {
            base = base.filter {
                $0.content.localizedCaseInsensitiveContains(searchText) ||
                $0.project.localizedCaseInsensitiveContains(searchText)
            }
        }

        // 排序
        switch sortOrder {
        case .newest:
            return base.sorted { $0.createdAt > $1.createdAt }
        case .oldest:
            return base.sorted { $0.createdAt < $1.createdAt }
        case .alphabetical:
            return base.sorted { $0.content.localizedCompare($1.content) == .orderedAscending }
        }
    }

    // 分享用的纯文本
    private var ideasText: String {
        currentIdeas.map { "• " + $0.content }.joined(separator: "\n")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                // 顶部筛选器
                Picker("筛选", selection: $filter) {
                    ForEach(Filter.allCases) { f in Text(f.rawValue).tag(f) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                ZStack(alignment: .bottomTrailing) {
                    if currentIdeas.isEmpty {
                        ContentUnavailableView(
                            filter == .archived ? "暂无已归档点子" : "暂无点子",
                            systemImage: "tray",
                            description: Text("在主页底部输入框新增点子")
                        )
                        .padding()
                    } else {
                        List {
                            ForEach(currentIdeas) { idea in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                                        Text(idea.content)
                                            .font(.body)
                                        if idea.isArchived {
                                            Text("已归档")
                                                .font(.caption2)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(.thinMaterial, in: Capsule())
                                        }
                                    }
                                    Text(idea.project)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    if idea.isArchived {
                                        Button {
                                            unarchive(idea)
                                        } label: {
                                            Label("取消归档", systemImage: "tray.and.arrow.up")
                                        }
                                        .tint(.green)
                                    } else {
                                        Button {
                                            archive(idea)
                                        } label: {
                                            Label("归档", systemImage: "archivebox")
                                        }
                                        .tint(.orange)
                                    }

                                    Button(role: .destructive) {
                                        deleteByID(idea.id)
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                            }
                            .onDelete(perform: delete)
                        }
                        .listStyle(.insetGrouped)
                    }

                    // 分享按钮
                    ShareLink(item: makeTextFileURL(),
                              preview: SharePreview("\(vm.selectedProject)-ideas.txt")) {
                        Image(systemName: "square.and.arrow.up.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .padding(14)
                            .background(Circle().fill(Color.blue))
                            .shadow(radius: 3)
                            .padding()
                    }
                    .disabled(currentIdeas.isEmpty)
                }
            }
            .navigationTitle("点子大全")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
            .toolbar {
                // 排序菜单
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("排序", selection: $sortOrder) {
                            ForEach(SortOrder.allCases) { order in
                                Text(order.rawValue).tag(order)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
                // 项目设置
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showProjectSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .disabled(vm.selectedProject.isEmpty)
                }
            }
            .sheet(isPresented: $showProjectSettings) {
                ProjectSettingsView(project: vm.selectedProject)
                    .environmentObject(vm)
            }
            .searchable(text: $searchText, prompt: "搜索点子")
        }
    }

    // MARK: - Actions
    private func delete(at offsets: IndexSet) {
        let filtered = currentIdeas
        let idsToDelete = offsets.map { filtered[$0].id }
        vm.ideas.removeAll { idsToDelete.contains($0.id) }
    }

    private func deleteByID(_ id: UUID) {
        vm.ideas.removeAll { $0.id == id }
    }

    private func archive(_ idea: Idea) {
        if let idx = vm.ideas.firstIndex(of: idea) {
            vm.ideas[idx].isArchived = true
        }
    }

    private func unarchive(_ idea: Idea) {
        if let idx = vm.ideas.firstIndex(of: idea) {
            vm.ideas[idx].isArchived = false
        }
    }

    private func makeTextFileURL() -> URL {
        let text = ideasText.isEmpty ? "（暂无点子）" : ideasText
        let filename = "\(vm.selectedProject)-ideas.txt"
        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? text.data(using: .utf8)?.write(to: tmpURL, options: .atomic)
        return tmpURL
    }
}
