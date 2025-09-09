import SwiftUI

struct ProjectSettingsView: View {
    @EnvironmentObject var vm: IdeaViewModel
    let project: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section(header: Text("项目名称")) {
                Text(project)
                    .font(.headline)
            }

            Section(header: Text("目标日期")) {
                DatePicker(
                    "选择目标日期",
                    selection: Binding(
                        get: { vm.ensureConfigExists(for: project).targetDate ?? Date() },
                        set: { newDate in
                            var config = vm.ensureConfigExists(for: project)
                            config.targetDate = newDate
                            vm.setConfig(for: project, config)
                        }
                    ),
                    displayedComponents: [.date, .hourAndMinute]
                )
            }

            Section(header: Text("灵动岛设置")) {
                Toggle("启用灵动岛", isOn: Binding(
                    get: { vm.ensureConfigExists(for: project).liveActivityEnabled },
                    set: { newVal in
                        var config = vm.ensureConfigExists(for: project)
                        config.liveActivityEnabled = newVal
                        vm.setConfig(for: project, config)
                    }
                ))
                Toggle("在灵动岛显示项目名称", isOn: Binding(
                    get: { vm.ensureConfigExists(for: project).showNameInIsland },
                    set: { newVal in
                        var config = vm.ensureConfigExists(for: project)
                        config.showNameInIsland = newVal
                        vm.setConfig(for: project, config)
                    }
                ))
            }

            Section(header: Text("提醒与日历")) {
                Toggle("启用通知提醒", isOn: Binding(
                    get: { vm.ensureConfigExists(for: project).notifyEnabled },
                    set: { newVal in
                        var config = vm.ensureConfigExists(for: project)
                        config.notifyEnabled = newVal
                        vm.setConfig(for: project, config)
                    }
                ))
                Toggle("导入到系统日历", isOn: Binding(
                    get: { vm.ensureConfigExists(for: project).importToCalendar },
                    set: { newVal in
                        var config = vm.ensureConfigExists(for: project)
                        config.importToCalendar = newVal
                        vm.setConfig(for: project, config)
                    }
                ))
            }

            Section {
                Button("保存并应用设置") {
                    vm.applyProjectSettings(for: project)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }

            Section(header: Text("调试")) {
                Button("测试灵动岛") {
                    let cfg = vm.ensureConfigExists(for: project)
                    _ = LiveActivityManager.startOrUpdate(
                        projectName: project,
                        targetDate: cfg.targetDate,
                        showName: cfg.showNameInIsland
                    )
                }
                Button("结束灵动岛") {
                    LiveActivityManager.end(projectName: project)
                }
            }

            Section {
                Button(role: .destructive) {
                    vm.deleteProject(named: project)
                    dismiss()
                } label: {
                    Text("删除此项目")
                }
            }
        }
        .navigationTitle("项目设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

