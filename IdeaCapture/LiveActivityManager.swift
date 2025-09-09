//
//  LiveActivityManager.swift
//  IdeaCapture
//
//  Created by ZhangYaoDong on 2025/8/9.
//

import Foundation
import ActivityKit
import EventKit


@available(iOS 16.1, *)
struct ProjectAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var title: String
        var remainingText: String
    }
    var projectName: String
}

enum LiveActivityManager {
    @discardableResult
    static func startOrUpdate(projectName: String, targetDate: Date?, showName: Bool) -> String? {
        guard #available(iOS 16.1, *) else { return nil }
        let remaining = remainingString(to: targetDate)
        let state = ProjectAttributes.ContentState(title: showName ? projectName : "倒计时", remainingText: remaining)
        let attrs = ProjectAttributes(projectName: projectName)
        
        // 如果已有同名活动，更新；否则创建
        if let activity = Activity<ProjectAttributes>.activities.first(where: { $0.attributes.projectName == projectName }) {
            Task { await activity.update(using: state) }
            return activity.id
        } else {
            do {
                let activity = try Activity<ProjectAttributes>.request(attributes: attrs, contentState: state, pushType: nil)
                return activity.id
            } catch {
                print("Live Activity start failed:", error)
                return nil
            }
        }
    }
    
    static func end(projectName: String) {
        guard #available(iOS 16.1, *) else { return }
        Activity<ProjectAttributes>.activities
            .filter { $0.attributes.projectName == projectName }
            .forEach { activity in
                Task { await activity.end(dismissalPolicy: .immediate) }
            }
    }
    
    private static func remainingString(to date: Date?) -> String {
        guard let date = date else { return "未设置日期" }
        let d = Int(date.timeIntervalSinceNow)
        if d <= 0 { return "已到期" }
        let h = d / 3600
        let m = (d % 3600) / 60
        return h > 0 ? "\(h)小时\(m)分" : "\(m)分钟"
    }
    
    static func debugDemo(projectName: String) {
        _ = startOrUpdate(projectName: projectName, targetDate: Date().addingTimeInterval(90*60), showName: true)
    }
}
