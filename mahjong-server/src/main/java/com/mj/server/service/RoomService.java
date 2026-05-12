package com.mj.server.service;

import com.mj.server.model.Room;
import com.mj.server.model.Player;
import org.springframework.stereotype.Service;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class RoomService {
    private final Map<String, Room> rooms = new ConcurrentHashMap<>();
    
    public Room createRoom(String hostId, String gameMode, int maxPlayers) {
        String roomId = generateRoomId();
        Room room = new Room();
        room.setRoomId(roomId);
        room.setHostId(hostId);
        room.setGameMode(gameMode);
        room.setMaxPlayers(maxPlayers);
        
        Player host = new Player(hostId, "Host");
        host.setSeat(0);
        room.addPlayer(host);
        
        rooms.put(roomId, room);
        return room;
    }
    
    public Room joinRoom(String roomId, Player player) {
        Room room = rooms.get(roomId);
        if (room != null && !room.isFull() && !room.isGameStarted()) {
            room.addPlayer(player);
            return room;
        }
        return null;
    }
    
    public void leaveRoom(String roomId, String playerId) {
        Room room = rooms.get(roomId);
        if (room != null) {
            room.getPlayers().values().removeIf(p -> p.getPlayerId().equals(playerId));
            if (room.isEmpty()) {
                rooms.remove(roomId);
            }
        }
    }
    
    public Room getRoom(String roomId) {
        return rooms.get(roomId);
    }
    
    public List<Room> getAllRooms() {
        return new ArrayList<>(rooms.values());
    }
    
    public void startGame(String roomId) {
        Room room = rooms.get(roomId);
        if (room != null) {
            room.setGameStarted(true);
        }
    }
    
    private String generateRoomId() {
        return "room-" + UUID.randomUUID().toString().substring(0, 8);
    }
}
