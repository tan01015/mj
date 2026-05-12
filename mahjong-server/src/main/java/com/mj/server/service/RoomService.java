package com.mj.server.service;

import com.mj.server.model.Game;
import com.mj.server.model.GamePlayer;
import com.mj.server.model.Player;
import com.mj.server.model.Room;
import org.springframework.stereotype.Service;

import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class RoomService {
    private final Map<String, Room> rooms = new ConcurrentHashMap<>();
    private final Map<String, Game> games = new ConcurrentHashMap<>();
    
    public Room createRoom(String hostId, String gameMode, int maxPlayers) {
        String roomId = generateRoomId();
        Room room = new Room();
        room.setRoomId(roomId);
        room.setHostId(hostId);
        room.setGameMode(gameMode);
        room.setMaxPlayers(maxPlayers);
        
        // 添加房主
        Player host = new Player(hostId, "玩家" + hostId.substring(0, 4));
        host.setSeat(0);
        room.addPlayer(host);
        
        rooms.put(roomId, room);
        return room;
    }
    
    public Room joinRoom(String roomId, Player player) {
        Room room = rooms.get(roomId);
        if (room != null && room.getPlayers().size() < room.getMaxPlayers() && !room.isGameStarted()) {
            // 分配座位
            int seat = room.getPlayers().size();
            player.setSeat(seat);
            room.addPlayer(player);
            return room;
        }
        return null;
    }
    
    public boolean leaveRoom(String roomId, String playerId) {
        Room room = rooms.get(roomId);
        if (room != null) {
            room.removePlayer(playerId);
            
            // 如果房间为空，删除房间
            if (room.getPlayers().isEmpty()) {
                rooms.remove(roomId);
                games.remove(roomId);
            }
            return true;
        }
        return false;
    }
    
    public void startGame(String roomId) {
        Room room = rooms.get(roomId);
        if (room != null && !room.isGameStarted()) {
            room.setGameStarted(true);
            
            // 创建游戏实例
            List<GamePlayer> gamePlayers = new ArrayList<>();
            for (Player player : room.getPlayers().values()) {
                GamePlayer gp = new GamePlayer(player.getPlayerId(), player.getNickname());
                gp.setSeat(player.getSeat());
                gamePlayers.add(gp);
            }
            Game game = new Game(roomId, gamePlayers);
            games.put(roomId, game);
            
            // 开始游戏
            game.startGame();
        }
    }
    
    public Game getGame(String roomId) {
        return games.get(roomId);
    }
    
    public Room getRoom(String roomId) {
        return rooms.get(roomId);
    }
    
    public Collection<Room> getAllRooms() {
        return rooms.values();
    }
    
    public boolean playerAction(String roomId, String playerId, String action, Integer tile) {
        Game game = games.get(roomId);
        if (game == null || !game.isGameStarted() || game.isGameEnded()) {
            return false;
        }
        
        switch (action) {
            case "DRAW":
                return game.drawTile(playerId) != null;
            case "DISCARD":
                if (tile != null) {
                    return game.discardTile(playerId, tile);
                }
                break;
            case "PONG":
                if (tile != null && game.getLastActionTile() != null) {
                    return game.pong(playerId, game.getLastActionTile());
                }
                break;
            case "WIN":
                if (tile != null) {
                    boolean isSelfDraw = "DRAW".equals(game.getLastAction());
                    return game.win(playerId, tile, isSelfDraw);
                }
                break;
        }
        
        return false;
    }
    
    private String generateRoomId() {
        return String.valueOf(100000 + new Random().nextInt(900000));
    }
}