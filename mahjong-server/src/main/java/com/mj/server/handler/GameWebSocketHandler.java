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
        System.out.println("New connection: " + session.getId());
        sessions.put(session.getId(), session);
    }
    
    @Override
    protected void handleTextMessage(WebSocketSession session, TextMessage message) throws Exception {
        try {
            Map<String, Object> msg = objectMapper.readValue(message.getPayload(), Map.class);
            String type = (String) msg.get("type");
            
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
                    sendError(session, "UNKNOWN_TYPE", "Unknown message type: " + type);
            }
        } catch (Exception e) {
            e.printStackTrace();
            sendError(session, "PARSE_ERROR", "Failed to parse message: " + e.getMessage());
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
        } else {
            sendError(session, "JOIN_FAILED", "Cannot join room");
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
                
                Map<String, Object> startMsg = new HashMap<>();
                startMsg.put("type", "GAME_START");
                startMsg.put("seed", System.currentTimeMillis());
                startMsg.put("dealerSeat", 0);
                startMsg.put("players", convertPlayersToList(room.getPlayers()));
                
                broadcastToRoom(roomId, "GAME_START", startMsg);
            }
        }
    }
    
    private void handlePlayerAction(WebSocketSession session, Map<String, Object> msg) {
        Map<String, Object> confirm = new HashMap<>();
        confirm.put("type", "ACTION_CONFIRM");
        confirm.put("accepted", true);
        sendMessage(session, confirm);
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
                broadcastToRoom(roomId, "PLAYER_LEFT", new HashMap<>());
            }
        }
    }
}
