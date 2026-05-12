package com.mj.server.websocket;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.mj.server.model.Game;
import com.mj.server.model.GamePlayer;
import com.mj.server.model.Room;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.*;

import java.io.IOException;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Component
public class WebSocketHandler implements org.springframework.web.socket.WebSocketHandler {
    
    private final Map<String, WebSocketSession> sessions = new ConcurrentHashMap<>();
    private final Map<String, Room> rooms = new ConcurrentHashMap<>();
    private final ObjectMapper objectMapper = new ObjectMapper();
    
    @Override
    public void afterConnectionEstablished(WebSocketSession session) throws Exception {
        String playerId = session.getId();
        sessions.put(playerId, session);
        System.out.println("Player connected: " + playerId);
        
        // 发送连接成功消息
        sendMessage(session, createMessage("CONNECTED", Map.of("playerId", playerId)));
    }
    
    @Override
    public void handleMessage(WebSocketSession session, WebSocketMessage<?> message) throws Exception {
        String payload = message.getPayload().toString();
        System.out.println("Received message: " + payload);
        
        try {
            Map<String, Object> data = objectMapper.readValue(payload, Map.class);
            String type = (String) data.get("type");
            String playerId = session.getId();
            
            switch (type) {
                case "CREATE_ROOM":
                    handleCreateRoom(session, data, playerId);
                    break;
                case "JOIN_ROOM":
                    handleJoinRoom(session, data, playerId);
                    break;
                case "READY":
                    handleReady(session, data, playerId);
                    break;
                case "START_GAME":
                    handleStartGame(session, data, playerId);
                    break;
                case "DRAW_TILE":
                    handleDrawTile(session, data, playerId);
                    break;
                case "DISCARD_TILE":
                    handleDiscardTile(session, data, playerId);
                    break;
                case "GAME_ACTION":
                    handleGameAction(session, data, playerId);
                    break;
                default:
                    sendError(session, "Unknown message type: " + type);
            }
        } catch (Exception e) {
            sendError(session, "Invalid message format");
            e.printStackTrace();
        }
    }
    
    @Override
    public void handleTransportError(WebSocketSession session, Throwable exception) throws Exception {
        System.err.println("Transport error for session: " + session.getId());
        exception.printStackTrace();
    }
    
    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus closeStatus) throws Exception {
        String playerId = session.getId();
        sessions.remove(playerId);
        
        // 从房间中移除玩家
        for (Room room : rooms.values()) {
            if (room.removePlayer(playerId)) {
                broadcastToRoom(room.getRoomId(), createMessage("PLAYER_LEFT", 
                    Map.of("playerId", playerId, "players", room.getPlayers())));
                break;
            }
        }
        
        System.out.println("Player disconnected: " + playerId);
    }
    
    @Override
    public boolean supportsPartialMessages() {
        return false;
    }
    
    // 消息处理函数
    private void handleCreateRoom(WebSocketSession session, Map<String, Object> data, String playerId) {
        try {
            String playerName = (String) data.get("playerName");
            String gameMode = (String) data.get("gameMode");
            int maxPlayers = (int) data.getOrDefault("maxPlayers", 4);
            
            Room room = new Room(maxPlayers);
            rooms.put(room.getRoomId(), room);
            
            GamePlayer player = new GamePlayer(playerId, playerName, 0);
            room.addPlayer(player);
            
            sendMessage(session, createMessage("ROOM_CREATED", 
                Map.of("roomId", room.getRoomId(), "players", room.getPlayers())));
                
        } catch (Exception e) {
            sendError(session, "Failed to create room");
            e.printStackTrace();
        }
    }
    
    private void handleJoinRoom(WebSocketSession session, Map<String, Object> data, String playerId) {
        try {
            String roomId = (String) data.get("roomId");
            String playerName = (String) data.get("playerName");
            
            Room room = rooms.get(roomId);
            if (room == null) {
                sendError(session, "Room not found");
                return;
            }
            
            if (room.getPlayers().size() >= room.getMaxPlayers()) {
                sendError(session, "Room is full");
                return;
            }
            
            int seat = room.getPlayers().size();
            GamePlayer player = new GamePlayer(playerId, playerName, seat);
            room.addPlayer(player);
            
            // 通知所有玩家
            broadcastToRoom(roomId, createMessage("PLAYER_JOINED", 
                Map.of("playerId", playerId, "players", room.getPlayers())));
                
        } catch (Exception e) {
            sendError(session, "Failed to join room");
            e.printStackTrace();
        }
    }
    
    private void handleReady(WebSocketSession session, Map<String, Object> data, String playerId) {
        try {
            boolean ready = (boolean) data.get("ready");
            
            // 查找玩家所在的房间
            Room room = findPlayerRoom(playerId);
            if (room == null) {
                sendError(session, "Player not in any room");
                return;
            }
            
            room.setPlayerReady(playerId, ready);
            
            // 通知所有玩家
            broadcastToRoom(room.getRoomId(), createMessage("READY_UPDATE", 
                Map.of("playerId", playerId, "ready", ready, "players", room.getPlayers())));
                
        } catch (Exception e) {
            sendError(session, "Failed to update ready status");
            e.printStackTrace();
        }
    }
    
    private void handleStartGame(WebSocketSession session, Map<String, Object> data, String playerId) {
        try {
            Room room = findPlayerRoom(playerId);
            if (room == null) {
                sendError(session, "Player not in any room");
                return;
            }
            
            if (!room.canStartGame()) {
                sendError(session, "Cannot start game - not all players ready");
                return;
            }
            
            Game game = new Game(room.getRoomId(), room.getPlayers());
            room.setGame(game);
            game.startGame();
            
            // 通知所有玩家游戏开始
            broadcastToRoom(room.getRoomId(), createMessage("GAME_START", 
                Map.of("gameState", getGameState(game))));
                
        } catch (Exception e) {
            sendError(session, "Failed to start game");
            e.printStackTrace();
        }
    }
    
    private void handleDrawTile(WebSocketSession session, Map<String, Object> data, String playerId) {
        try {
            Room room = findPlayerRoom(playerId);
            if (room == null || room.getGame() == null) {
                sendError(session, "No active game");
                return;
            }
            
            Game game = room.getGame();
            Integer tile = game.drawTile(playerId);
            
            if (tile == null) {
                sendError(session, "Cannot draw tile");
                return;
            }
            
            // 通知所有玩家
            broadcastToRoom(room.getRoomId(), createMessage("TILE_DRAWN", 
                Map.of("playerId", playerId, "tile", tile, "remainingTiles", game.getRemainingTiles())));
                
        } catch (Exception e) {
            sendError(session, "Failed to draw tile");
            e.printStackTrace();
        }
    }
    
    private void handleDiscardTile(WebSocketSession session, Map<String, Object> data, String playerId) {
        try {
            int tile = (int) data.get("tile");
            
            Room room = findPlayerRoom(playerId);
            if (room == null || room.getGame() == null) {
                sendError(session, "No active game");
                return;
            }
            
            Game game = room.getGame();
            boolean success = game.discardTile(playerId, tile);
            
            if (!success) {
                sendError(session, "Cannot discard tile");
                return;
            }
            
            // 通知所有玩家
            broadcastToRoom(room.getRoomId(), createMessage("TILE_DISCARDED", 
                Map.of("playerId", playerId, "tile", tile, "currentPlayer", game.getCurrentPlayer())));
                
        } catch (Exception e) {
            sendError(session, "Failed to discard tile");
            e.printStackTrace();
        }
    }
    
    private void handleGameAction(WebSocketSession session, Map<String, Object> data, String playerId) {
        try {
            String action = (String) data.get("action");
            Integer tile = (Integer) data.get("tile");
            
            Room room = findPlayerRoom(playerId);
            if (room == null || room.getGame() == null) {
                sendError(session, "No active game");
                return;
            }
            
            Game game = room.getGame();
            boolean success = false;
            
            switch (action) {
                case "PONG":
                    success = game.pong(playerId, tile);
                    break;
                case "CHOW":
                    // 吃牌逻辑需要更多参数
                    break;
                case "KONG":
                    success = game.kong(playerId, tile);
                    break;
                case "WIN":
                    boolean isSelfDraw = tile != game.getLastActionTile();
                    success = game.win(playerId, tile, isSelfDraw);
                    break;
            }
            
            if (!success) {
                sendError(session, "Action failed: " + action);
                return;
            }
            
            // 通知所有玩家
            broadcastToRoom(room.getRoomId(), createMessage("GAME_ACTION", 
                Map.of("playerId", playerId, "action", action, "tile", tile)));
                
            // 检查游戏是否结束
            if (game.isGameEnded()) {
                broadcastToRoom(room.getRoomId(), createMessage("GAME_END", 
                    Map.of("winner", game.getWinner(), "scores", game.getPlayerScores())));
            }
                
        } catch (Exception e) {
            sendError(session, "Failed to perform action: " + data.get("action"));
            e.printStackTrace();
        }
    }
    
    // 辅助方法
    private Room findPlayerRoom(String playerId) {
        return rooms.values().stream()
            .filter(room -> room.getPlayers().stream()
                .anyMatch(p -> p.getPlayerId().equals(playerId)))
            .findFirst()
            .orElse(null);
    }
    
    private void broadcastToRoom(String roomId, String message) {
        Room room = rooms.get(roomId);
        if (room != null) {
            for (GamePlayer player : room.getPlayers()) {
                WebSocketSession session = sessions.get(player.getPlayerId());
                if (session != null && session.isOpen()) {
                    try {
                        session.sendMessage(new TextMessage(message));
                    } catch (IOException e) {
                        e.printStackTrace();
                    }
                }
            }
        }
    }
    
    private void sendMessage(WebSocketSession session, String message) {
        if (session.isOpen()) {
            try {
                session.sendMessage(new TextMessage(message));
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
    }
    
    private void sendError(WebSocketSession session, String error) {
        sendMessage(session, createMessage("ERROR", Map.of("message", error)));
    }
    
    private String createMessage(String type, Map<String, Object> data) {
        try {
            Map<String, Object> message = Map.of("type", type, "data", data);
            return objectMapper.writeValueAsString(message);
        } catch (Exception e) {
            e.printStackTrace();
            return "{\"type\":\"ERROR\",\"data\":{\"message\":\"Message creation failed\"}}";
        }
    }
    
    private Map<String, Object> getGameState(Game game) {
        return Map.of(
            "roomId", game.getRoomId(),
            "players", game.getPlayers(),
            "currentPlayer", game.getCurrentPlayer(),
            "remainingTiles", game.getRemainingTiles(),
            "gameStarted", game.isGameStarted(),
            "gameEnded", game.isGameEnded()
        );
    }
}