package com.mj.server.handler;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.mj.server.model.*;
import com.mj.server.service.RoomService;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.*;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import java.io.IOException;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

@Component
public class GameWebSocketHandler extends TextWebSocketHandler {
    
    private final RoomService roomService;
    private final ObjectMapper objectMapper;
    
    private final Map<String, WebSocketSession> sessions = new ConcurrentHashMap<>();
    private final Map<String, String> sessionToPlayer = new ConcurrentHashMap<>();
    private final Map<String, String> sessionToSingleGameId = new ConcurrentHashMap<>();
    
    public GameWebSocketHandler(RoomService roomService) {
        this.roomService = roomService;
        this.objectMapper = new ObjectMapper();
    }
    
    @Override
    public void afterConnectionEstablished(WebSocketSession session) throws Exception {
        System.out.println("新连接建立: " + session.getId());
        sessions.put(session.getId(), session);
    }
    
    @Override
    protected void handleTextMessage(WebSocketSession session, TextMessage message) throws Exception {
        try {
            Map<String, Object> msg = objectMapper.readValue(message.getPayload(), Map.class);
            String type = (String) msg.get("type");
            
            System.out.println("收到消息类型: " + type + ", 内容: " + msg);
            
            switch (type) {
                case "CREATE_ROOM":
                    handleCreateRoom(session, msg);
                    break;
                case "JOIN_ROOM":
                    handleJoinRoom(session, msg);
                    break;
                case "READY":
                    handleReady(session, msg);
                    break;
                case "START_GAME":
                    handleStartGame(session, msg);
                    break;
                case "PLAYER_ACTION":
                    handlePlayerAction(session, msg);
                    break;
                case "DRAW_TILE":
                    handleDrawTile(session);
                    break;
                case "DISCARD_TILE":
                    handleDiscardTile(session, msg);
                    break;
                case "GAME_ACTION":
                    handleGameAction(session, msg);
                    break;
                case "REACTION":
                    handleReaction(session, msg);
                    break;
                case "HEARTBEAT":
                    handleHeartbeat(session);
                    break;
                case "SINGLE_PLAYER_START":
                    handleSinglePlayerStart(session);
                    break;
                case "SINGLE_PLAYER_ACTION":
                    handleSinglePlayerAction(session, msg);
                    break;
                default:
                    sendError(session, "UNKNOWN_TYPE", "未知消息类型: " + type);
            }
        } catch (Exception e) {
            e.printStackTrace();
            sendError(session, "PARSE_ERROR", "消息解析失败: " + e.getMessage());
        }
    }
    
    private void handleCreateRoom(WebSocketSession session, Map<String, Object> msg) {
        String playerName = (String) msg.get("playerName");
        String gameMode = (String) msg.getOrDefault("gameMode", "standard");
        int maxPlayers = ((Number) msg.getOrDefault("maxPlayers", 4)).intValue();
        
        String playerId = UUID.randomUUID().toString();
        Room room = roomService.createRoom(playerId, playerName, gameMode, maxPlayers);
        
        sessionToPlayer.put(session.getId(), playerId);
        
        Map<String, Object> response = new HashMap<>();
        response.put("type", "ROOM_CREATED");
        response.put("roomId", room.getRoomId());
        response.put("playerId", playerId);
        response.put("seat", 0);
        
        sendMessage(session, response);
        System.out.println("房间创建成功: " + room.getRoomId() + ", 玩家: " + playerId);
    }
    
    private void handleJoinRoom(WebSocketSession session, Map<String, Object> msg) {
        String roomId = (String) msg.get("roomId");
        String playerName = (String) msg.get("playerName");
        
        String playerId = UUID.randomUUID().toString();
        Player player = new Player(playerId, playerName);
        
        Room room = roomService.joinRoom(roomId, player);
        if (room != null) {
            sessionToPlayer.put(session.getId(), playerId);
            sessions.put(session.getId(), session);
            
            Map<String, Object> response = new HashMap<>();
            response.put("type", "ROOM_JOINED");
            response.put("roomId", roomId);
            response.put("playerId", playerId);
            response.put("seat", player.getSeat());
            response.put("players", convertPlayersToList(room.getPlayers()));
            
            sendMessage(session, response);
            broadcastToRoom(roomId, "PLAYER_JOINED", response);
            System.out.println("玩家加入房间: " + playerId + ", 房间: " + roomId);
        } else {
            sendError(session, "JOIN_FAILED", "无法加入房间");
        }
    }
    
    private void handleReady(WebSocketSession session, Map<String, Object> msg) {
        String playerId = sessionToPlayer.get(session.getId());
        String roomId = findRoomByPlayer(playerId);
        
        if (roomId != null) {
            Room room = roomService.getRoom(roomId);
            Player player = room.getPlayers().values().stream()
                .filter(p -> p.getPlayerId().equals(playerId))
                .findFirst()
                .orElse(null);
            
            if (player != null) {
                Boolean ready = (Boolean) msg.getOrDefault("ready", true);
                player.setReady(ready);

                Map<String, Object> response = new HashMap<>();
                response.put("type", "READY_UPDATE");
                response.put("players", convertPlayersToList(room.getPlayers()));

                broadcastToRoom(roomId, "READY_UPDATE", response);
                System.out.println("玩家准备: " + playerId + ", 房间: " + roomId + ", 状态: " + ready);

                // 检查是否所有玩家都准备
                checkAllReady(roomId);
            }
        }
    }
    
    private void checkAllReady(String roomId) {
        Room room = roomService.getRoom(roomId);
        if (room != null) {
            boolean allReady = room.getPlayers().values().stream().allMatch(Player::isReady);
            if (allReady && room.getPlayers().size() >= 2) {
                System.out.println("所有玩家已准备，房间: " + roomId);
                
                Map<String, Object> response = new HashMap<>();
                response.put("type", "ALL_READY");
                response.put("roomId", roomId);
                
                broadcastToRoom(roomId, "ALL_READY", response);
            }
        }
    }
    
    private void handleStartGame(WebSocketSession session, Map<String, Object> msg) {
        String playerId = sessionToPlayer.get(session.getId());
        String roomId = findRoomByPlayer(playerId);

        if (roomId == null) {
            sendError(session, "NOT_IN_ROOM", "您不在任何房间中");
            return;
        }

        Room room = roomService.getRoom(roomId);
        if (room == null) {
            sendError(session, "ROOM_NOT_FOUND", "房间不存在");
            return;
        }

        if (!room.getHostId().equals(playerId)) {
            sendError(session, "NOT_HOST", "只有房主才能开始游戏");
            return;
        }

        if (room.getPlayers().size() < 2) {
            sendError(session, "NOT_ENOUGH_PLAYERS", "至少需要2名玩家才能开始游戏");
            return;
        }

        roomService.startGame(roomId);
        Game game = roomService.getGame(roomId);

        if (game != null) {
            // 发送游戏开始消息（手牌按seat索引）
            Map<String, Object> startMsg = new HashMap<>();
            startMsg.put("type", "GAME_START");
            startMsg.put("dealerSeat", game.getDealer());
            startMsg.put("currentPlayer", game.getCurrentPlayer());
            startMsg.put("players", convertPlayersToList(room.getPlayers()));
            startMsg.put("hands", game.getPlayerHandsBySeat());
            startMsg.put("remainingTiles", game.getRemainingTiles());

            broadcastToRoom(roomId, "GAME_START", startMsg);
            System.out.println("游戏开始: " + roomId + ", 庄家: " + game.getDealer() + ", 当前玩家: " + game.getCurrentPlayer());
        } else {
            sendError(session, "GAME_START_FAILED", "游戏初始化失败");
        }
    }
    
    private void handlePlayerAction(WebSocketSession session, Map<String, Object> msg) {
        String action = (String) msg.get("action");
        Object tileObj = msg.get("tile");
        Integer tile = tileObj != null ? ((Number) tileObj).intValue() : null;
        String playerId = sessionToPlayer.get(session.getId());
        String roomId = findRoomByPlayer(playerId);
        
        System.out.println("========== 玩家动作 ==========");
        System.out.println("玩家ID: " + playerId);
        System.out.println("房间ID: " + roomId);
        System.out.println("动作类型: " + action);
        System.out.println("牌: " + tile);
        System.out.println("完整消息: " + msg);
        System.out.println("================================");
        
        if (roomId != null) {
            Map<String, Object> actionResult = roomService.playerAction(roomId, playerId, action, tile);
            boolean success = (Boolean) actionResult.getOrDefault("accepted", false);
            Game game = roomService.getGame(roomId);

            // DRAW动作需要返回摸到的牌
            Integer responseTile = tile;
            if ("DRAW".equals(action) && success && game != null) {
                responseTile = game.getLastActionTile();
            }

            Map<String, Object> confirm = new HashMap<>();
            confirm.put("type", "ACTION_CONFIRM");
            confirm.put("accepted", success);
            confirm.put("action", action);
            confirm.put("tile", responseTile);
            confirm.put("playerId", playerId);
            confirm.put("roomId", roomId);

            sendMessage(session, confirm);
            System.out.println("动作处理结果: " + (success ? "成功" : "失败"));

            if (success && game != null) {
                // 广播动作给其他玩家
                Map<String, Object> broadcastMsg = new HashMap<>();
                broadcastMsg.put("type", "PLAYER_ACTION");
                broadcastMsg.put("action", action);
                broadcastMsg.put("tile", tile);
                broadcastMsg.put("playerId", playerId);
                broadcastMsg.put("seat", getPlayerSeat(roomId, playerId));
                broadcastMsg.put("currentPlayer", game.getCurrentPlayer());
                broadcastMsg.put("remainingTiles", game.getRemainingTiles());
                
                if ("DISCARD".equals(action)) {
                    broadcastToRoomExcludePlayer(roomId, "PLAYER_DISCARD", broadcastMsg, playerId);
                } else {
                    broadcastToRoom(roomId, "PLAYER_ACTION", broadcastMsg);
                }
                
                // 检查游戏是否结束
                if (game.isGameEnded()) {
                    handleGameEnd(roomId, game);
                }
            }
        }
    }
    
    // 处理摸牌：客户端发送 DRAW_TILE
    private void handleDrawTile(WebSocketSession session) {
        String playerId = sessionToPlayer.get(session.getId());
        String roomId = findRoomByPlayer(playerId);

        System.out.println("摸牌请求 - 玩家ID: " + playerId + ", 房间ID: " + roomId);

        if (roomId != null) {
            Game game = roomService.getGame(roomId);
            Integer drawnTile = roomService.playerDraw(roomId, playerId);

            Map<String, Object> confirm = new HashMap<>();
            confirm.put("type", "TILE_DRAWN");
            confirm.put("accepted", drawnTile != null);
            confirm.put("tile", drawnTile);
            confirm.put("playerId", playerId);

            sendMessage(session, confirm);

            if (drawnTile != null && game != null) {
                // 通知其他玩家有人摸牌了（不透露具体牌）
                Map<String, Object> broadcastMsg = new HashMap<>();
                broadcastMsg.put("type", "TILE_DRAWN");
                broadcastMsg.put("playerId", playerId);
                broadcastMsg.put("seat", getPlayerSeat(roomId, playerId));
                broadcastMsg.put("currentPlayer", game.getCurrentPlayer());
                broadcastMsg.put("remainingTiles", game.getRemainingTiles());

                broadcastToRoomExcludePlayer(roomId, "TILE_DRAWN", broadcastMsg, playerId);
            }
        }
    }

    // 处理出牌：客户端发送 DISCARD_TILE
    private void handleDiscardTile(WebSocketSession session, Map<String, Object> msg) {
        String playerId = sessionToPlayer.get(session.getId());
        String roomId = findRoomByPlayer(playerId);
        Object tileObj = msg.get("tile");
        Integer tile = tileObj != null ? ((Number) tileObj).intValue() : null;

        System.out.println("出牌 - 玩家ID: " + playerId + ", 牌: " + tile);

        if (roomId != null && tile != null) {
            Map<String, Object> actionResult = roomService.playerAction(roomId, playerId, "DISCARD", tile);
            boolean success = (Boolean) actionResult.getOrDefault("accepted", false);
            Game game = roomService.getGame(roomId);

            Map<String, Object> confirm = new HashMap<>();
            confirm.put("type", "ACTION_CONFIRM");
            confirm.put("accepted", success);
            confirm.put("action", "DISCARD");
            confirm.put("tile", tile);
            confirm.put("playerId", playerId);

            sendMessage(session, confirm);

            if (success && game != null) {
                Map<String, Object> broadcastMsg = new HashMap<>();
                broadcastMsg.put("type", "PLAYER_DISCARD");
                broadcastMsg.put("action", "DISCARD");
                broadcastMsg.put("tile", tile);
                broadcastMsg.put("playerId", playerId);
                broadcastMsg.put("seat", getPlayerSeat(roomId, playerId));
                broadcastMsg.put("currentPlayer", game.getCurrentPlayer());
                broadcastMsg.put("remainingTiles", game.getRemainingTiles());

                broadcastToRoomExcludePlayer(roomId, "PLAYER_DISCARD", broadcastMsg, playerId);

                if (game.isGameEnded()) {
                    handleGameEnd(roomId, game);
                }
            }
        }
    }

    // 处理游戏动作：客户端发送 GAME_ACTION (PONG/CHOW/KONG/WIN)
    private void handleGameAction(WebSocketSession session, Map<String, Object> msg) {
        String action = (String) msg.get("action");
        Object tileObj = msg.get("tile");
        Integer tile = tileObj != null ? ((Number) tileObj).intValue() : null;
        String playerId = sessionToPlayer.get(session.getId());
        String roomId = findRoomByPlayer(playerId);

        System.out.println("游戏动作 - 玩家ID: " + playerId + ", 动作: " + action + ", 牌: " + tile);

        if (roomId != null && action != null) {
            Map<String, Object> actionResult = roomService.playerAction(roomId, playerId, action, tile);
            boolean success = (Boolean) actionResult.getOrDefault("accepted", false);
            Game game = roomService.getGame(roomId);

            Map<String, Object> confirm = new HashMap<>();
            confirm.put("type", "ACTION_CONFIRM");
            confirm.put("accepted", success);
            confirm.put("action", action);
            confirm.put("tile", tile);
            confirm.put("playerId", playerId);

            sendMessage(session, confirm);

            if (success && game != null) {
                Map<String, Object> broadcastMsg = new HashMap<>();
                broadcastMsg.put("type", "PLAYER_ACTION");
                broadcastMsg.put("action", action);
                broadcastMsg.put("tile", tile);
                broadcastMsg.put("playerId", playerId);
                broadcastMsg.put("seat", getPlayerSeat(roomId, playerId));
                broadcastMsg.put("currentPlayer", game.getCurrentPlayer());
                broadcastMsg.put("remainingTiles", game.getRemainingTiles());
                // 发送所有玩家的手牌数量，用于客户端更新显示
                broadcastMsg.put("handCounts", getHandCounts(game));

                broadcastToRoom(roomId, "PLAYER_ACTION", broadcastMsg);

                if (game.isGameEnded()) {
                    handleGameEnd(roomId, game);
                }
            }
        }
    }
    
    // 处理玩家反应：客户端发送 REACTION (WIN/PONG/CHOW/KONG/PASS)
    private void handleReaction(WebSocketSession session, Map<String, Object> msg) {
        String action = (String) msg.get("action");
        Object tileObj = msg.get("tile");
        Integer tile = tileObj != null ? ((Number) tileObj).intValue() : null;
        String playerId = sessionToPlayer.get(session.getId());
        String roomId = findRoomByPlayer(playerId);

        System.out.println("玩家反应 - 玩家ID: " + playerId + ", 动作: " + action + ", 牌: " + tile);

        if (roomId != null && action != null) {
            Map<String, Object> actionResult = roomService.playerAction(roomId, playerId, action, tile);
            boolean success = (Boolean) actionResult.getOrDefault("accepted", false);
            Game game = roomService.getGame(roomId);

            Map<String, Object> confirm = new HashMap<>();
            confirm.put("type", "REACTION_CONFIRM");
            confirm.put("accepted", success);
            confirm.put("action", action);
            confirm.put("tile", tile);
            confirm.put("playerId", playerId);
            
            // 如果游戏还在等待反应，返回当前状态
            if (game != null && game.isWaitingForReaction()) {
                confirm.put("waitingForReaction", true);
                confirm.put("lastActionTile", game.getLastActionTile());
            } else {
                confirm.put("waitingForReaction", false);
                confirm.put("currentPlayer", game != null ? game.getCurrentPlayer() : -1);
            }

            sendMessage(session, confirm);

            if (success && game != null) {
                Map<String, Object> broadcastMsg = new HashMap<>();
                broadcastMsg.put("type", "PLAYER_REACTION");
                broadcastMsg.put("action", action);
                broadcastMsg.put("tile", tile);
                broadcastMsg.put("playerId", playerId);
                broadcastMsg.put("seat", getPlayerSeat(roomId, playerId));
                broadcastMsg.put("currentPlayer", game.getCurrentPlayer());
                broadcastMsg.put("remainingTiles", game.getRemainingTiles());

                broadcastToRoom(roomId, "PLAYER_REACTION", broadcastMsg);

                if (game.isGameEnded()) {
                    handleGameEnd(roomId, game);
                }
            }
        }
    }

    private void handleGameEnd(String roomId, Game game) {
        Map<String, Object> endMsg = new HashMap<>();
        endMsg.put("type", "GAME_END");
        endMsg.put("winner", game.getWinner());
        endMsg.put("scores", game.getPlayerScores());
        
        broadcastToRoom(roomId, "GAME_END", endMsg);
        System.out.println("游戏结束，房间: " + roomId + ", 获胜者: " + game.getWinner());
    }
    
    // ==================== 单人模式处理 ====================

    private void handleSinglePlayerStart(WebSocketSession session) {
        // 清理旧游戏和AI线程
        String oldGameId = sessionToSingleGameId.remove(session.getId());
        if (oldGameId != null) {
            roomService.stopSinglePlayerAI(oldGameId);
            roomService.getSinglePlayerGame(oldGameId); // 旧游戏自然被覆盖
        }

        String gameId = "single-" + UUID.randomUUID().toString().substring(0, 8);
        Game game = roomService.createSinglePlayerGame(gameId);
        sessionToSingleGameId.put(session.getId(), gameId);

        // 设置AI回合结束回调：当回合切回人类玩家或游戏结束时推送游戏状态
        game.setOnHumanTurnCallback(() -> {
            if (session.isOpen()) {
                Map<String, Object> pushMsg = new HashMap<>();
                pushMsg.put("type", "SINGLE_PLAYER_STATE_PUSH");
                pushMsg.put("currentPlayer", game.getCurrentPlayer());
                pushMsg.put("remainingTiles", game.getRemainingTiles());
                pushMsg.put("hands", game.getAllHands());
                pushMsg.put("melds", game.getAllMelds());
                pushMsg.put("discarded", game.getAllDiscarded());
                // 最近发生的动作（碰/杠/胡等）
                if (game.getLastAction() != null) {
                    pushMsg.put("lastAction", game.getLastAction());
                    pushMsg.put("lastActionSeat", game.getPlayerSeat(game.getLastActionPlayer()));
                    pushMsg.put("lastActionTile", game.getLastActionTile());
                }
                if (game.isGameEnded()) {
                    pushMsg.put("gameEnded", true);
                    pushMsg.put("winner", game.getWinner());
                    pushMsg.put("scores", game.getPlayerScores());
                    System.out.println("[回调] 游戏结束，获胜者座位: " + game.getWinner());
                }
                // 检查是否有对座位0的反应
                if (game.isWaitingForReaction()) {
                    int discardedTile = game.getLastActionTile();
                    int discarderSeat = game.getPlayerSeat(game.getLastActionPlayer());
                    pushMsg.put("waitingForReaction", true);
                    pushMsg.put("discardedTile", discardedTile);
                    pushMsg.put("discardedBy", discarderSeat);
                    Map<Integer, List<String>> reactions = game.getAvailableReactions(discardedTile);
                    pushMsg.put("reactions", reactions);
                }
                sendMessage(session, pushMsg);
                
                // 如果游戏结束，额外发送GAME_END消息
                if (game.isGameEnded()) {
                    sendSinglePlayerGameEnd(session, game);
                }
            }
        });

        Map<String, Object> startMsg = new HashMap<>();
        startMsg.put("type", "SINGLE_PLAYER_GAME_START");
        startMsg.put("gameId", gameId);
        startMsg.put("dealerSeat", game.getDealer());
        startMsg.put("currentPlayer", game.getCurrentPlayer());
        startMsg.put("players", buildPlayerList(game.getPlayers()));
        startMsg.put("hands", game.getAllHands());
        startMsg.put("melds", game.getAllMelds());
        startMsg.put("discarded", game.getAllDiscarded());
        startMsg.put("remainingTiles", game.getRemainingTiles());

        sendMessage(session, startMsg);
        System.out.println("单机游戏创建: " + gameId + ", 108张牌, 4名玩家（seat0为真人，seat1-3为AI）");
    }

    private void handleSinglePlayerAction(WebSocketSession session, Map<String, Object> msg) {
        String gameId = sessionToSingleGameId.get(session.getId());
        if (gameId == null) {
            sendError(session, "NO_GAME", "没有活跃的单人游戏");
            return;
        }

        Game game = roomService.getSinglePlayerGame(gameId);
        if (game == null || game.isGameEnded()) {
            sendError(session, "GAME_OVER", "游戏已结束");
            return;
        }

        Integer seat = msg.get("seat") != null ? ((Number) msg.get("seat")).intValue() : null;
        String action = (String) msg.get("action");
        Integer tile = msg.get("tile") != null ? ((Number) msg.get("tile")).intValue() : null;

        if (seat == null || action == null) {
            sendError(session, "INVALID_MSG", "缺少seat或action");
            return;
        }

        // 只允许真人玩家（seat 0）发送操作
        if (seat != 0) {
            sendError(session, "INVALID_PLAYER", "只有真人玩家可以发送操作");
            return;
        }

        String playerId = gameId + "-seat" + seat;
        boolean success = false;

        // 处理反应（胡、碰、吃、杠）
        if (game.isWaitingForReaction()) {
            success = game.resolveReaction(playerId, action, tile);
        } else {
            // 正常操作：摸牌、出牌、自摸胡、暗杠/加杠
            if ("DRAW".equals(action)) {
                Integer drawnTile = game.drawTile(playerId);
                success = drawnTile != null;
            } else if ("DISCARD".equals(action) && tile != null) {
                success = game.discardTile(playerId, tile);
            } else if ("WIN".equals(action)) {
                // 自摸胡牌
                success = game.win(playerId, tile != null ? tile : 0, true);
            } else if ("KONG".equals(action) && tile != null) {
                // 暗杠或加杠（非反应模式）
                success = game.kong(playerId, tile);
            } else {
                sendError(session, "INVALID_ACTION", "无效的操作: " + action);
                return;
            }
        }

        // 构建完整游戏状态响应
        Map<String, Object> response = new HashMap<>();
        response.put("type", "SINGLE_PLAYER_ACTION_CONFIRM");
        response.put("accepted", success);
        response.put("action", action);
        response.put("seat", seat);
        response.put("currentPlayer", game.getCurrentPlayer());
        response.put("remainingTiles", game.getRemainingTiles());
        
        // 获取最新的手牌数据
        Map<Integer, List<Integer>> hands = game.getAllHands();
        System.out.println("[ACTION_CONFIRM] 动作: " + action + ", seat: " + seat + ", 手牌: " + hands);
        response.put("hands", hands);
        response.put("melds", game.getAllMelds());
        response.put("discarded", game.getAllDiscarded());

        if ("DRAW".equals(action) && success && game.getLastActionTile() != null) {
            response.put("tile", game.getLastActionTile());
        }

        // 自摸胡牌/杠牌可用性
        if ("DRAW".equals(action) && success) {
            response.put("selfDrawWinAvailable", game.isSelfDrawWinAvailable());
            response.put("selfDrawKongAvailable", game.isSelfDrawKongAvailable());
        }

        // 出牌后检查反应
        if ("DISCARD".equals(action) && success && game.isWaitingForReaction()) {
            int discardedTile = game.getLastActionTile();
            Map<Integer, List<String>> reactions = game.getAvailableReactions(discardedTile);
            response.put("waitingForReaction", true);
            response.put("discardedTile", discardedTile);
            response.put("discardedBy", seat);
            response.put("reactions", reactions);
        }

        sendMessage(session, response);

        // 检查游戏是否结束
        if (game.isGameEnded()) {
            sendSinglePlayerGameEnd(session, game);
        }
    }

    private void sendSinglePlayerGameEnd(WebSocketSession session, Game game) {
        Map<String, Object> endMsg = new HashMap<>();
        endMsg.put("type", "SINGLE_PLAYER_GAME_END");
        endMsg.put("winner", game.getWinner());
        endMsg.put("scores", game.getPlayerScores());
        endMsg.put("hands", game.getAllHands());
        endMsg.put("melds", game.getAllMelds());
        endMsg.put("discarded", game.getAllDiscarded());
        sendMessage(session, endMsg);

        // 游戏结束时停止AI线程
        String gameId = sessionToSingleGameId.remove(session.getId());
        if (gameId != null) {
            roomService.stopSinglePlayerAI(gameId);
        }
        System.out.println("单机游戏结束，获胜者座位: " + game.getWinner());
    }

    private List<Map<String, Object>> buildPlayerList(List<GamePlayer> players) {
        List<Map<String, Object>> result = new ArrayList<>();
        for (GamePlayer gp : players) {
            Map<String, Object> playerMap = new HashMap<>();
            playerMap.put("seat", gp.getSeat());
            playerMap.put("nickname", gp.getNickname());
            playerMap.put("ready", gp.isReady());
            playerMap.put("online", gp.isOnline());
            result.add(playerMap);
        }
        return result;
    }

    private void handleHeartbeat(WebSocketSession session) {
        Map<String, Object> response = new HashMap<>();
        response.put("type", "HEARTBEAT_ACK");
        response.put("timestamp", System.currentTimeMillis());
        sendMessage(session, response);
    }
    
    private void sendMessage(WebSocketSession session, Map<String, Object> message) {
        if (session == null || !session.isOpen()) {
            return;
        }
        try {
            String json = objectMapper.writeValueAsString(message);
            session.sendMessage(new TextMessage(json));
        } catch (IOException e) {
            // 客户端已断开连接，忽略异常
            System.out.println("发送消息失败，连接已关闭: " + e.getMessage());
        }
    }
    
    private void broadcastToRoom(String roomId, String type, Map<String, Object> data) {
        Room room = roomService.getRoom(roomId);
        if (room != null) {
            for (Player player : room.getPlayers().values()) {
                String sessionId = findSessionByPlayer(player.getPlayerId());
                if (sessionId != null) {
                    WebSocketSession session = sessions.get(sessionId);
                    if (session != null && session.isOpen()) {
                        Map<String, Object> message = new HashMap<>(data);
                        message.put("type", type);
                        sendMessage(session, message);
                    }
                }
            }
        }
    }
    
    private void broadcastToRoomExcludePlayer(String roomId, String type, Map<String, Object> data, String excludePlayerId) {
        Room room = roomService.getRoom(roomId);
        if (room != null) {
            for (Player player : room.getPlayers().values()) {
                if (!player.getPlayerId().equals(excludePlayerId)) {
                    String sessionId = findSessionByPlayer(player.getPlayerId());
                    if (sessionId != null) {
                        WebSocketSession session = sessions.get(sessionId);
                        if (session != null && session.isOpen()) {
                            Map<String, Object> message = new HashMap<>(data);
                            message.put("type", type);
                            sendMessage(session, message);
                        }
                    }
                }
            }
        }
    }
    
    private Integer getPlayerSeat(String roomId, String playerId) {
        Room room = roomService.getRoom(roomId);
        if (room != null) {
            Player player = room.getPlayers().values().stream()
                .filter(p -> p.getPlayerId().equals(playerId))
                .findFirst()
                .orElse(null);
            return player != null ? player.getSeat() : null;
        }
        return null;
    }
    
    private void sendError(WebSocketSession session, String code, String message) {
        Map<String, Object> error = new HashMap<>();
        error.put("type", "ERROR");
        error.put("code", code);
        error.put("message", message);
        sendMessage(session, error);
    }
    
    private String findRoomByPlayer(String playerId) {
        for (Room room : roomService.getAllRooms()) {
            if (room.getPlayers().values().stream().anyMatch(p -> p.getPlayerId().equals(playerId))) {
                return room.getRoomId();
            }
        }
        return null;
    }
    
    private String findSessionByPlayer(String playerId) {
        for (Map.Entry<String, String> entry : sessionToPlayer.entrySet()) {
            if (entry.getValue().equals(playerId)) {
                return entry.getKey();
            }
        }
        return null;
    }
    
    private List<Map<String, Object>> convertPlayersToList(Map<Integer, Player> players) {
        List<Map<String, Object>> result = new ArrayList<>();
        for (Player player : players.values()) {
            Map<String, Object> playerMap = new HashMap<>();
            playerMap.put("playerId", player.getPlayerId());
            playerMap.put("seat", player.getSeat());
            playerMap.put("nickname", player.getNickname());
            playerMap.put("ready", player.isReady());
            playerMap.put("online", player.isOnline());
            result.add(playerMap);
        }
        return result;
    }
    
    /**
     * 获取所有玩家的手牌数量
     */
    private Map<Integer, Integer> getHandCounts(Game game) {
        Map<Integer, Integer> handCounts = new HashMap<>();
        Map<Integer, List<Integer>> hands = game.getPlayerHandsBySeat();
        for (Map.Entry<Integer, List<Integer>> entry : hands.entrySet()) {
            handCounts.put(entry.getKey(), entry.getValue().size());
        }
        return handCounts;
    }
    
    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) throws Exception {
        String playerId = sessionToPlayer.remove(session.getId());
        sessions.remove(session.getId());
        
        if (playerId != null) {
            String roomId = findRoomByPlayer(playerId);
            if (roomId != null) {
                roomService.leaveRoom(roomId, playerId);
                
                Map<String, Object> leaveMsg = new HashMap<>();
                leaveMsg.put("type", "PLAYER_LEFT");
                leaveMsg.put("playerId", playerId);
                
                broadcastToRoom(roomId, "PLAYER_LEFT", leaveMsg);
            }
        }
        
        System.out.println("连接关闭: " + session.getId() + ", 状态: " + status);
    }
}