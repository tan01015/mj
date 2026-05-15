package com.mj.server.service;

import com.mj.server.ai.AIPlayer;
import com.mj.server.model.*;
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
            // 由 Room.addPlayer 原子分配座位
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
     * 停止单人游戏的AI线程并清理相关游戏实例
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

        // 清理游戏实例，防止内存泄露或残留状态
        singlePlayerGames.remove(gameId);
    }

    /** 玩家摸牌，返回摸到的牌 */
    public Integer playerDraw(String roomId, String playerId) {
        Game game = games.get(roomId);
        if (game == null || !game.isGameStarted() || game.isGameEnded()) {
            return null;
        }
        // 权限检查：只有当前玩家在非反应状态可以摸牌
        Room room = rooms.get(roomId);
        if (room == null) return null;
        Player player = room.getPlayers().values().stream().filter(p -> p.getPlayerId().equals(playerId)).findFirst().orElse(null);
        if (player == null) return null;
        int seat = player.getSeat();

        if (game.isWaitingForReaction()) {
            // 正在等待其他玩家反应，不允许摸牌
            System.out.println("[playerDraw] 被拒绝：正在等待反应 - 玩家: " + playerId);
            return null;
        }

        if (seat != game.getCurrentPlayer()) {
            System.out.println("[playerDraw] 被拒绝：不是轮到玩家 - 玩家: " + playerId + ", seat=" + seat + ", current=" + game.getCurrentPlayer());
            return null;
        }

        return game.drawTile(playerId);
    }

    /**
     * 处理玩家动作，返回包含 accepted(boolean)、tile(Integer，可选)、reason(String，可选) 的结果。
     */
    public Map<String, Object> playerAction(String roomId, String playerId, String action, Integer tile) {
        Map<String, Object> result = new HashMap<>();
        result.put("accepted", false);
        result.put("tile", tile);

        Game game = games.get(roomId);
        if (game == null || !game.isGameStarted() || game.isGameEnded()) {
            result.put("reason", "GAME_NOT_ACTIVE");
            return result;
        }

        Room room = rooms.get(roomId);
        if (room == null) {
            result.put("reason", "ROOM_NOT_FOUND");
            return result;
        }

        Player player = room.getPlayers().values().stream().filter(p -> p.getPlayerId().equals(playerId)).findFirst().orElse(null);
        if (player == null) {
            result.put("reason", "PLAYER_NOT_IN_ROOM");
            return result;
        }

        int seat = player.getSeat();

        synchronized (game) {
            // 如果当前处于等待反应阶段，则仅允许反应相关动作
            if (game.isWaitingForReaction()) {
                // 允许的反应动作：PONG/CHOW/KONG/WIN/PASS
                if ("PONG".equals(action) || "CHOW".equals(action) || "KONG".equals(action) || "WIN".equals(action) || "PASS".equals(action)) {
                    boolean ok = game.resolveReaction(playerId, action, tile);
                    result.put("accepted", ok);
                    if (!ok) result.put("reason", "REACTION_FAILED");
                    return result;
                } else {
                    result.put("reason", "WAITING_FOR_REACTION");
                    return result;
                }
            }

            // 非反应阶段：需为当前玩家才能进行常规操作
            if (seat != game.getCurrentPlayer()) {
                result.put("reason", "NOT_YOUR_TURN");
                return result;
            }

            switch (action) {
                case "DRAW": {
                    Integer drawn = game.drawTile(playerId);
                    if (drawn != null) {
                        result.put("accepted", true);
                        result.put("tile", drawn);
                    } else {
                        result.put("reason", "DRAW_FAILED");
                    }
                    return result;
                }
                case "DISCARD": {
                    if (tile == null) {
                        result.put("reason", "NO_TILE_SPECIFIED");
                        return result;
                    }
                    boolean ok = game.discardTile(playerId, tile);
                    result.put("accepted", ok);
                    if (!ok) result.put("reason", "DISCARD_FAILED");
                    return result;
                }
                case "KONG": {
                    if (tile == null) {
                        result.put("reason", "NO_TILE_SPECIFIED");
                        return result;
                    }
                    if (!game.canKong(playerId, tile)) {
                        result.put("reason", "CANNOT_KONG");
                        return result;
                    }
                    boolean ok = game.kong(playerId, tile);
                    result.put("accepted", ok);
                    if (!ok) result.put("reason", "KONG_FAILED");
                    return result;
                }
                case "WIN": {
                    if (tile == null) {
                        result.put("reason", "NO_TILE_SPECIFIED");
                        return result;
                    }
                    boolean isSelfDraw = "DRAW".equals(game.getLastAction());
                    if (!game.canWin(playerId, tile) && !(isSelfDraw && game.canSelfDrawWin(playerId))) {
                        result.put("reason", "CANNOT_WIN");
                        return result;
                    }
                    boolean ok = game.win(playerId, tile, isSelfDraw);
                    result.put("accepted", ok);
                    if (!ok) result.put("reason", "WIN_FAILED");
                    return result;
                }
                default: {
                    result.put("reason", "INVALID_ACTION");
                    return result;
                }
            }
        }
    }

    private String generateRoomId() {
        return String.valueOf(100000 + new Random().nextInt(900000));
    }
}
