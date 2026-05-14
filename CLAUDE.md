# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a HarmonyOS (OpenHarmony) ArkTS client + Java Spring Boot backend for a 4-player Mahjong game. It supports single-player (vs AI) and LAN multiplayer via WebSocket.

## Build & Run Commands

### HarmonyOS Client (`entry/`)

The client is built with DevEco Studio's Hvigor build system. There is no `package.json` with npm scripts.

- **Build HAP**: `hvigorw assembleHap` (or use DevEco Studio's Build menu)
- **Run tests**: Tests use the Hypium framework (`@ohos/hypium`). Run via DevEco Studio's test runner or `hvigorw test`.
- **Lint**: Configured in `code-linter.json5`. Run via DevEco Studio or `hvigorw lint`.
- **Preview**: Use DevEco Studio Previewer for UI preview.

The client targets **HarmonyOS 6.0.2(22)** and runs in **landscape** orientation (`module.json5`).

### Java Backend (`mahjong-server/`)

- **Run server**: `cd mahjong-server && mvn spring-boot:run`
- **Server port**: `8082` (configured in `application.yml`, not 8080)
- **Build**: `cd mahjong-server && mvn clean compile`
- **Java version**: 17
- **Framework**: Spring Boot 3.2.0 with WebSocket support

## Architecture

### Client Architecture

The client follows a page-based ArkUI architecture with a centralized state and network layer:

**Page Flow**: `Index` -> `SplashPage` -> `MainMenuPage` -> (`GameRoomPage` for single-player | `LobbyPage` -> `RoomPage` -> `GameRoomPage` for multiplayer) -> `GamePage`

**Key Layers**:
- **Pages** (`entry/src/main/ets/pages/`): ArkUI `@Component` structs. `GamePage` is the main gameplay UI.
- **Game State** (`utils/GameManager.ets`): Singleton reactive state manager. Components subscribe to state changes via `gameManager.subscribe()`. Holds room info, hand tiles, melds, current player, etc.
- **Network** (`utils/NetworkManager.ets`): Singleton WebSocket client. Message types are handled via `networkManager.on(type, handler)`. The server URL is hardcoded to `ws://192.168.189.217:8082/ws/game` — update this for your local network.
- **Engine** (`engine/`):
  - `MahjongRules.ets`: Static utility class for tile definitions, win/chow/pong/kong logic, and scoring. **Must call `MahjongRules.initialize()` before use.**
  - `MahjongGame.ets`: Client-side game state machine (dealing, playing, ended phases). Used for single-player local games.
- **AI** (`ai/AdvancedAI.ets`): Rule-based AI with three difficulty levels (`EASY`, `MEDIUM`, `HARD`). Used in single-player mode.
- **Statistics** (`utils/StatisticsManager.ets`): Local persistence for win/loss stats and leaderboard.

### Server Architecture

- **WebSocket endpoint**: `/ws/game`
- **Message handler**: `GameWebSocketHandler.java` dispatches by message type: `CREATE_ROOM`, `JOIN_ROOM`, `READY`, `START_GAME`, `PLAYER_ACTION`, `HEARTBEAT`
- **Services**: `RoomService.java` manages in-memory rooms and game lifecycle. Games are stored in a `ConcurrentHashMap` by room ID.
- **Models**: `Room`, `Player`, `Game`, `GamePlayer`

### Client-Server Protocol

All messages are JSON over WebSocket. Key message types:
- Client -> Server: `CREATE_ROOM`, `JOIN_ROOM`, `READY`, `START_GAME`, `PLAYER_ACTION` (with `action` and `tile` fields)
- Server -> Client: `ROOM_CREATED`, `ROOM_JOINED`, `PLAYER_JOINED`, `READY_UPDATE`, `ALL_READY`, `GAME_START`, `ACTION_CONFIRM`, `PLAYER_ACTION`, `PLAYER_DISCARD`, `GAME_END`, `ERROR`

The server broadcasts state changes to all players in a room.

## Critical Implementation Details

### Tile ID System

The client and server use **different tile ID schemes**. This is a known inconsistency:

**Client** (`MahjongRules.ets`):
- 万 (Character): 1-9
- 条 (Bamboo): 11-19
- 筒 (Dot): 21-29
- 字牌 (Honor): 31-37 (东南西北中发白)
- 花牌 (Flower): 41-48

**Server** (`Game.java`):
- Uses 1-136 sequential IDs with type/value derived by modular arithmetic (`getTileType` / `getTileValue`).

When modifying game logic, be careful which side you are on. The WebSocket messages currently send raw tile numbers, so client and server tile systems must be aligned at the protocol level or a mapping layer must be introduced.

### Single-Player vs Multiplayer

- **Single-player**: `GameRoomPage` initializes a local game using `MahjongGame` engine and `AdvancedAI` opponents. No WebSocket connection is used.
- **Multiplayer**: `LobbyPage` connects via `NetworkManager` to the Java backend. `GameManager` is updated from server messages.

### Game Action Flow

1. Player receives turn (`currentPlayer === seat`)
2. For multiplayer: client sends `PLAYER_ACTION` with `action: "DISCARD"` and `tile` to server
3. Server validates, updates `Game` state, broadcasts `PLAYER_DISCARD` / `PLAYER_ACTION` to room
4. Client `GamePage` receives broadcast and updates `GameManager` state
5. AI turns in single-player are triggered automatically by `GamePage` calling `AdvancedAI.makeDecision()`

### Important Files

- `entry/src/main/ets/utils/NetworkManager.ets` — WebSocket URL and message routing
- `entry/src/main/ets/utils/GameManager.ets` — Reactive game state
- `entry/src/main/ets/engine/MahjongRules.ets` — Client tile definitions and rule logic
- `mahjong-server/src/main/java/com/mj/server/handler/GameWebSocketHandler.java` — Server message dispatch
- `mahjong-server/src/main/java/com/mj/server/service/RoomService.java` — Room/game lifecycle
- `mahjong-server/src/main/java/com/mj/server/model/Game.java` — Server game logic and tile system
