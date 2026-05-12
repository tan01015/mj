# 麻将游戏项目

## 项目结构

### 鸿蒙客户端 (entry)
- pages/
  - Index.ets - 入口页面
  - SplashPage.ets - 工作室展示页
  - MainMenuPage.ets - 主菜单（单人/联机选择）
  - LobbyPage.ets - 局域网对战大厅
  - GameRoomPage.ets - 游戏房间（统一棋牌室）
  - RoomPage.ets - 房间等待页
  - GamePage.ets - 游戏对局页
- utils/
  - NetworkManager.ets - WebSocket网络管理
  - GameManager.ets - 游戏状态管理

### Java后端 (mahjong-server)
- config/ - WebSocket配置
- controller/ - REST API控制器
- handler/ - WebSocket消息处理
- model/ - 数据模型（Room, Player）
- service/ - 业务逻辑（房间管理）

## 启动步骤

### 1. 启动Java后端服务器

cd mahjong-server
mvn spring-boot:run

服务器将在 http://localhost:8080 启动

### 2. 修改客户端服务器地址

在 entry/src/main/ets/utils/NetworkManager.ets 中，将 serverUrl 改为你的服务器IP：
private serverUrl: string = 'ws://你的IP地址:8080/ws/game';

### 3. 编译运行鸿蒙应用

使用 DevEco Studio 打开项目并运行

## 功能特性

✅ 工作室展示页 - 品牌Logo和动画
✅ 主菜单 - 单人/联机模式选择
✅ 单人对战 - 点击即玩，自动配置AI对手
✅ 局域网对战 - 完整的房间管理系统
✅ 实时通信 - WebSocket实时同步
✅ 房间管理 - 创建、加入、准备、开始
✅ 游戏对局 - 出牌交互界面

## 技术栈

前端：HarmonyOS ArkTS + ArkUI
后端：Spring Boot + WebSocket
通信：JSON over WebSocket
