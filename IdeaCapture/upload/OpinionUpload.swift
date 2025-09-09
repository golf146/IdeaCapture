//
//  OpinionUpload.swift
//  IdeaCapture
//
//  Created by ZhangYaoDong on 2025/8/12.
//

import Foundation
import Combine
import UIKit

struct Opinion: Identifiable, Codable {
    var id: String
    var projectId: String
    var version: Int
    var opinion: String
    var createdAt: Date
    var deviceUDID: String
}

final class OpinionUpload: ObservableObject {
    static let shared = OpinionUpload()
    private init() {}
    
    @Published var opinions: [Opinion] = []
    private var cancellables = Set<AnyCancellable>()
    
    /// 添加观点
    func addOpinion(projectId: String, content: String) {
        let opinion = Opinion(
            id: UUID().uuidString,
            projectId: projectId,
            version: 1,
            opinion: content,
            createdAt: Date(),
            deviceUDID: UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        )
        opinions.append(opinion)
    }
    
    /// 清空观点
    func clearOpinions() {
        opinions.removeAll()
    }
    
    /// 上传观点（会自动包含项目数据）
    func upload(projectName: String) {
        guard let token = UserDefaults.standard.string(forKey: "authToken"), !token.isEmpty else {
            print("❌ 未登录，无法上传观点")
            return
        }
        
        // 生成一个项目 ID（你可以改成从数据库已有项目拿）
        let projectId = UUID().uuidString
        
        // 项目数据
        let projectsArray: [[String: Any]] = [[
            "id": projectId,
            "name": projectName,
            "created_at": Date().iso8601String(),
            "updated_at": Date().iso8601String(),
            "created_device_udid": UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
            "updated_device_udid": UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        ]]
        
        // 观点数据
        let opinionsArray = opinions.map { o in
            [
                "id": o.id,
                "project_id": o.projectId,
                "version": o.version,
                "opinion": o.opinion,
                "created_at": o.createdAt.iso8601String(),
                "device_udid": o.deviceUDID
            ]
        }
        
        APIService.shared.uploadProjectsAndOpinions(projects: projectsArray, opinions: opinionsArray)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("❌ 上传失败: \(error.localizedDescription)")
                }
            }, receiveValue: { success in
                if success {
                    print("✅ 观点上传成功")
                    self.clearOpinions()
                }
            })
            .store(in: &cancellables)
    }
}

// MARK: - Date 格式化
extension Date {
    func iso8601String() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }
}
