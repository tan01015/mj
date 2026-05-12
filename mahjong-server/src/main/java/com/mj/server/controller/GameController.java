package com.mj.server.controller;

import com.mj.server.model.Room;
import com.mj.server.service.RoomService;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
@RequestMapping("/api")
@CrossOrigin(origins = "*")
public class GameController {
    
    private final RoomService roomService;
    
    public GameController(RoomService roomService) {
        this.roomService = roomService;
    }
    
    @GetMapping("/rooms")
    public Map<String, Object> getRooms() {
        Map<String, Object> response = new HashMap<>();
        List<Map<String, Object>> rooms = new ArrayList<>();
        
        for (Room room : roomService.getAllRooms()) {
            Map<String, Object> roomData = new HashMap<>();
            roomData.put("roomId", room.getRoomId());
            roomData.put("hostId", room.getHostId());
            roomData.put("gameMode", room.getGameMode());
            roomData.put("playersCount", room.getPlayers().size());
            roomData.put("maxPlayers", room.getMaxPlayers());
            roomData.put("gameStarted", room.isGameStarted());
            rooms.add(roomData);
        }
        
        response.put("rooms", rooms);
        return response;
    }
}
