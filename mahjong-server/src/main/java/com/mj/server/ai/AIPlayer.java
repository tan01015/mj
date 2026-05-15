package com.mj.server.ai;

import com.mj.server.model.Game;

import java.util.*;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

/**
 * 麻将AI玩家
 * 在单人模式下，AI通过线程自动控制打牌行为
 */
public class AIPlayer implements Runnable {
    
    public enum Difficulty {
        EASY,    // 简单：随机出牌
        MEDIUM,  // 中等：基于牌型价值
        HARD     // 困难：基于策略和概率
    }
    
    private final String gameId;
    private final String playerId;
    private final int seat;
    private final Difficulty difficulty;
    private final Game game;
    
    private volatile boolean running = false;
    private volatile CountDownLatch turnSignal = null;
    
    public AIPlayer(String gameId, String playerId, int seat, Difficulty difficulty, Game game) {
        this.gameId = gameId;
        this.playerId = playerId;
        this.seat = seat;
        this.difficulty = difficulty;
        this.game = game;
    }
    
    @Override
    public void run() {
        running = true;
        System.out.println("[AI] AI玩家启动 - 座位: " + seat + ", 难度: " + difficulty);
        
        try {
            while (running && !game.isGameEnded()) {
                // 等待轮到AI的回合
                waitForTurn();
                
                if (!running || game.isGameEnded()) {
                    break;
                }
                
                // 执行AI决策
                executeTurn();
            }
        } catch (InterruptedException e) {
            System.out.println("[AI] AI线程被中断 - 座位: " + seat);
            Thread.currentThread().interrupt();
        } catch (Exception e) {
            System.err.println("[AI] AI线程异常 - 座位: " + seat + ", 错误: " + e.getMessage());
            e.printStackTrace();
        } finally {
            System.out.println("[AI] AI玩家结束 - 座位: " + seat);
        }
    }
    
    /**
     * 等待轮到自己的回合
     */
    private void waitForTurn() throws InterruptedException {
        while (running && !game.isGameEnded()) {
            int currentPlayer = game.getCurrentPlayer();
            
            // 检查是否轮到当前AI
            if (currentPlayer == seat) {
                System.out.println("[AI] 轮到AI回合 - 座位: " + seat + ", 最后动作: " + game.getLastAction());

                // 等待反应状态：只有该AI在pendingReactions中时才处理
                if (game.isWaitingForReaction()) {
                    if (game.getPendingReactions().contains(playerId)) {
                        System.out.println("[AI] AI需要反应 - 座位: " + seat);
                        handleReaction();
                        return;
                    }
                    // AI是出牌者，不在pendingReactions中，等待他人反应
                    Thread.sleep(100);
                    continue;
                }

                // 如果不是等待反应，说明需要摸牌
                return;
            }
            
            // 检查是否在等待反应，且当前AI需要反应
            if (game.isWaitingForReaction()) {
                if (game.getPendingReactions().contains(playerId)) {
                    System.out.println("[AI] AI需要反应 - 座位: " + seat);
                    handleReaction();
                    return;
                }
            }
            
            // 不是自己的回合，等待
            Thread.sleep(100);
        }
    }
    
    /**
     * 处理反应（碰、吃、杠、胡）
     */
    private void handleReaction() {
        Integer lastTile = game.getLastActionTile();
            if (lastTile == null) {
                System.out.println("[AI] 没有最后出的牌，PASS");
                game.resolveReaction(playerId, "PASS", null);
                return;
            }
            
            // 检查可用动作
            List<String> availableActions = new ArrayList<>();
            
            // 1. 检查胡牌（优先级最高）
            if (game.canWin(playerId, lastTile)) {
                availableActions.add("WIN");
                System.out.println("[AI] AI可以胡牌 - 座位: " + seat);
            }
            
            // 2. 检查杠牌
            if (game.canKong(playerId, lastTile)) {
                availableActions.add("KONG");
                System.out.println("[AI] AI可以杠牌 - 座位: " + seat);
            }
            
            // 3. 检查碰牌
            if (game.canPong(playerId, lastTile)) {
                availableActions.add("PONG");
                System.out.println("[AI] AI可以碰牌 - 座位: " + seat);
            }
            
            // 吃牌已移除

            if (availableActions.isEmpty()) {
                // 没有可用动作，PASS
                System.out.println("[AI] AI无反应 - 座位: " + seat + ", PASS");
                game.resolveReaction(playerId, "PASS", null);
                return;
            }
            
            // 根据难度选择动作
            String chosenAction = selectReactionAction(availableActions, lastTile);
            
            if ("WIN".equals(chosenAction)) {
                System.out.println("[AI] AI选择胡牌 - 座位: " + seat);
                game.resolveReaction(playerId, "WIN", lastTile);
            } else if ("KONG".equals(chosenAction)) {
                System.out.println("[AI] AI选择杠牌 - 座位: " + seat);
                game.resolveReaction(playerId, "KONG", lastTile);
            } else if ("PONG".equals(chosenAction)) {
                System.out.println("[AI] AI选择碰牌 - 座位: " + seat);
                game.resolveReaction(playerId, "PONG", lastTile);
            } else {
                // PASS
                System.out.println("[AI] AI选择PASS - 座位: " + seat);
                game.resolveReaction(playerId, "PASS", null);
            }
    }
    
    /**
     * 选择反应动作（基于难度）
     */
    private String selectReactionAction(List<String> actions, int lastTile) {
        // HUP牌优先级最高，总是选择
        if (actions.contains("WIN")) {
            return "WIN";
        }
        
        switch (difficulty) {
            case EASY:
                // 简单：随机选择
                return actions.get((int)(Math.random() * actions.size()));
                
            case MEDIUM:
                // 中等：优先杠>碰
                if (actions.contains("KONG")) return "KONG";
                if (actions.contains("PONG")) return "PONG";
                return "PASS";
                
            case HARD:
                // 困难：基于策略
                if (actions.contains("KONG")) return "KONG";
                if (actions.contains("PONG")) {
                    // 评估碰牌的价值
                    if (shouldPong(lastTile)) return "PONG";
                }
                return "PASS";
                
            default:
                return "PASS";
        }
    }
    
    /**
     * 执行自己的回合（摸牌和出牌）
     */
    private void executeTurn() {
        try {
            if (game.isGameEnded()) {
                System.out.println("[AI] 游戏已结束，不执行回合 - 座位: " + seat);
                return;
            }

            List<Integer> hand = game.getPlayerHands().get(playerId);
            if (hand == null || hand.isEmpty()) {
                System.out.println("[AI] 手牌为空 - 座位: " + seat + ", 异常状态，退出AI线程");
                // 手牌为空是异常状态（正常情况碰/杠/吃补牌后不会出现），安全退出
                running = false;
                return;
            }

            boolean isDealerFirstTurn = "DEAL".equals(game.getLastAction()) && seat == game.getDealer();
            boolean needDraw = !isDealerFirstTurn && hand.size() == 13; // 手牌13张正常需摸牌；碰/杠后<13直接弃牌

            if (needDraw) {
                Integer drawnTile = game.drawTile(playerId);
                if (drawnTile == null) {
                    System.out.println("[AI] 摸牌失败 - 座位: " + seat);
                    return;
                }
                System.out.println("[AI] AI摸牌 - 座位: " + seat + ", 牌: " + drawnTile + ", 手牌数: " + hand.size());

                // 自摸胡
                if (game.canSelfDrawWin(playerId)) {
                    System.out.println("[AI] AI自摸胡牌！ - 座位: " + seat);
                    boolean winResult = game.win(playerId, drawnTile, true);
                    System.out.println("[AI] 胡牌结果: " + winResult + ", 游戏结束: " + game.isGameEnded());
                    return;
                }

                // 暗杠
                long tileCount = hand.stream().filter(t -> t == drawnTile).count();
                if (tileCount >= 4 && (difficulty == Difficulty.HARD || difficulty == Difficulty.MEDIUM)) {
                    System.out.println("[AI] AI暗杠 - 座位: " + seat);
                    game.kong(playerId, drawnTile);
                    Thread.sleep(800);
                    // 杠后检查岭上开花自摸
                    if (game.isGameEnded()) {
                        System.out.println("[AI] 杠后岭上开花，游戏结束 - 座位: " + seat);
                        return;
                    }
                    // 杠后岭上已补牌，手牌<13，直接弃牌
                    int tileToDiscard = selectTileToDiscard();
                    if (tileToDiscard > 0) {
                        System.out.println("[AI] AI暗杠后出牌 - 座位: " + seat + ", 牌: " + tileToDiscard);
                        game.discardTile(playerId, tileToDiscard);
                    }
                    return;
                }
            } else if (hand.size() < 13) {
                System.out.println("[AI] 碰/杠后直接弃牌 - 座位: " + seat + ", 手牌数: " + hand.size());
            } else {
                System.out.println("[AI] 庄家起手直接出牌 - 座位: " + seat + ", 手牌数: " + hand.size());
            }

            // 选择出牌
            int tileToDiscard = selectTileToDiscard();
            if (tileToDiscard > 0) {
                System.out.println("[AI] AI出牌 - 座位: " + seat + ", 牌: " + tileToDiscard);
                game.discardTile(playerId, tileToDiscard);
            } else {
                System.out.println("[AI] AI无牌可出 - 座位: " + seat);
            }

        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        } catch (Exception e) {
            System.err.println("[AI] 执行回合异常 - 座位: " + seat + ", 错误: " + e.getMessage());
            e.printStackTrace();
        }
    }
    
    /**
     * 选择要出的牌
     */
    private int selectTileToDiscard() {
        List<Integer> hand = game.getPlayerHands().get(playerId);
        if (hand == null || hand.isEmpty()) {
            return 0;
        }
        
        switch (difficulty) {
            case EASY:
                // 简单：随机出牌
                return hand.get((int)(Math.random() * hand.size()));
                
            case MEDIUM:
                // 中等：优先出孤张、字牌、边张
                return mediumSelectTile(hand);
                
            case HARD:
                // 困难：基于牌型分析和概率
                return hardSelectTile(hand);
                
            default:
                return hand.get(0);
        }
    }
    
    /**
     * 中等难度选牌
     */
    private int mediumSelectTile(List<Integer> hand) {
        Map<Integer, Integer> tileCount = new HashMap<>();
        for (int tile : hand) {
            tileCount.put(tile, tileCount.getOrDefault(tile, 0) + 1);
        }
        
        // 优先出字牌
        for (int tile : hand) {
            int type = Game.getTileType(tile);
            if (type == Game.TILE_TYPE_HONOR && tileCount.get(tile) == 1) {
                return tile;
            }
        }
        
        // 其次出孤张（只有一张的牌）
        for (int tile : hand) {
            if (tileCount.get(tile) == 1) {
                int value = Game.getTileValue(tile);
                // 优先出边张（1和9）
                if (value == 1 || value == 9) {
                    return tile;
                }
            }
        }
        
        // 再次出孤张
        for (int tile : hand) {
            if (tileCount.get(tile) == 1) {
                return tile;
            }
        }
        
        // 最后随机出
        return hand.get((int)(Math.random() * hand.size()));
    }
    
    /**
     * 困难难度选牌
     */
    private int hardSelectTile(List<Integer> hand) {
        Map<Integer, Integer> tileCount = new HashMap<>();
        for (int tile : hand) {
            tileCount.put(tile, tileCount.getOrDefault(tile, 0) + 1);
        }
        
        // 计算每张牌的价值分数（越低越应该出）
        Map<Integer, Double> tileScores = new HashMap<>();
        
        for (int tile : hand) {
            double score = calculateTileValue(tile, tileCount, hand);
            tileScores.put(tile, score);
        }
        
        // 找出分数最低的牌
        int worstTile = hand.get(0);
        double minScore = tileScores.get(worstTile);
        
        for (int tile : hand) {
            double score = tileScores.get(tile);
            if (score < minScore) {
                minScore = score;
                worstTile = tile;
            }
        }
        
        return worstTile;
    }
    
    /**
     * 计算牌的价值
     */
    private double calculateTileValue(int tile, Map<Integer, Integer> tileCount, List<Integer> hand) {
        int type = Game.getTileType(tile);
        int value = Game.getTileValue(tile);
        int count = tileCount.getOrDefault(tile, 0);
        
        double score = 10.0; // 基础分数
        
        // 字牌价值较低
        if (type == Game.TILE_TYPE_HONOR) {
            score -= 3.0;
            // 如果是孤张字牌，价值更低
            if (count == 1) {
                score -= 5.0;
            } else if (count == 2) {
                score += 3.0; // 对子有价值
            } else if (count == 3) {
                score += 8.0; // 刻子很有价值
            }
        } else {
            // 数牌
            if (count == 1) {
                // 孤张
                score -= 2.0;
                
                // 边张（1和9）价值更低
                if (value == 1 || value == 9) {
                    score -= 2.0;
                }
                
                // 检查是否有相邻牌
                boolean hasNeighbor = false;
                for (int other : hand) {
                    if (other != tile && Game.getTileType(other) == type) {
                        int otherValue = Game.getTileValue(other);
                        if (Math.abs(otherValue - value) <= 2) {
                            hasNeighbor = true;
                            break;
                        }
                    }
                }
                if (!hasNeighbor) {
                    score -= 3.0; // 完全孤立的牌
                }
            } else if (count == 2) {
                // 对子
                score += 2.0;
            } else if (count == 3) {
                // 刻子
                score += 8.0;
            } else if (count >= 4) {
                // 杠
                score += 10.0;
            }
        }
        
        return score;
    }
    
    /**
     * 判断是否应该碰牌
     */
    private boolean shouldPong(int tile) {
        // 简单策略：有对子就碰
        List<Integer> hand = game.getPlayerHands().get(playerId);
        long count = hand.stream().filter(t -> t == tile).count();
        return count >= 2;
    }
    
    /**
     * 判断是否应该吃牌
     */
    private boolean shouldChow(int tile) {
        // 简单策略：可以吃就吃
        return true;
    }
    
    /**
     * 停止AI
     */
    public void stop() {
        running = false;
        System.out.println("[AI] AI玩家停止 - 座位: " + seat);
    }
    
    public String getPlayerId() {
        return playerId;
    }
    
    public int getSeat() {
        return seat;
    }
    
    public Difficulty getDifficulty() {
        return difficulty;
    }
}
