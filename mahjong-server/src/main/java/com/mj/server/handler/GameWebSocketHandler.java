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
                case "HEARTBEAT":
                    handleHeartbeat(session);
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
        Room room = roomService.createRoom(playerId, gameMode, maxPlayers);
        
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
                player.setReady(true);
                
                Map<String, Object> response = new HashMap<>();
                response.put("type", "READY_UPDATE");
                response.put("players", convertPlayersToList(room.getPlayers()));
                
                broadcastToRoom(roomId, "READY_UPDATE", response);
                System.out.println("玩家准备: " + playerId + ", 房间: " + roomId);
                
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
        
        if (roomId != null) {
            Room room = roomService.getRoom(roomId);
            if (room.getHostId().equals(playerId)) {
                roomService.startGame(roomId);
                Game game = roomService.getGame(roomId);
                
                if (game != null) {
                    // 发送游戏开始消息
                    Map<String, Object> startMsg = new HashMap<>();
                    startMsg.put("type", "GAME_START");
                    startMsg.put("dealerSeat", game.getDealer());
                    startMsg.put("currentPlayer", game.getCurrentPlayer());
                    startMsg.put("players", convertPlayersToList(room.getPlayers()));
                    startMsg.put("hands", game.getPlayerHands());
                    startMsg.put("remainingTiles", game.getRemainingTiles());
                    
                    broadcastToRoom(roomId, "GAME_START", startMsg);
                    System.out.println("游戏开始: " + roomId);
                }
            }
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
            boolean success = roomService.playerAction(roomId, playerId, action, tile);
            Game game = roomService.getGame(roomId);
            
            Map<String, Object> confirm = new HashMap<>();
            confirm.put("type", "ACTION_CONFIRM");
            confirm.put("accepted", success);
            confirm.put("action", action);
            confirm.put("tile", tile);
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
    
    private void handleGameEnd(String roomId, Game game) {
        Map<String, Object> endMsg = new HashMap<>();
        endMsg.put("type", "GAME_END");
        endMsg.put("winner", game.getWinner());
        endMsg.put("scores", game.getPlayerScores());
        
        broadcastToRoom(roomId, "GAME_END", endMsg);
        System.out.println("游戏结束，房间: " + roomId + ", 获胜者: " + game.getWinner());
    }
    
    private void handleHeartbeat(WebSocketSession session) {
        Map<String, Object> response = new HashMap<>();
        response.put("type", "HEARTBEAT_ACK");
        response.put("timestamp", System.currentTimeMillis());
        sendMessage(session, response);
    }
    
    private void sendMessage(WebSocketSession session, Map<String, Object> message) {
        try {
            String json = objectMapper.writeValueAsString(message);
            session.sendMessage(new TextMessage(json));
        } catch (IOException e) {
            e.printStackTrace();
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
            playerMap.put("seat", player.getSeat());
            playerMap.put("nickname", player.getNickname());
            playerMap.put("ready", player.isReady());
            playerMap.put("online", player.isOnline());
            result.add(playerMap);
        }
        return result;
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