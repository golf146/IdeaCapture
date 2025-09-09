//
//  NotificationManager.swift
//  IdeaCapture
//
//  Created by ZhangYaoDong on 2025/8/9.
//

import Foundation
import UserNotifications
import EventKit


enum NotificationManager {
    static func requestAuthorization(completion: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }
    
    /// 安排在目标时间前的一组提醒
    static func scheduleCountdownNotifications(projectName: String, target: Date) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers(for: projectName))
        
        let offsets: [TimeInterval] = [
            24*3600, 12*3600, 2*3600, 1*3600, 30*60, 10*60
        ]
        for off in offsets {
            let fire = target.addingTimeInterval(-off)
            guard fire > Date() else { continue }
            let content = UNMutableNotificationContent()
            content.title = "倒计时提醒：\(projectName)"
            content.body = message(for: off, project: projectName)
            content.sound = .default
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: fire.timeIntervalSinceNow, repeats: false)
            let request = UNNotificationRequest(identifier: id(for: projectName, offset: off), content: content, trigger: trigger)
            center.add(request)
        }
    }
    
    static func clear(projectName: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers(for: projectName))
    }
    
    static func testFireNow(projectName: String) {
        let content = UNMutableNotificationContent()
        content.title = "测试通知 - \(projectName)"
        content.body = "这是一条测试提醒。"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let req = UNNotificationRequest(identifier: "test-\(projectName)-\(UUID().uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }
    
    private static func message(for offset: TimeInterval, project: String) -> String {
        switch offset {
        case 24*3600: return "距离 \(project) 截止还有 24 小时。"
        case 12*3600: return "距离 \(project) 截止还有 12 小时。"
        case 2*3600:  return "距离 \(project) 截止还有 2 小时。"
        case 1*3600:  return "距离 \(project) 截止还有 1 小时。"
        case 30*60:   return "距离 \(project) 截止还有 30 分钟。"
        case 10*60:   return "距离 \(project) 截止还有 10 分钟。"
        default:       return "倒计时提醒。"
        }
    }
    
    private static func id(for project: String, offset: TimeInterval) -> String {
        "cd-\(project)-\(Int(offset))"
    }
    private static func identifiers(for project: String) -> [String] {
        [24*3600,12*3600,2*3600,1*3600,30*60,10*60].map { id(for: project, offset: TimeInterval($0)) }
    }
}
