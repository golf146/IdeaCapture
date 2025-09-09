//
//  CalendarManager.swift
//  IdeaCapture
//
//  Created by ZhangYaoDong on 2025/8/9.
//

import Foundation
import EventKit

final class CalendarManager {
    private let store = EKEventStore()
    
    enum Access {
        case authorized, denied, notDetermined
    }
    
    /// 当前授权状态（不触发系统弹窗）
    var status: Access {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .authorized:
            return .authorized
        case .notDetermined:
            return .notDetermined
        default:
            return .denied
        }
    }
    
    /// 触发系统权限弹窗（仅在 .notDetermined 时会弹）
    func requestAccess(completion: @escaping (Bool) -> Void) {
        store.requestAccess(to: .event) { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }
    
    /// 创建或更新事件；自动兜底选择一个可写日历
    func upsertEvent(title: String, notes: String?, date: Date, existingId: String?) -> String? {
        let event: EKEvent
        if let id = existingId, let e = store.event(withIdentifier: id) {
            event = e
        } else {
            event = EKEvent(eventStore: store)
        }
        
        event.title = title
        event.notes = notes
        event.startDate = date
        event.endDate = date.addingTimeInterval(60 * 30) // 默认半小时
        
        // 优先默认日历；若为空，挑选第一个允许写入的日历
        if let def = store.defaultCalendarForNewEvents {
            event.calendar = def
        } else {
            let writable = store.calendars(for: .event).first { $0.allowsContentModifications }
            event.calendar = writable
        }
        
        do {
            try store.save(event, span: .thisEvent)
            return event.eventIdentifier
        } catch {
            print("Calendar save error: \(error)")
            return nil
        }
    }
    
    func removeEvent(id: String) {
        if let e = store.event(withIdentifier: id) {
            do {
                try store.remove(e, span: .thisEvent)
            } catch {
                print("Calendar remove error: \(error)")
            }
        }
    }
}
