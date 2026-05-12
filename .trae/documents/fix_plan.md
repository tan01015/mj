# 麻将游戏鸿蒙项目修复计划

## 问题分析

通过对项目代码和构建日志的分析，发现以下主要问题：

### 1. Hvigor构建配置问题
- 构建日志显示 `hvigorfile.ts` 绑定系统插件失败，返回 `{ plugins: [] }` 而不是预期的 `{ system: [Function: appTasks], plugins: [] }`

### 2. API兼容性问题（HarmonyOS 6.0+）
- `@ohos.router` 已弃用，需使用新的路由API
- `@ohos.promptAction` 已弃用，需使用 `@kit.ArkUI` 中的相关API
- `@ohos.webSocket` 已整合到 `@kit.NetworkKit`，但API有变化

### 3. 资源文件重复定义
- `background.png`、`foreground.png`、`layered_image.json` 在 `AppScope` 和 `entry` 目录重复定义

### 4. 文件缺失
- `RoomPage.ets` 文件可能缺失（main_pages.json中定义但需要确认）

## 修复计划

### 任务1：修复 hvigorfile.ts 配置
- 更新项目根目录的 `hvigorfile.ts`，确保正确导入系统任务
- 更新 entry 模块的 `hvigorfile.ts`

### 任务2：更新路由API
- 将 `@ohos.router` 替换为 `@ohos.router` 的新导入方式

### 任务3：更新提示API
- 将 `@ohos.promptAction` 替换为 `@kit.ArkUI` 中的 `promptAction`

### 任务4：修复 WebSocket 代码
- 更新 `NetworkManager.ets` 使用正确的 WebSocket API

### 任务5：清理重复资源文件
- 删除 `entry/src/main/resources/base/media/` 中的重复文件

### 任务6：检查并修复 RoomPage.ets
- 如果文件缺失，创建一个简单的占位页面

## 预计修改文件

1. `hvigorfile.ts` - 根目录
2. `entry/hvigorfile.ts`
3. `entry/src/main/ets/entryability/EntryAbility.ets`
4. `entry/src/main/ets/pages/Index.ets`
5. `entry/src/main/ets/pages/SplashPage.ets`
6. `entry/src/main/ets/pages/MainMenuPage.ets`
7. `entry/src/main/ets/pages/LobbyPage.ets`
8. `entry/src/main/ets/pages/GameRoomPage.ets`
9. `entry/src/main/ets/pages/GamePage.ets`
10. `entry/src/main/ets/utils/NetworkManager.ets`
11. 删除重复的资源文件

## 风险评估

| 风险项 | 严重程度 | 说明 |
|--------|----------|------|
| API变更 | 中 | 需要确保使用正确的HarmonyOS 6.0+ API |
| 路由跳转 | 中 | 新版本路由API可能有不同的参数格式 |
| WebSocket连接 | 高 | 新版本WebSocket API变化较大 |

## 测试计划

1. 修复完成后执行构建验证
2. 检查APK/HAP文件是否正常生成
3. 在模拟器或真机上验证基本功能