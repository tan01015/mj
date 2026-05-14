package com.mj.server.model;

import java.util.*;

public class Game {
    // 牌类型常量（与客户端 MahjongRules.ets 保持一致）
    // 万: 1-9, 条: 11-19, 筒: 21-29, 字牌: 31-37
    public static final int TILE_TYPE_CHARACTER = 1; // 万
    public static final int TILE_TYPE_BAMBOO = 2;    // 条
    public static final int TILE_TYPE_DOT = 3;       // 筒
    public static final int TILE_TYPE_HONOR = 4;     // 字牌

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
    private boolean singlePlayer = false;
    private boolean waitingForReaction = false;
    private List<String> pendingReactions = new ArrayList<>(); // 等待反应的玩家列表
    private Map<String, Boolean> reactionResults = new HashMap<>(); // 玩家反应结果
    private boolean selfDrawWinAvailable = false; // 自摸胡可用
    private boolean selfDrawKongAvailable = false; // 暗杠/加杠可用
    private Runnable onHumanTurnCallback = null; // AI回合结束切回人类时的回调

    public Game(String roomId, List<GamePlayer> players) {
        this(roomId, players, false);
    }

    public Game(String roomId, List<GamePlayer> players, boolean singlePlayer) {
        this.roomId = roomId;
        this.players = new ArrayList<>(players);
        this.deck = new ArrayList<>();
        this.wall = new ArrayList<>();
        this.playerHands = new HashMap<>();
        this.playerDiscarded = new HashMap<>();
        this.playerMelds = new HashMap<>();
        this.playerScores = new HashMap<>();
        this.currentPlayer = 0;
        this.remainingTiles = singlePlayer ? 108 : 136;
        this.gameStarted = false;
        this.gameEnded = false;
        this.dealer = 0;
        this.round = 1;
        this.singlePlayer = singlePlayer;

        for (GamePlayer player : players) {
            playerHands.put(player.getPlayerId(), new ArrayList<>());
            playerDiscarded.put(player.getPlayerId(), new ArrayList<>());
            playerMelds.put(player.getPlayerId(), new ArrayList<>());
            playerScores.put(player.getPlayerId(), 0);
        }

        if (singlePlayer) {
            initializeDeck108();
        } else {
            initializeDeck();
        }
    }

    // ==================== 牌编码系统（与客户端 MahjongRules.ets 一致） ====================

    /**
     * 获取牌的类型
     * 1-9: 万(TILE_TYPE_CHARACTER)
     * 11-19: 条(TILE_TYPE_BAMBOO)
     * 21-29: 筒(TILE_TYPE_DOT)
     * 31-37: 字牌(TILE_TYPE_HONOR)
     */
    public static int getTileType(int tile) {
        if (tile >= 1 && tile <= 9) return TILE_TYPE_CHARACTER;
        if (tile >= 11 && tile <= 19) return TILE_TYPE_BAMBOO;
        if (tile >= 21 && tile <= 29) return TILE_TYPE_DOT;
        if (tile >= 31 && tile <= 37) return TILE_TYPE_HONOR;
        return 0;
    }

    /**
     * 获取牌的面值（1-9 或 字牌 1-7: 东南西北中发白）
     */
    public static int getTileValue(int tile) {
        int type = getTileType(tile);
        switch (type) {
            case TILE_TYPE_CHARACTER: return tile;       // 1-9
            case TILE_TYPE_BAMBOO:    return tile - 10;  // 1-9
            case TILE_TYPE_DOT:       return tile - 20;  // 1-9
            case TILE_TYPE_HONOR:     return tile - 30;  // 1-7
            default: return 0;
        }
    }

    // ==================== 牌堆初始化 ====================

    private void initializeDeck() {
        deck.clear();

        // 万牌 1-9, 每种4张
        for (int tile = 1; tile <= 9; tile++) {
            for (int copy = 0; copy < 4; copy++) {
                deck.add(tile);
            }
        }
        // 条牌 11-19, 每种4张
        for (int tile = 11; tile <= 19; tile++) {
            for (int copy = 0; copy < 4; copy++) {
                deck.add(tile);
            }
        }
        // 筒牌 21-29, 每种4张
        for (int tile = 21; tile <= 29; tile++) {
            for (int copy = 0; copy < 4; copy++) {
                deck.add(tile);
            }
        }
        // 字牌 31-37 (东南西北中发白), 每种4张
        for (int tile = 31; tile <= 37; tile++) {
            for (int copy = 0; copy < 4; copy++) {
                deck.add(tile);
            }
        }

        shuffleDeck();
        wall = new ArrayList<>(deck);
        remainingTiles = wall.size();
    }

    private void shuffleDeck() {
        Collections.shuffle(deck);
    }

    private void initializeDeck108() {
        deck.clear();
        // 万牌 1-9, 每种4张
        for (int tile = 1; tile <= 9; tile++) {
            for (int copy = 0; copy < 4; copy++) {
                deck.add(tile);
            }
        }
        // 条牌 11-19, 每种4张
        for (int tile = 11; tile <= 19; tile++) {
            for (int copy = 0; copy < 4; copy++) {
                deck.add(tile);
            }
        }
        // 筒牌 21-29, 每种4张
        for (int tile = 21; tile <= 29; tile++) {
            for (int copy = 0; copy < 4; copy++) {
                deck.add(tile);
            }
        }
        shuffleDeck();
        wall = new ArrayList<>(deck);
        remainingTiles = wall.size();
    }

    // ==================== 游戏流程 ====================

    public void startGame() {
        if (gameStarted) return;
        gameStarted = true;
        dealInitialHands();
    }

    private void dealInitialHands() {
        for (int i = 0; i < players.size(); i++) {
            GamePlayer player = players.get(i);
            List<Integer> hand = playerHands.get(player.getPlayerId());

            // 庄家（dealer）起手14张，其他玩家13张
            int handSize = (i == dealer) ? 14 : 13;

            for (int j = 0; j < handSize; j++) {
                if (!wall.isEmpty()) {
                    hand.add(wall.remove(0));
                }
            }
            Collections.sort(hand);
        }
        remainingTiles = wall.size();
        
        System.out.println("[发牌完成] 庄家座位: " + dealer + ", 庄家手牌14张，其他玩家13张");
        System.out.println("[发牌完成] 剩余牌数: " + remainingTiles);
        
        // 庄家已经14张，不需要摸牌，直接出牌
        // 设置lastAction为DEAL，表示刚发完牌
        lastAction = "DEAL";
        lastActionPlayer = players.get(dealer).getPlayerId();
    }

    public synchronized Integer drawTile(String playerId) {
        GamePlayer player = getPlayerById(playerId);
        if (player == null || getPlayerSeat(playerId) != currentPlayer || !gameStarted || gameEnded) {
            System.out.println("[摸牌失败] 玩家ID: " + playerId + ", 原因: 玩家不存在或不是当前玩家或游戏未开始/已结束");
            return null;
        }
    
        if (wall.isEmpty()) {
            System.out.println("[摸牌失败] 牌墙已空，流局");
            winner = -1; // -1 表示流局（荒牌）
            endGame();
            return null;
        }
    
        int tile = wall.remove(0);
        playerHands.get(playerId).add(tile);
        remainingTiles = wall.size();
    
        lastActionPlayer = playerId;
        lastAction = "DRAW";
        lastActionTile = tile;
    
        System.out.println("[摸牌成功] 玩家ID: " + playerId + ", 座位: " + getPlayerSeat(playerId) + ", 摸到牌: " + tile + ", 剩余牌: " + remainingTiles);
        System.out.println("[手牌] 玩家ID: " + playerId + ", 手牌: " + playerHands.get(playerId));
            
        // 摸牌后检查是否可以自摸胡牌或杠牌
        checkSelfDrawActions(playerId, tile);
    
        return tile;
    }
    
    /**
     * 摸牌后检查自摸胡牌和杠牌的可能性
     */
    private void checkSelfDrawActions(String playerId, int drawnTile) {
        System.out.println("[摸牌检查] 玩家ID: " + playerId + ", 检查自摸胡牌和杠牌");

        selfDrawWinAvailable = false;
        selfDrawKongAvailable = false;

        // 检查是否可以自摸胡牌（手牌已14张，tile已在手中）
        if (canSelfDrawWin(playerId)) {
            selfDrawWinAvailable = true;
            System.out.println("[摸牌检查] 玩家ID: " + playerId + " 可以自摸胡牌！");
        }

        // 检查是否可以暗杠（手中有4张相同的牌）
        List<Integer> hand = playerHands.get(playerId);
        long count = hand.stream().filter(t -> t == drawnTile).count();
        if (count >= 4) {
            selfDrawKongAvailable = true;
            System.out.println("[摸牌检查] 玩家ID: " + playerId + " 可以暗杠！");
        }

        // 检查是否可以加杠（之前碰过，现在摸到第4张）
        List<List<Integer>> melds = playerMelds.get(playerId);
        boolean hasPong = melds.stream()
            .anyMatch(m -> m.size() == 3 && m.get(0).equals(drawnTile));
        if (hasPong && count >= 1) {
            selfDrawKongAvailable = true;
            System.out.println("[摸牌检查] 玩家ID: " + playerId + " 可以加杠！");
        }
    }

    public synchronized boolean discardTile(String playerId, int tile) {
        GamePlayer player = getPlayerById(playerId);
        if (player == null || getPlayerSeat(playerId) != currentPlayer || !gameStarted || gameEnded) {
            System.out.println("[出牌失败] 玩家ID: " + playerId + ", 原因: 玩家不存在或不是当前玩家或游戏未开始/已结束");
            return false;
        }

        List<Integer> hand = playerHands.get(playerId);
        if (!hand.contains(tile)) {
            System.out.println("[出牌失败] 玩家ID: " + playerId + ", 原因: 手牌中没有这张牌: " + tile);
            return false;
        }
        
        // 检查手牌数量：防止未摸牌就出牌（手牌13张且无副露时需先摸牌）
        // 碰/吃后11张可出牌，杠后10-11张可出牌，庄家首轮14张可出牌
        if (hand.size() == 13 && playerMelds.get(playerId).isEmpty() && !"DEAL".equals(lastAction)) {
            System.out.println("[出牌失败] 玩家ID: " + playerId + ", 原因: 需要先摸牌才能出牌, 手牌: " + hand.size());
            return false;
        }

        hand.remove(Integer.valueOf(tile));
        playerDiscarded.get(playerId).add(tile);

        lastActionPlayer = playerId;
        lastAction = "DISCARD";
        lastActionTile = tile;

        System.out.println("[出牌成功] 玩家ID: " + playerId + ", 座位: " + getPlayerSeat(playerId) + ", 出牌: " + tile);
        System.out.println("[手牌] 玩家ID: " + playerId + ", 出牌后手牌: " + hand);
        System.out.println("[弃牌] 玩家ID: " + playerId + ", 弃牌堆: " + playerDiscarded.get(playerId));

        // 检查手牌是否为空（所有牌都已组成面子），为空则胜利
        if (hand.isEmpty()) {
            System.out.println("[手牌为空] 玩家ID: " + playerId + " 手牌已空，判定胜利！");
            win(playerId, tile, false);
            return true;
        }

        // 出牌后，该玩家本轮结束，检查其他玩家的反应
        initReactionSystem(playerId, tile);
        
        // 注意：这里不立即推进到下一位玩家，等所有玩家反应完成后再推进
        return true;
    }
    
    /**
     * 初始化反应系统：检查其他3位玩家是否有胡、杠、碰、吃的可能
     * 符合真实麻将规则：
     * 1. 按逆时针顺序检查（下家、对家、上家）
     * 2. 胡牌优先级最高，任何人胡牌则其他人不能动作
     * 3. 杠/碰优先级高于吃
     * 4. 只有下家可以吃牌
     * 避免死锁：按座位顺序依次检查，不互相等待
     */
    private void initReactionSystem(String discarderId, int discardedTile) {
        waitingForReaction = true;
        pendingReactions.clear();
        reactionResults.clear();
        
        int discarderSeat = getPlayerSeat(discarderId);
        int nextSeat = (discarderSeat + 1) % players.size(); // 下家
        
        System.out.println("[反应系统] 开始检查反应，出牌玩家座位: " + discarderSeat + ", 出牌: " + discardedTile + ", 下家座位: " + nextSeat);
        
        // 按逆时针顺序检查其他3位玩家（下家、对家、上家）
        for (int i = 1; i <= 3; i++) {
            int checkSeat = (discarderSeat + i) % players.size();
            GamePlayer player = players.get(checkSeat);
            String playerId = player.getPlayerId();
            
            List<String> availableActions = new ArrayList<>();
            
            // 真实麻将优先级：胡 > 杠 > 碰（已移除吃牌）
            // 1. 检查胡牌（任何位置都可以胡）
            if (canWin(playerId, discardedTile)) {
                availableActions.add("WIN");
                System.out.println("[反应检查] 玩家ID: " + playerId + ", 座位: " + checkSeat + " 可以胡牌（点炮）");
            }

            // 2. 检查杠牌（任何位置都可以明杠）
            if (canKong(playerId, discardedTile)) {
                availableActions.add("KONG");
                System.out.println("[反应检查] 玩家ID: " + playerId + ", 座位: " + checkSeat + " 可以明杠");
            }

            // 3. 检查碰牌（任何位置都可以碰）
            if (canPong(playerId, discardedTile)) {
                availableActions.add("PONG");
                System.out.println("[反应检查] 玩家ID: " + playerId + ", 座位: " + checkSeat + " 可以碰牌");
            }
            
            // 只有有可用动作的玩家才需要反应
            if (!availableActions.isEmpty()) {
                pendingReactions.add(playerId);
                System.out.println("[反应系统] 玩家ID: " + playerId + " (座位" + checkSeat + ") 需要反应，可用动作: " + availableActions);
            } else {
                // 没有可用动作的玩家自动PASS
                reactionResults.put(playerId, true);
                System.out.println("[反应系统] 玩家ID: " + playerId + " (座位" + checkSeat + ") 无可用动作，自动PASS");
            }
        }
        
        // 如果没有玩家需要反应，直接推进到下一位（出牌者的下家）
        if (pendingReactions.isEmpty()) {
            System.out.println("[反应系统] 没有玩家需要反应，推进到出牌者的下家");
            waitingForReaction = false;
            currentPlayer = nextSeat;
            System.out.println("[反应系统] 下一位玩家座位: " + currentPlayer);
            // 单机模式：如果轮到人类玩家，触发回调推送状态
            if (singlePlayer && currentPlayer == 0 && onHumanTurnCallback != null) {
                onHumanTurnCallback.run();
            }
        } else {
            System.out.println("[反应系统] 等待 " + pendingReactions.size() + " 位玩家反应: " + pendingReactions);
            // 单机模式：如果人类玩家需要反应，立即推送通知
            if (singlePlayer && onHumanTurnCallback != null) {
                for (String pendingId : pendingReactions) {
                    if (getPlayerSeat(pendingId) == 0) {
                        System.out.println("[反应系统] 人类玩家需要反应，推送通知");
                        onHumanTurnCallback.run();
                        break;
                    }
                }
            }
        }
    }

    // ==================== 碰牌 (Pong) ====================

    public boolean canPong(String playerId, int tile) {
        List<Integer> hand = playerHands.get(playerId);
        return hand.stream().filter(t -> t == tile).count() >= 2;
    }

    public synchronized boolean pong(String playerId, int tile) {
        if (!"DISCARD".equals(lastAction) || !canPong(playerId, tile)) {
            System.out.println("[碰牌失败] 玩家ID: " + playerId + ", 原因: 不是出牌动作或不能碰牌");
            return false;
        }

        List<Integer> hand = playerHands.get(playerId);
        
        // 检查是否有足够的牌
        long count = hand.stream().filter(t -> t == tile).count();
        if (count < 2) {
            System.out.println("[碰牌失败] 玩家ID: " + playerId + ", 原因: 手牌中不足两张: " + tile);
            return false;
        }

        // 从手牌中移除两张相同的牌
        hand.remove(Integer.valueOf(tile));
        hand.remove(Integer.valueOf(tile));

        // 创建碰牌组合
        List<Integer> pongMeld = Arrays.asList(tile, tile, tile);
        playerMelds.get(playerId).add(pongMeld);

        // 从弃牌堆移除被碰的牌
        playerDiscarded.get(lastActionPlayer).remove(Integer.valueOf(tile));

        lastActionPlayer = playerId;
        lastAction = "PONG";
        lastActionTile = tile;
        currentPlayer = getPlayerSeat(playerId);
        
        // 碰牌后，清空等待反应状态（因为有人执行了动作）
        waitingForReaction = false;
        pendingReactions.clear();

        System.out.println("[碰牌成功] 玩家ID: " + playerId + ", 座位: " + currentPlayer + ", 碰牌: " + tile);
        System.out.println("[手牌] 玩家ID: " + playerId + ", 碰牌后手牌: " + hand);
        System.out.println("[牌组] 玩家ID: " + playerId + ", 牌组: " + playerMelds.get(playerId));

        return true;
    }

    // ==================== 吃牌 (Chow) ====================

    public boolean canChow(String playerId, int tile) {
        // 只有下家可以吃牌
        int discarderSeat = getPlayerSeat(lastActionPlayer);
        int playerSeat = getPlayerSeat(playerId);
        int nextSeat = (discarderSeat + 1) % players.size();
        
        // 检查是否是下家
        if (playerSeat != nextSeat) {
            return false;
        }

        // 字牌不能组成顺子
        int tileType = getTileType(tile);
        if (tileType == TILE_TYPE_HONOR || tileType == 0) {
            return false;
        }

        List<Integer> hand = playerHands.get(playerId);

        // 检查三种可能的顺子组合
        int[][] combos = {
            {tile - 2, tile - 1, tile},
            {tile - 1, tile, tile + 1},
            {tile, tile + 1, tile + 2}
        };

        for (int[] combo : combos) {
            if (isValidSequence(combo) && hand.contains(combo[0]) && hand.contains(combo[1])) {
                return true;
            }
        }

        return false;
    }

    public synchronized boolean chow(String playerId, int discardedTile) {
        if (!"DISCARD".equals(lastAction) || !canChow(playerId, discardedTile)) {
            System.out.println("[吃牌失败] 玩家ID: " + playerId + ", 原因: 不是出牌动作或不能吃牌");
            return false;
        }

        List<Integer> hand = playerHands.get(playerId);

        // 找到有效的顺子组合
        int[][] combos = {
            {discardedTile - 2, discardedTile - 1, discardedTile},
            {discardedTile - 1, discardedTile, discardedTile + 1},
            {discardedTile, discardedTile + 1, discardedTile + 2}
        };

        boolean found = false;
        for (int[] combo : combos) {
            if (isValidSequence(combo) && hand.contains(combo[0]) && hand.contains(combo[1])) {
                // 从手牌移除另外两张牌
                hand.remove(Integer.valueOf(combo[0]));
                hand.remove(Integer.valueOf(combo[1]));

                // 创建顺子组合（排序）
                List<Integer> chowMeld = new ArrayList<>();
                for (int t : combo) chowMeld.add(t);
                Collections.sort(chowMeld);
                playerMelds.get(playerId).add(chowMeld);

                // 从弃牌堆移除被吃的牌
                playerDiscarded.get(lastActionPlayer).remove(Integer.valueOf(discardedTile));

                found = true;
                break;
            }
        }
        
        if (!found) {
            System.out.println("[吃牌失败] 玩家ID: " + playerId + ", 原因: 找不到合适的顺子组合");
            return false;
        }

        lastActionPlayer = playerId;
        lastAction = "CHOW";
        lastActionTile = discardedTile;
        currentPlayer = getPlayerSeat(playerId);
        
        // 吃牌后，清空等待反应状态（因为有人执行了动作）
        waitingForReaction = false;
        pendingReactions.clear();

        // 吃牌后补牌：从牌墙摸一张
        if (!wall.isEmpty()) {
            int replacementTile = wall.remove(0);
            hand.add(replacementTile);
            remainingTiles = wall.size();
            System.out.println("[吃牌补牌] 玩家ID: " + playerId + ", 补牌: " + replacementTile + ", 剩余牌: " + remainingTiles);
        } else {
            System.out.println("[吃牌补牌] 牌墙已空，无法补牌");
        }

        System.out.println("[吃牌成功] 玩家ID: " + playerId + ", 座位: " + currentPlayer + ", 吃牌: " + discardedTile);
        System.out.println("[手牌] 玩家ID: " + playerId + ", 吃牌后手牌: " + hand);
        System.out.println("[牌组] 玩家ID: " + playerId + ", 牌组: " + playerMelds.get(playerId));

        return true;
    }

    private boolean isValidSequence(int[] tiles) {
        if (tiles.length != 3) return false;
        for (int t : tiles) {
            if (t < 1 || t > 29) return false;
        }
        int type = getTileType(tiles[0]);
        return type == getTileType(tiles[1]) && type == getTileType(tiles[2])
            && tiles[1] == tiles[0] + 1 && tiles[2] == tiles[0] + 2;
    }

    // ==================== 杠牌 (Kong) ====================

    public boolean canKong(String playerId, int tile) {
        List<Integer> hand = playerHands.get(playerId);
        return hand.stream().filter(t -> t == tile).count() >= 3;
    }

    /**
     * 杠牌：明杠（别人打出）或加杠/暗杠（自己摸到）
     */
    public synchronized boolean kong(String playerId, int tile) {
        List<Integer> hand = playerHands.get(playerId);
        long handCount = hand.stream().filter(t -> t == tile).count();

        if ("DISCARD".equals(lastAction) && lastActionTile != null && lastActionTile == tile) {
            // 明杠：别人打出，手中有3张
            if (handCount < 3) {
                System.out.println("[杠牌失败] 玩家ID: " + playerId + ", 原因: 明杠需要手中有3张");
                return false;
            }
            for (int i = 0; i < 3; i++) {
                hand.remove(Integer.valueOf(tile));
            }
            playerDiscarded.get(lastActionPlayer).remove(Integer.valueOf(tile));
        } else {
            // 暗杠：手中有4张
            if (handCount >= 4) {
                for (int i = 0; i < 4; i++) {
                    hand.remove(Integer.valueOf(tile));
                }
            } else {
                // 加杠：检查是否已经碰过这张牌
                List<List<Integer>> melds = playerMelds.get(playerId);
                boolean hasPong = melds.stream()
                    .anyMatch(m -> m.size() == 3 && m.get(0).equals(tile));
                
                if (!hasPong || handCount < 1) {
                    System.out.println("[杠牌失败] 玩家ID: " + playerId + ", 原因: 加杠需要先碰过且手中有1张");
                    return false;
                }
                
                // 移除手中的那张牌
                hand.remove(Integer.valueOf(tile));
                
                // 将碰牌组合升级为杠牌组合
                for (List<Integer> meld : melds) {
                    if (meld.size() == 3 && meld.get(0).equals(tile)) {
                        meld.add(tile); // 添加第四张牌
                        break;
                    }
                }
            }
        }

        // 如果是明杠或暗杠（不是加杠），创建新的杠牌组合
        if ("DISCARD".equals(lastAction) || handCount >= 4) {
            List<Integer> kongMeld = Arrays.asList(tile, tile, tile, tile);
            playerMelds.get(playerId).add(kongMeld);
        }

        lastActionPlayer = playerId;
        lastAction = "KONG";
        lastActionTile = tile;
        currentPlayer = getPlayerSeat(playerId);
        
        // 杠牌后，清空等待反应状态（因为有人执行了动作）
        waitingForReaction = false;
        pendingReactions.clear();

        System.out.println("[杠牌成功] 玩家ID: " + playerId + ", 座位: " + currentPlayer + ", 杠牌: " + tile);

        // 杠后补牌（岭上开花）：从牌墙末尾摸一张牌
        if (!wall.isEmpty()) {
            int replacementTile = wall.remove(wall.size() - 1); // 从杠尾摸牌
            playerHands.get(playerId).add(replacementTile);
            remainingTiles = wall.size();
            lastAction = "DRAW";
            lastActionTile = replacementTile;

            System.out.println("[杠后补牌] 玩家ID: " + playerId + ", 补牌: " + replacementTile + ", 剩余牌: " + remainingTiles);

            // 检查岭上开花（自摸胡）
            if (canWin(playerId, replacementTile)) {
                System.out.println("[杠后补牌] 岭上开花！玩家ID: " + playerId + " 自摸胡牌！");
                winner = getPlayerSeat(playerId);
                lastAction = "WIN";
                lastActionTile = replacementTile;
            }
        } else {
            System.out.println("[杠后补牌] 牌墙已空，无法补牌");
            remainingTiles = wall.size();
        }

        System.out.println("[手牌] 玩家ID: " + playerId + ", 杠后手牌: " + playerHands.get(playerId));
        System.out.println("[牌组] 玩家ID: " + playerId + ", 牌组: " + playerMelds.get(playerId));

        return true;
    }

    // ==================== 胡牌判定 ====================

    /**
     * 点炮胡检查：手牌 + 别人打出的牌 = 14张
     */
    public boolean canWin(String playerId, int tile) {
        List<Integer> hand = playerHands.get(playerId);
        List<Integer> testHand = new ArrayList<>(hand);
        testHand.add(tile);
        boolean result = canWinSimple(testHand);
        System.out.println("[胡牌检查-点炮] 玩家ID: " + playerId + ", 手牌+牌: " + testHand.size() + "张, 结果: " + (result ? "可以胡" : "不能胡"));
        return result;
    }

    /**
     * 自摸胡检查：当前手牌直接判断（tile已在手中），含已碰/杠牌组
     */
    public boolean canSelfDrawWin(String playerId) {
        List<Integer> hand = playerHands.get(playerId);
        List<List<Integer>> melds = playerMelds.get(playerId);
        // 计算总手牌等效数：手牌 + 已碰/杠牌组张数
        int meldTileCount = 0;
        if (melds != null) {
            for (List<Integer> meld : melds) {
                meldTileCount += meld.size();
            }
        }
        int totalEffective = hand.size() + meldTileCount;
        if (totalEffective != 14) return false;

        // 构建完整14张手牌用于判断（手牌 + 已碰/杠的牌展开）
        List<Integer> combined = new ArrayList<>(hand);
        if (melds != null) {
            for (List<Integer> meld : melds) {
                combined.addAll(meld);
            }
        }
        // 对14张牌进行标准判断
        return isSevenPairs(combined) || isStandardWin(combined);
    }

    private boolean canWinSimple(List<Integer> hand) {
        if (hand.size() != 14) return false;

        if (isSevenPairs(hand)) {
            return true;
        }

        return isStandardWin(hand);
    }

    private boolean isSevenPairs(List<Integer> hand) {
        if (hand.size() != 14) return false;

        Map<Integer, Integer> tileCounts = new HashMap<>();
        for (int tile : hand) {
            tileCounts.put(tile, tileCounts.getOrDefault(tile, 0) + 1);
        }

        for (int count : tileCounts.values()) {
            if (count != 2) return false;
        }
        return tileCounts.size() == 7;
    }

    private boolean isStandardWin(List<Integer> hand) {
        if (hand.size() % 3 != 2) return false;

        // 统计每种牌的数量
        Map<Integer, Integer> tileCount = new HashMap<>();
        for (int tile : hand) {
            tileCount.put(tile, tileCount.getOrDefault(tile, 0) + 1);
        }

        // 尝试每种牌作为将牌（对子）
        for (Map.Entry<Integer, Integer> entry : tileCount.entrySet()) {
            if (entry.getValue() >= 2) {
                List<Integer> remaining = new ArrayList<>(hand);
                removePair(remaining, entry.getKey());
                if (isAllMelds(remaining)) {
                    return true;
                }
            }
        }
        return false;
    }

    private void removePair(List<Integer> hand, int tile) {
        boolean removed1 = hand.remove(Integer.valueOf(tile));
        boolean removed2 = hand.remove(Integer.valueOf(tile));
        if (!removed1 || !removed2) {
            throw new IllegalStateException("无法移除对子，牌数量不足");
        }
    }

    private boolean isAllMelds(List<Integer> hand) {
        if (hand.isEmpty()) return true;

        List<Integer> sorted = new ArrayList<>(hand);
        Collections.sort(sorted);

        int first = sorted.get(0);

        // 尝试作为刻子（三张相同）
        if (sorted.size() >= 3 &&
            sorted.get(0).equals(sorted.get(1)) &&
            sorted.get(1).equals(sorted.get(2))) {

            List<Integer> remaining = new ArrayList<>(sorted.subList(3, sorted.size()));
            if (isAllMelds(remaining)) {
                return true;
            }
        }

        // 尝试作为顺子（三张连续同花色）
        int second = first + 1;
        int third = first + 2;
        
        // 检查这三张牌是否都是同一类型且有效
        if (isValidSequence(new int[]{first, second, third})) {
            // 统计每种牌的数量
            Map<Integer, Integer> countMap = new HashMap<>();
            for (int tile : sorted) {
                countMap.put(tile, countMap.getOrDefault(tile, 0) + 1);
            }
            
            // 检查是否有足够的牌组成顺子
            if (countMap.getOrDefault(first, 0) > 0 && 
                countMap.getOrDefault(second, 0) > 0 && 
                countMap.getOrDefault(third, 0) > 0) {
                
                List<Integer> remaining = new ArrayList<>(sorted);
                remaining.remove(Integer.valueOf(first));
                remaining.remove(Integer.valueOf(second));
                remaining.remove(Integer.valueOf(third));
                if (isAllMelds(remaining)) {
                    return true;
                }
            }
        }

        return false;
    }

    // ==================== 胡牌 ====================

    public synchronized boolean win(String playerId, int tile, boolean isSelfDraw) {
        // 自摸和点炮分开检查（自摸时tile已在手中，点炮时tile不在手中）
        boolean canWin = isSelfDraw ? canSelfDrawWin(playerId) : canWin(playerId, tile);
        if (!canWin) {
            System.out.println("[胡牌失败] 玩家ID: " + playerId + ", 原因: 不满足胡牌条件, 自摸: " + isSelfDraw);
            return false;
        }

        int score = calculateScore(playerId, tile, isSelfDraw);
        playerScores.put(playerId, playerScores.get(playerId) + score);

        winner = getPlayerSeat(playerId);
        gameEnded = true;

        // 清除反应状态，确保回调时状态干净
        waitingForReaction = false;
        pendingReactions.clear();

        endGame();
        
        System.out.println("[胡牌成功] 玩家ID: " + playerId + ", 座位: " + winner + ", 胡牌: " + tile + ", 自摸: " + isSelfDraw + ", 得分: " + score);
        System.out.println("[最终手牌] 玩家ID: " + playerId + ", 手牌+胡牌: " + playerHands.get(playerId) + " + " + tile);
        
        return true;
    }

    private int calculateScore(String playerId, int tile, boolean isSelfDraw) {
        List<Integer> hand = playerHands.get(playerId);
        List<Integer> testHand = new ArrayList<>(hand);
        testHand.add(tile);

        int score = 1; // 基础分

        if (isSevenPairs(testHand)) {
            score += 4; // 七对子
        }

        if (isSelfDraw) {
            score += 1; // 自摸加分
        }

        return score;
    }

    private void endGame() {
        gameEnded = true;
        // 单机模式：游戏结束时通知客户端显示结果
        if (singlePlayer && onHumanTurnCallback != null) {
            onHumanTurnCallback.run();
        }
    }

    // ==================== 单人模式反应系统 ====================

    /**
     * 获取可用的反应动作（供客户端查询）
     */
    public Map<Integer, List<String>> getAvailableReactions(int discardedTile) {
        Map<Integer, List<String>> reactions = new LinkedHashMap<>();
        for (GamePlayer player : players) {
            int seat = player.getSeat();
            if (seat == getPlayerSeat(lastActionPlayer)) continue;
            List<String> actions = new ArrayList<>();
            String pid = player.getPlayerId();
            if (canWin(pid, discardedTile)) actions.add("WIN");
            if (canKong(pid, discardedTile)) actions.add("KONG");
            if (canPong(pid, discardedTile)) actions.add("PONG");
            if (!actions.isEmpty()) {
                reactions.put(seat, actions);
            }
        }
        return reactions;
    }

    /**
     * 处理玩家反应
     * 符合真实麻将规则：
     * 1. 胡牌优先级最高，有人胡牌则游戏结束
     * 2. 杠/碰/吃后，执行动作的玩家成为当前玩家，需要摸牌
     * 3. 一旦有人执行非PASS动作，其他玩家的反应机会取消
     * 避免死锁：每个玩家的反应独立处理，不等待其他玩家
     */
    public synchronized boolean resolveReaction(String playerId, String action, Integer tile) {
        if (!waitingForReaction) {
            System.out.println("[反应失败] 玩家ID: " + playerId + ", 原因: 不在等待反应状态");
            return false;
        }
        
        // 检查该玩家是否在待反应列表中
        if (!pendingReactions.contains(playerId)) {
            System.out.println("[反应失败] 玩家ID: " + playerId + ", 原因: 该玩家不需要反应");
            return false;
        }

        System.out.println("[反应处理] 玩家ID: " + playerId + ", 动作: " + action + ", 牌: " + tile);

        if ("PASS".equals(action)) {
            // 玩家选择PASS
            pendingReactions.remove(playerId);
            reactionResults.put(playerId, true);
            System.out.println("[反应处理] 玩家ID: " + playerId + " 选择PASS");
            
            // 检查是否所有玩家都已反应
            checkAllReactionsCompleted();
            return true;
        }

        boolean success = false;
        switch (action) {
            case "WIN":
                // 胡牌：点炮胡（不是自摸）
                success = win(playerId, tile, false);
                if (success) {
                    // 有人胡牌，游戏结束，清空待反应列表
                    pendingReactions.clear();
                    waitingForReaction = false;
                    System.out.println("[反应处理] 玩家ID: " + playerId + " 点炮胡牌，游戏结束");
                }
                break;
            case "KONG":
                // 明杠：别人打出的牌
                success = kong(playerId, tile);
                if (success) {
                    // 有人杠牌，清空待反应列表，杠牌玩家成为当前玩家，需要摸牌
                    pendingReactions.clear();
                    waitingForReaction = false;
                    System.out.println("[反应处理] 玩家ID: " + playerId + " 明杠，成为当前玩家，需要摸牌");
                }
                break;
            case "PONG":
                // 碰牌
                success = pong(playerId, tile);
                if (success) {
                    // 有人碰牌，清空待反应列表，碰牌玩家成为当前玩家，需要摸牌
                    pendingReactions.clear();
                    waitingForReaction = false;
                    System.out.println("[反应处理] 玩家ID: " + playerId + " 碰牌，成为当前玩家，需要摸牌");
                }
                break;
            // CHOW已移除，单机模式不支持吃牌
            default:
                System.out.println("[反应失败] 玩家ID: " + playerId + ", 原因: 未知动作 " + action);
                return false;
        }
        
        if (!success) {
            System.out.println("[反应失败] 玩家ID: " + playerId + ", 原因: 动作执行失败");
            return false;
        }
        
        // 如果执行了非PASS动作，该玩家反应完成
        pendingReactions.remove(playerId);
        reactionResults.put(playerId, true);
        
        // 检查是否所有玩家都已反应（理论上不会到这里，因为上面已经清空了）
        if (pendingReactions.isEmpty()) {
            checkAllReactionsCompleted();
        }
        
        return success;
    }
    
    /**
     * 检查所有玩家是否都已完成反应
     * 如果都完成了，推进到下一位玩家（出牌者的下家）
     */
    private void checkAllReactionsCompleted() {
        if (pendingReactions.isEmpty()) {
            System.out.println("[反应系统] 所有玩家已完成反应，推进回合");
            waitingForReaction = false;

            // 只有全部PASS时才推进currentPlayer（执行了动作的方法已自行设置currentPlayer）
            boolean actionTaken = "PONG".equals(lastAction)
                || "KONG".equals(lastAction)
                || "WIN".equals(lastAction)
                || "CHOW".equals(lastAction);

            if (!actionTaken) {
                int discarderSeat = getPlayerSeat(lastActionPlayer);
                currentPlayer = (discarderSeat + 1) % players.size();
            }

            System.out.println("[反应系统] 出牌者座位: " + getPlayerSeat(lastActionPlayer) +
                ", 动作已执行: " + actionTaken + ", 下一位玩家: " + currentPlayer);
            // 单机模式：如果轮到人类玩家，触发回调推送状态
            if (singlePlayer && currentPlayer == 0 && onHumanTurnCallback != null) {
                onHumanTurnCallback.run();
            }
        } else {
            System.out.println("[反应系统] 还有 " + pendingReactions.size() + " 位玩家未反应: " + pendingReactions);
        }
    }

    public Map<Integer, List<Integer>> getAllHands() {
        Map<Integer, List<Integer>> result = new HashMap<>();
        for (GamePlayer player : players) {
            List<Integer> hand = playerHands.get(player.getPlayerId());
            if (hand != null) {
                result.put(player.getSeat(), new ArrayList<>(hand));
            }
        }
        return result;
    }

    public Map<Integer, List<List<Integer>>> getAllMelds() {
        Map<Integer, List<List<Integer>>> result = new HashMap<>();
        for (GamePlayer player : players) {
            List<List<Integer>> melds = playerMelds.get(player.getPlayerId());
            if (melds != null) {
                result.put(player.getSeat(), new ArrayList<>(melds));
            }
        }
        return result;
    }

    public Map<Integer, List<Integer>> getAllDiscarded() {
        Map<Integer, List<Integer>> result = new HashMap<>();
        for (GamePlayer player : players) {
            List<Integer> discarded = playerDiscarded.get(player.getPlayerId());
            if (discarded != null) {
                result.put(player.getSeat(), new ArrayList<>(discarded));
            }
        }
        return result;
    }

    // ==================== Getters ====================

    public boolean isSinglePlayer() { return singlePlayer; }
    public boolean isWaitingForReaction() { return waitingForReaction; }
    public boolean isSelfDrawWinAvailable() { return selfDrawWinAvailable; }
    public boolean isSelfDrawKongAvailable() { return selfDrawKongAvailable; }
    public void setOnHumanTurnCallback(Runnable callback) { this.onHumanTurnCallback = callback; }
    
    /**
     * 获取待反应的玩家列表
     */
    public List<String> getPendingReactions() {
        return new ArrayList<>(pendingReactions);
    }
    
    /**
     * 获取当前游戏状态摘要（用于调试和客户端显示）
     */
    public String getStateSummary() {
        StringBuilder sb = new StringBuilder();
        sb.append("\n========== 游戏状态 ==========");
        sb.append("\n房间ID: ").append(roomId);
        sb.append("\n游戏开始: ").append(gameStarted);
        sb.append("\n游戏结束: ").append(gameEnded);
        sb.append("\n当前玩家座位: ").append(currentPlayer);
        sb.append("\n庄家座位: ").append(dealer);
        sb.append("\n剩余牌数: ").append(remainingTiles);
        sb.append("\n最后动作: ").append(lastAction);
        sb.append("\n最后动作玩家: ").append(lastActionPlayer);
        sb.append("\n最后动作牌: ").append(lastActionTile);
        sb.append("\n等待反应: ").append(waitingForReaction);
        if (waitingForReaction) {
            sb.append("\n待反应玩家: ").append(pendingReactions);
        }
        sb.append("\n==============================");
        return sb.toString();
    }

    // ==================== 辅助方法 ====================

    private GamePlayer getPlayerById(String playerId) {
        return players.stream()
            .filter(p -> p.getPlayerId().equals(playerId))
            .findFirst()
            .orElse(null);
    }

    public int getPlayerSeat(String playerId) {
        GamePlayer player = getPlayerById(playerId);
        return player != null ? player.getSeat() : -1;
    }

    // ==================== Getters ====================

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

    /** 返回按seat索引的手牌（适配客户端） */
    public Map<Integer, List<Integer>> getPlayerHandsBySeat() {
        Map<Integer, List<Integer>> result = new HashMap<>();
        for (GamePlayer player : players) {
            List<Integer> hand = playerHands.get(player.getPlayerId());
            if (hand != null) {
                result.put(player.getSeat(), hand);
            }
        }
        return result;
    }
    public Map<String, List<Integer>> getPlayerDiscarded() { return playerDiscarded; }
    public Map<String, List<List<Integer>>> getPlayerMelds() { return playerMelds; }
    public Map<String, Integer> getPlayerScores() { return playerScores; }
    public String getLastActionPlayer() { return lastActionPlayer; }
    public String getLastAction() { return lastAction; }
    public Integer getLastActionTile() { return lastActionTile; }
}
