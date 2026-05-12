package com.mj.server.model;

import java.util.*;

public class Game {
    private String roomId;
    private List<GamePlayer> players;
    private List<Integer> deck;
    private List<Integer> wall;
    private int currentPlayer;
    private int remainingTiles;
    private boolean gameStarted;
    private boolean gameEnded;
    private Integer winner;
    private int dealer;
    private int round;
    private Map<String, List<Integer>> playerHands;
    private Map<String, List<Integer>> playerDiscarded;
    private Map<String, List<List<Integer>>> playerMelds;
    private Map<String, Integer> playerScores;
    private String lastActionPlayer;
    private String lastAction;
    private Integer lastActionTile;
    
    public Game(String roomId, List<GamePlayer> players) {
        this.roomId = roomId;
        this.players = new ArrayList<>(players);
        this.deck = new ArrayList<>();
        this.wall = new ArrayList<>();
        this.playerHands = new HashMap<>();
        this.playerDiscarded = new HashMap<>();
        this.playerMelds = new HashMap<>();
        this.playerScores = new HashMap<>();
        this.currentPlayer = 0;
        this.remainingTiles = 136;
        this.gameStarted = false;
        this.gameEnded = false;
        this.dealer = 0;
        this.round = 1;
        
        // 初始化玩家数据
        for (GamePlayer player : players) {
            playerHands.put(player.getPlayerId(), new ArrayList<>());
            playerDiscarded.put(player.getPlayerId(), new ArrayList<>());
            playerMelds.put(player.getPlayerId(), new ArrayList<>());
            playerScores.put(player.getPlayerId(), 0);
        }
        
        initializeDeck();
    }
    
    private void initializeDeck() {
        deck.clear();
        
        // 创建136张标准麻将牌
        for (int i = 1; i <= 136; i++) {
            deck.add(i);
        }
        
        // 洗牌
        shuffleDeck();
        
        // 初始化牌墙
        wall = new ArrayList<>(deck);
        remainingTiles = wall.size();
    }
    
    private void shuffleDeck() {
        Collections.shuffle(deck);
    }
    
    public void startGame() {
        if (gameStarted) return;
        
        gameStarted = true;
        dealInitialHands();
    }
    
    private void dealInitialHands() {
        // 每人发13张牌
        for (int i = 0; i < players.size(); i++) {
            GamePlayer player = players.get(i);
            List<Integer> hand = playerHands.get(player.getPlayerId());
            
            for (int j = 0; j < 13; j++) {
                if (!wall.isEmpty()) {
                    int tile = wall.remove(0);
                    hand.add(tile);
                }
            }
            
            // 排序手牌
            Collections.sort(hand);
        }
        
        remainingTiles = wall.size();
    }
    
    public Integer drawTile(String playerId) {
        GamePlayer player = getPlayerById(playerId);
        if (player == null || getPlayerSeat(playerId) != currentPlayer || !gameStarted || gameEnded) {
            return null;
        }
        
        if (wall.isEmpty()) {
            endGame(); // 流局
            return null;
        }
        
        int tile = wall.remove(0);
        List<Integer> hand = playerHands.get(playerId);
        hand.add(tile);
        remainingTiles = wall.size();
        
        return tile;
    }
    
    public boolean discardTile(String playerId, int tile) {
        GamePlayer player = getPlayerById(playerId);
        if (player == null || getPlayerSeat(playerId) != currentPlayer || !gameStarted || gameEnded) {
            return false;
        }
        
        List<Integer> hand = playerHands.get(playerId);
        List<Integer> discarded = playerDiscarded.get(playerId);
        
        if (!hand.contains(tile)) {
            return false;
        }
        
        // 移除手牌
        hand.remove(Integer.valueOf(tile));
        discarded.add(tile);
        
        lastActionPlayer = playerId;
        lastAction = "DISCARD";
        lastActionTile = tile;
        
        // 切换到下一位玩家
        currentPlayer = (currentPlayer + 1) % players.size();
        
        return true;
    }
    
    public boolean canPong(String playerId, int tile) {
        List<Integer> hand = playerHands.get(playerId);
        
        // 检查手牌中是否有两张相同的牌
        long count = hand.stream()
            .filter(t -> getTileType(t) == getTileType(tile) && getTileValue(t) == getTileValue(tile))
            .count();
        
        return count >= 2;
    }
    
    public boolean pong(String playerId, int tile) {
        if (!"DISCARD".equals(lastAction) || !canPong(playerId, tile)) {
            return false;
        }
        
        List<Integer> hand = playerHands.get(playerId);
        List<Integer> discarded = playerDiscarded.get(lastActionPlayer);
        List<List<Integer>> melds = playerMelds.get(playerId);
        
        // 从手牌移除两张相同的牌
        List<Integer> sameTiles = hand.stream()
            .filter(t -> getTileType(t) == getTileType(tile) && getTileValue(t) == getTileValue(tile))
            .limit(2)
            .collect(ArrayList::new, ArrayList::add, ArrayList::addAll);
        
        hand.removeAll(sameTiles);
        
        // 创建碰牌组合
        List<Integer> pongMeld = new ArrayList<>(sameTiles);
        pongMeld.add(tile);
        Collections.sort(pongMeld);
        melds.add(pongMeld);
        
        // 从弃牌堆移除碰的牌
        discarded.remove(Integer.valueOf(tile));
        
        lastActionPlayer = playerId;
        lastAction = "PONG";
        lastActionTile = tile;
        
        currentPlayer = getPlayerSeat(playerId);
        
        return true;
    }
    
    public boolean canWin(String playerId, int tile) {
        List<Integer> hand = playerHands.get(playerId);
        List<Integer> testHand = new ArrayList<>(hand);
        testHand.add(tile);
        
        // 简化版胡牌检查（实际需要完整算法）
        return canWinSimple(testHand);
    }
    
    private boolean canWinSimple(List<Integer> hand) {
        if (hand.size() != 14) return false;
        
        // 七对子检查
        if (isSevenPairs(hand)) {
            return true;
        }
        
        // 普通胡牌检查（简化版）
        return isStandardWin(hand);
    }
    
    private boolean isSevenPairs(List<Integer> hand) {
        Map<String, Long> tileCounts = new HashMap<>();
        
        for (int tile : hand) {
            String key = getTileType(tile) + "-" + getTileValue(tile);
            tileCounts.put(key, tileCounts.getOrDefault(key, 0L) + 1);
        }
        
        return tileCounts.values().stream().allMatch(count -> count == 2) && tileCounts.size() == 7;
    }
    
    private boolean isStandardWin(List<Integer> hand) {
        // 简化实现：检查是否包含将牌和顺子/刻子组合
        // 实际需要递归算法检查所有可能的组合
        return hand.size() == 14; // 临时实现
    }
    
    public boolean win(String playerId, int tile, boolean isSelfDraw) {
        if (!canWin(playerId, tile)) {
            return false;
        }
        
        // 计算得分
        int score = calculateScore(playerId, tile, isSelfDraw);
        playerScores.put(playerId, playerScores.get(playerId) + score);
        
        winner = getPlayerSeat(playerId);
        gameEnded = true;
        
        endGame();
        
        return true;
    }
    
    private int calculateScore(String playerId, int tile, boolean isSelfDraw) {
        int score = 1; // 基础分
        
        List<Integer> hand = playerHands.get(playerId);
        List<Integer> testHand = new ArrayList<>(hand);
        testHand.add(tile);
        
        // 七对子加倍
        if (isSevenPairs(testHand)) {
            score += 4;
        }
        
        // 自摸加分
        if (isSelfDraw) {
            score += 1;
        }
        
        return score;
    }
    
    private void endGame() {
        gameEnded = true;
    }
    
    private GamePlayer getPlayerById(String playerId) {
        return players.stream()
            .filter(p -> p.getPlayerId().equals(playerId))
            .findFirst()
            .orElse(null);
    }
    
    private int getPlayerSeat(String playerId) {
        GamePlayer player = getPlayerById(playerId);
        return player != null ? players.indexOf(player) : -1;
    }
    
    private int getTileType(int tile) {
        // 简化实现：根据牌ID范围判断类型
        if (tile <= 36) return 1; // 万
        else if (tile <= 72) return 2; // 条
        else if (tile <= 108) return 3; // 筒
        else if (tile <= 136) return 4; // 字牌
        return 0;
    }
    
    private int getTileValue(int tile) {
        // 简化实现：计算牌面值
        int type = getTileType(tile);
        if (type == 1) return (tile - 1) % 9 + 1; // 万
        else if (type == 2) return (tile - 37) % 9 + 1; // 条
        else if (type == 3) return (tile - 73) % 9 + 1; // 筒
        else if (type == 4) return (tile - 109) % 7 + 1; // 字牌
        return 0;
    }
    
    // Getters and Setters
    public String getRoomId() { return roomId; }
    public List<GamePlayer> getPlayers() { return players; }
    public List<Integer> getDeck() { return deck; }
    public List<Integer> getWall() { return wall; }
    public int getCurrentPlayer() { return currentPlayer; }
    public int getRemainingTiles() { return remainingTiles; }
    public boolean isGameStarted() { return gameStarted; }
    public boolean isGameEnded() { return gameEnded; }
    public Integer getWinner() { return winner; }
    public int getDealer() { return dealer; }
    public int getRound() { return round; }
    public Map<String, List<Integer>> getPlayerHands() { return playerHands; }
    public Map<String, List<Integer>> getPlayerDiscarded() { return playerDiscarded; }
    public Map<String, List<List<Integer>>> getPlayerMelds() { return playerMelds; }
    public Map<String, Integer> getPlayerScores() { return playerScores; }
    public String getLastActionPlayer() { return lastActionPlayer; }
    public String getLastAction() { return lastAction; }
    public Integer getLastActionTile() { return lastActionTile; }
}