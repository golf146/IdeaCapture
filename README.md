# IdeaCapture (Abandoned Project / 已停止维护)

> EN: IdeaCapture is an experimental iOS app built with **SwiftUI + SpriteKit**, designed to capture and visualize ideas.  
> CN: IdeaCapture 是一个使用 **SwiftUI + SpriteKit** 构建的实验性 iOS 应用，主要用于灵感捕捉与可视化管理。  

⚠️ **Status**: The project is **abandoned** and no longer maintained. / 本项目 **已弃坑，不再维护**。

---

## ✨ Features / 功能概览

- 📌 **Idea Management / 灵感管理**
  - Create, archive, delete ideas / 创建、归档、删除点子
  - Organize ideas by project / 通过项目组织点子
  - Export `.txt` file of ideas / 导出项目点子为 `.txt`

- 🎨 **Visualization / 可视化**
  - **BubbleCanvas**: SwiftUI random layout with wobble animation  
    **BubbleCanvas**：SwiftUI 随机布局 + 抖动动画  
  - **BubbleScene**: SpriteKit physics bubbles (DVD bounce or Gravity)  
    **BubbleScene**：SpriteKit 物理气泡（DVD 弹跳 / 重力模式）

  <div>
    <img src="photo/Simulator%20Screenshot%20-%2016%2018.3%20-%202025-09-09%20at%2011.51.01.png" width="260">
    <img src="photo/Simulator%20Screenshot%20-%2016%2018.3%20-%202025-09-09%20at%2011.51.05.png" width="260">
    <img src="photo/Simulator%20Screenshot%20-%2016%2018.3%20-%202025-09-09%20at%2011.51.08.png" width="260">
  </div>

- 🔔 **Notifications & Calendar / 通知与日历**
  - Local countdown notifications (24h, 12h, 2h, 1h, 30m, 10m)  
    本地倒计时提醒（24h、12h、2h、1h、30m、10m）  
  - EventKit integration, auto-create calendar events  
    集成 EventKit，自动写入日历

- 🏝️ **Live Activities / 灵动岛**
  - Real-time countdown on Dynamic Island (iOS 16.1+)  
    灵动岛实时倒计时（iOS 16.1+）  
  - Compact / Expanded / Minimal states  
    紧凑 / 展开 / 极简三种状态

- 🚀 **Onboarding / 引导**
  - Multi-step setup wizard with project details  
    多步骤引导页（摘要、标签、目标、受众、语气）  
  - Advanced options: deadline, Live Activity, notifications  
    高级选项：截止日期、灵动岛、通知  

  <div>
    <img src="photo/Simulator%20Screenshot%20-%2016%2018.3%20-%202025-09-09%20at%2011.50.38.png" width="260">
    <img src="photo/Simulator%20Screenshot%20-%2016%2018.3%20-%202025-09-09%20at%2011.50.20.png" width="260">
    <img src="photo/Simulator%20Screenshot%20-%2016%2018.3%20-%202025-09-09%20at%2011.50.15.png" width="260">
    <img src="photo/Simulator%20Screenshot%20-%2016%2018.3%20-%202025-09-09%20at%2011.50.13.png" width="260">
    <img src="photo/Simulator%20Screenshot%20-%2016%2018.3%20-%202025-09-09%20at%2011.50.11.png" width="260">
    <img src="photo/Simulator%20Screenshot%20-%2016%2018.3%20-%202025-09-09%20at%2011.50.02.png" width="260">
  </div>

- ⚙️ **Settings & Developer Mode / 设置与开发者模式**
  - Switch between BubbleCanvas and BubbleScene  
    切换可视化模式（BubbleCanvas / BubbleScene）  
  - Unlock hidden developer mode by tapping version 7 times  
    点击版本号 7 次解锁开发者模式  
  - Debug tools: force onboarding, test notifications, test Live Activity  
    调试工具：重置引导、测试通知、测试灵动岛

---

## 🛠️ Technical Details / 技术实现细节

### 1. Data Layer / 数据层
- **Idea.swift**
  - Stores `id, content, project, createdAt, fontName, fontSize, colorHex, isArchived`
  - 使用 `Codable + UserDefaults` JSON 存储
- **IdeaViewModel**
  - Manages all projects, ideas, configs, and metadata  
  - 调度通知、日历、灵动岛逻辑

---

### 2. Sidebar Gesture / 侧边栏手势
- Implemented in `ContentView.swift` using `DragGesture`  
  在 `ContentView.swift` 中使用 `DragGesture` 实现
- **Rule**:
  - Only if drag starts within left 20px → allow opening sidebar  
  - 只有手势起点在左边 20px 内才允许打开侧边栏  
- **Threshold**:  
  - If drag offset > 40% of sidebar width → open  
  - 向右拖拽超过侧边栏宽度 40% → 打开  

---

### 3. BubbleScene Physics / BubbleScene 物理模拟
- **DVD Mode / DVD 模式**
  - `restitution = 1` → 完全弹性碰撞  
  - `friction = 0` → 无摩擦  
  - Random initial velocity `-100...100`  
    初始速度随机 `-100...100`
- **Gravity Mode / 重力模式**
  - Uses `CoreMotion` accelerometer or device motion  
    使用 `CoreMotion` 加速度计或设备方向  
  - Updates physics world:
    ```swift
    let dx = g.x * gravityStrength
    let dy = g.y * gravityStrength
    physicsWorld.gravity = CGVector(dx: dx, dy: dy)
    ```
  - 实时根据设备姿态改变重力方向

---

### 4. Notifications / 通知参数
- Reminder offsets (in seconds):  
  - `[86400, 43200, 7200, 3600, 1800, 600]`  
  - 对应 **24h, 12h, 2h, 1h, 30m, 10m**  
- Trigger type: `UNTimeIntervalNotificationTrigger`

---

### 5. Live Activity / 灵动岛
- Based on **ActivityKit + WidgetKit**  
- Countdown text formatter:  
  - >1 hour → `"xh ym"`  
  - <1 hour → `"ym"`  
  - expired → `"已到期" / "Expired"`
- Compact → shows short label (e.g., `45m`)  
- Expanded → project name + countdown  

---

## 📂 Project Structure / 项目结构

```
IdeaCapture/
├── IdeaBubbleApp.swift        # App entry / 入口
├── ContentView.swift          # Main UI with Sidebar / 主界面 + 侧边栏
├── BubbleCanvas.swift         # SwiftUI bubble layout / SwiftUI 气泡布局
├── BubbleScene.swift          # SpriteKit bubble physics / SpriteKit 物理气泡
├── AllIdeasView.swift         # Idea list with search / 点子列表 + 搜索
├── ProjectEditorView.swift    # Project editing / 编辑项目
├── ProjectSettingsView.swift  # Project config / 项目配置
├── OnboardingView.swift       # Onboarding wizard / 引导页
├── SettingsView.swift         # Settings + Developer mode / 设置 + 开发者模式
├── Idea.swift                 # Data model + ViewModel / 数据模型 + VM
├── NotificationManager.swift  # Local notifications / 通知
├── CalendarManager.swift      # EventKit integration / 日历
├── LiveActivityManager.swift  # ActivityKit wrapper / 灵动岛封装
├── APIService.swift           # Mock login API / 登录接口
├── NewWidgetExtension/        # Widget + Live Activity extension / 小组件
└── web-backend/               # 后端网站（PHP + MySQL）
```

---

## 🚧 Known Limitations / 已知限制
- Mock login API (`APIService`) not connected to real backend  
  登录 API 为 mock 接口，无真实后端  
- No migration logic for persisted data  
  无数据迁移逻辑，版本升级可能丢失数据  
- Some features only available on iOS 16.1+  
  部分功能仅限 iOS 16.1+  
- 云端上传 / 服务器交互功能未公开 → 功能残缺状态

---

## 🌐 Web Backend / 网站后端

- Located in `/web-backend`  
- Built with **PHP + MySQL**  
- Provides planned API endpoints for:  
  - Idea upload & sync / 点子上传与同步  
  - User login & project binding / 用户登录与项目绑定  

---

## 📲 Installation / 安装与运行说明

1. 克隆本仓库并在 Xcode 中打开：  
   ```bash
   git clone https://github.com/JackieZ123430/IdeaCapture.git
   cd IdeaCapture
   open IdeaCapture.xcodeproj
   ```

2. **开发环境说明**  
   - 本项目开发于 **Xcode 26 beta 4**  
   - 可以在 **更高版本或正式版 Xcode** 中正常打开与运行  
   - 运行环境要求：**iOS 18 – iOS 26**

3. **功能说明**  
   - 本地功能（点子管理、项目管理、气泡可视化、通知、灵动岛倒计时等）均可正常使用  
   - **部分依赖服务器的功能（云端上传、账号验证等）目前未公开** → 功能不可用，后续可能开放  

4. **开发者模式**  
   - 原本通过 **双击版本号 7 次** 解锁的逻辑已被禁用  
   - 如需使用开发者工具，请直接在代码中手动开启：  
     ```swift
     @AppStorage("DebugEnabled") private var debugEnabled: Bool = true
     ```

---

## 📖 Contributing / 贡献

- 本项目已停止维护，**Pull Request 不再主动合并**。  
- 欢迎 fork 本仓库，用于个人学习或扩展功能。  
- 请遵守 [Apache License 2.0](./LICENSE)。

---

## 📝 Changelog / 更新记录

### v1.0.0 (2025-09-09)
- 初始开源版本  
- 包含点子管理、BubbleScene、通知、日历、灵动岛功能  
- 云端上传功能未公开  

---

## 🙏 Acknowledgements / 致谢
- Apple 官方文档（SwiftUI / SpriteKit / ActivityKit / EventKit / UserNotifications）  
- GitHub Actions for iOS CI/CD  
- 参考灵感来自 Things、Notion 等效率应用  

---

## ⚠️ Status / 状态
- EN: This project is **abandoned**, but serves as a reference for SwiftUI + SpriteKit integration, notifications, calendar, and Live Activities.  
- CN: 本项目 **已弃坑**，但可作为 SwiftUI + SpriteKit 集成、通知、日历和灵动岛的参考示例。  
