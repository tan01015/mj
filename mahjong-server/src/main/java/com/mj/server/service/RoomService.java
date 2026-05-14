package com.mj.server.service;

import com.mj.server.ai.AIPlayer;
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
    private final Map<String, Game> singlePlayerGames = new ConcurrentHashMap<>();
    private final Map<String, List<AIPlayer>> singlePlayerAIPlayers = new ConcurrentHashMap<>();
    private final Map<String, List<Thread>> singlePlayerAIThreads = new ConcurrentHashMap<>();
    
    public Room createRoom(String hostId, String playerName, String gameMode, int maxPlayers) {
        String roomId = generateRoomId();
        Room room = new Room();
        room.setRoomId(roomId);
        room.setHostId(hostId);
        room.setGameMode(gameMode);
        room.setMaxPlayers(maxPlayers);

        String name = (playerName != null && !playerName.isEmpty()) ? playerName : "玩家";
        Player host = new Player(hostId, name);
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

    public Game createSinglePlayerGame(String gameId) {
        List<GamePlayer> players = new ArrayList<>();
        for (int seat = 0; seat < 4; seat++) {
            GamePlayer gp = new GamePlayer(gameId + "-seat" + seat, "玩家" + (seat + 1));
            gp.setSeat(seat);
            players.add(gp);
        }
        Game game = new Game(gameId, players, true);
        game.startGame();
        singlePlayerGames.put(gameId, game);
        
        // 启动AI线程（座位1、2、3为AI，座位0为真人玩家）
        List<AIPlayer> aiPlayers = new ArrayList<>();
        List<Thread> aiThreads = new ArrayList<>();
        
        AIPlayer.Difficulty[] difficulties = {
            AIPlayer.Difficulty.EASY,
            AIPlayer.Difficulty.MEDIUM,
            AIPlayer.Difficulty.HARD
        };
        
        for (int seat = 1; seat <= 3; seat++) {
            String aiPlayerId = gameId + "-seat" + seat;
            AIPlayer aiPlayer = new AIPlayer(gameId, aiPlayerId, seat, difficulties[seat - 1], game);
            aiPlayers.add(aiPlayer);
            
            Thread aiThread = new Thread(aiPlayer, "AI-Thread-Seat" + seat);
            aiThread.setDaemon(true); // 守护线程，主线程结束时自动退出
            aiThread.start();
            aiThreads.add(aiThread);
            
            System.out.println("[单人模式] 启动AI线程 - 座位: " + seat + ", 难度: " + difficulties[seat - 1]);
        }
        
        singlePlayerAIPlayers.put(gameId, aiPlayers);
        singlePlayerAIThreads.put(gameId, aiThreads);
        
        return game;
    }

    public Game getSinglePlayerGame(String gameId) {
        return singlePlayerGames.get(gameId);
    }
    
    /**
     * 停止单人游戏的AI线程
     */
    public void stopSinglePlayerAI(String gameId) {
        List<AIPlayer> aiPlayers = singlePlayerAIPlayers.remove(gameId);
        List<Thread> aiThreads = singlePlayerAIThreads.remove(gameId);
        
        if (aiPlayers != null) {
            for (AIPlayer ai : aiPlayers) {
                ai.stop();
            }
            System.out.println("[单人模式] 已停止 " + aiPlayers.size() + " 个AI线程");
        }
        
        if (aiThreads != null) {
            for (Thread thread : aiThreads) {
                try {
                    thread.join(1000); // 等待最多1秒
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                }
            }
            System.out.println("[单人模式] AI线程已清理");
        }
    }
    
    /** 玩家摸牌，返回摸到的牌 */
    public Integer playerDraw(String roomId, String playerId) {
        Game game = games.get(roomId);
        if (game == null || !game.isGameStarted() || game.isGameEnded()) {
            return null;
        }
        return game.drawTile(playerId);
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
                if (tile != null) {
                    return game.pong(playerId, tile);
                }
                break;
            case "CHOW":
                if (tile != null) {
                    return game.chow(playerId, tile);
                }
                break;
            case "KONG":
                if (tile != null) {
                    return game.kong(playerId, tile);
                }
                break;
            case "WIN":
                if (tile != null) {
                    // 判断是自摸还是点炮
                    boolean isSelfDraw = "DRAW".equals(game.getLastAction());
                    return game.win(playerId, tile, isSelfDraw);
                }
                break;
            case "PASS":
                // PASS动作只在等待反应时有效
                if (game.isWaitingForReaction()) {
                    return game.resolveReaction(playerId, "PASS", null);
                }
                break;
        }
        
        return false;
    }
    
    private String generateRoomId() {
        return String.valueOf(100000 + new Random().nextInt(900000));
    }
}