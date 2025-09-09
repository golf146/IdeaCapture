import SwiftUI

struct ProjectEditorView: View {
    @EnvironmentObject var vm: IdeaViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var newProjectName = ""
    @State private var renameFrom: String? = nil
    @State private var renameTo: String = ""
    
    var body: some View {
        NavigationStack {
            List {
                Section("项目列表") {
                    ForEach(vm.projects, id: \.self) { project in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(project)
                                if project == vm.selectedProject {
                                    Text("当前选中").font(.caption).foregroundColor(.blue)
                                }
                            }
                            Spacer()
                            Button {
                                vm.selectedProject = project
                            } label: {
                                Image(systemName: "checkmark.circle")
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                renameFrom = project
                                renameTo = project
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .onDelete { indexSet in
                        indexSet.map { vm.projects[$0] }.forEach { name in
                            vm.deleteProject(named: name)
                        }
                    }
                }
                
                Section("新建项目") {
                    HStack {
                        TextField("输入项目名称", text: $newProjectName)
                        Button("添加") {
                            vm.addProject(newProjectName)
                            newProjectName = ""
                        }
                        .disabled(newProjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .navigationTitle("编辑项目")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .alert("重命名项目", isPresented: Binding(
                get: { renameFrom != nil },
                set: { if !$0 { renameFrom = nil } })
            ) {
                TextField("新名称", text: $renameTo)
                Button("保存") {
                    if let old = renameFrom {
                        vm.renameProject(from: old, to: renameTo)
                    }
                    renameFrom = nil
                }
                Button("取消", role: .cancel) {
                    renameFrom = nil
                }
            } message: {
                Text("将项目「\(renameFrom ?? "")」重命名为：")
            }
        }
    }
}
