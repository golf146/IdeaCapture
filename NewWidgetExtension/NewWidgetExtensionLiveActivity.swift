//
//  NewWidgetExtensionLiveActivity.swift
//  NewWidgetExtension
//
//  Created by ZhangYaoDong on 2025/8/9.
//

import ActivityKit
import WidgetKit
import SwiftUI

// ✅ 与主 App 保持一致的 Attributes（字段需保持完全相同）
@available(iOS 16.1, *)
struct ProjectAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var title: String
        var remainingText: String
    }
    var projectName: String
}

@available(iOS 16.1, *)
struct NewWidgetExtensionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ProjectAttributes.self) { context in
            // 锁屏 / 横幅
            if #available(iOS 17.0, *) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(context.state.title.isEmpty ? "倒计时" : context.state.title)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text(context.state.remainingText)
                        .font(.title3).bold()
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
//                .activityBackgroundTint(.thinMaterial)                 // iOS 17+: Material
                .activitySystemActionForegroundColor(.primary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text(context.state.title.isEmpty ? "倒计时" : context.state.title)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text(context.state.remainingText)
                        .font(.title3).bold()
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .activityBackgroundTint(Color(.secondarySystemBackground)) // iOS 16.x: Color
                .activitySystemActionForegroundColor(.primary)
            }

        } dynamicIsland: { context in
            DynamicIsland {
                // 展开态
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("项目")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Text(context.attributes.projectName)
                            .font(.subheadline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .padding(.leading, 10)   // ✅ 防止左上角贴边被圆角裁切
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("剩余")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Text(context.state.remainingText)
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .monospacedDigit()
                    }
                    .padding(.trailing, 10) // ✅ 防止右上角贴边被圆角裁切
                }

                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.title.isEmpty ? "倒计时进行中…" : context.state.title)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .padding(.horizontal, 10)
                }

            } compactLeading: {
                // 小岛（紧凑）左
                Image(systemName: "hourglass")

            } compactTrailing: {
                // 小岛（紧凑）右：短时间文案
                Text(shortRemaining(context.state.remainingText))
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

            } minimal: {
                // 极简态
                Image(systemName: "hourglass")
            }
            .keylineTint(.accentColor)
        }
    }
}

/// 将“2小时30分/45分钟/已到期”等文本裁成紧凑短文案（2h / 45m / 0m）
@available(iOS 16.1, *)
private func shortRemaining(_ text: String) -> String {
    if text.contains("已到期") { return "0m" }
    if let hRange = text.range(of: "小时"),
       let num = Int(text[..<hRange.lowerBound].split(whereSeparator: { !$0.isNumber }).last ?? "") {
        return "\(num)h"
    }
    if let mRange = text.range(of: "分钟"),
       let num = Int(text[..<mRange.lowerBound].split(whereSeparator: { !$0.isNumber }).last ?? "") {
        return "\(num)m"
    }
    return text
}

#if DEBUG
@available(iOS 16.1, *)
#Preview("LiveActivity Preview", as: .dynamicIsland(.expanded), using: ProjectAttributes(projectName: "示例项目")) {
    NewWidgetExtensionLiveActivity()
} contentStates: {
    ProjectAttributes.ContentState(title: "示例倒计时", remainingText: "1小时20分")
    ProjectAttributes.ContentState(title: "示例倒计时", remainingText: "45分钟")
}
#endif
