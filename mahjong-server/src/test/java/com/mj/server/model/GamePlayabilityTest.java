package com.mj.server.model;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

import java.util.*;

/**
 * 麻将游戏可玩性测试
 * 模拟完整的游戏流程，确保游戏可以正常进行
 */
public class GamePlayabilityTest {

    private Game game;
    private List<GamePlayer> players;

    @BeforeEach
    public void setUp() {
        // 创建4个测试玩家
        players = new ArrayList<>();
        for (int i = 0; i < 4; i++) {
            GamePlayer player = new GamePlayer("player" + i, "测试玩家" + i);
            player.setSeat(i);
            players.add(player);
        }

        // 创建游戏实例
        game = new Game("test-room", players, false);
        game.startGame();
    }

    /**
     * 测试1：完整的游戏流程 - 无人反应的情况
     */
    @Test
    public void testCompleteGameFlow_NoReactions() {
        System.out.println("\n========== 测试1：完整游戏流程（无人反应） ==========");
        
        // 第1轮：庄家出牌
        System.out.println("\n--- 第1轮：庄家出牌 ---");
        String dealerId = "player0";
        assertEquals(14, game.getPlayerHands().get(dealerId).size(), "庄家应该有14张牌");
        
        // 庄家出牌
        int firstTile = game.getPlayerHands().get(dealerId).get(0);
        boolean discardSuccess = game.discardTile(dealerId, firstTile);
        assertTrue(discardSuccess, "庄家应该能出牌");
        assertEquals(13, game.getPlayerHands().get(dealerId).size(), "出牌后庄家应该有13张牌");
        
        // 模拟所有玩家PASS
        simulateAllPass();
        
        // 检查是否推进到下一位玩家
        assertEquals(1, game.getCurrentPlayer(), "应该推进到player1");
        
        // 第2轮：player1摸牌出牌
        System.out.println("\n--- 第2轮：player1摸牌出牌 ---");
        String player1Id = "player1";
        Integer drawnTile = game.drawTile(player1Id);
        assertNotNull(drawnTile, "player1应该能摸牌");
        assertEquals(14, game.getPlayerHands().get(player1Id).size(), "摸牌后应该有14张牌");
        
        // player1出牌
        int tileToDiscard = game.getPlayerHands().get(player1Id).get(0);
        discardSuccess = game.discardTile(player1Id, tileToDiscard);
        assertTrue(discardSuccess, "player1应该能出牌");
        assertEquals(13, game.getPlayerHands().get(player1Id).size(), "出牌后应该有13张牌");
        
        // 模拟所有玩家PASS
        simulateAllPass();
        
        // 检查是否推进到下一位玩家
        assertEquals(2, game.getCurrentPlayer(), "应该推进到player2");
        
        System.out.println("\n========== 测试1通过 ==========\n");
    }

    /**
     * 测试2：碰牌流程
     */
    @Test
    public void testPongFlow() {
        System.out.println("\n========== 测试2：碰牌流程 ==========");
        
        // 准备：给player1添加两张相同的牌
        String pongPlayerId = "player1";
        List<Integer> hand = game.getPlayerHands().get(pongPlayerId);
        int testTile = 5;
        hand.add(testTile);
        hand.add(testTile);
        
        // 庄家出这张牌
        String dealerId = "player0";
        game.discardTile(dealerId, testTile);
        
        // player1碰牌
        System.out.println("\n--- player1碰牌 ---");
        boolean pongSuccess = game.pong(pongPlayerId, testTile);
        assertTrue(pongSuccess, "player1应该能碰牌");
        assertEquals(13, game.getPlayerHands().get(pongPlayerId).size(), "碰牌后手牌数量不对");
        assertEquals(1, game.getPlayerMelds().get(pongPlayerId).size(), "应该有一个牌组");
        
        // 碰牌后，player1成为当前玩家，需要摸牌
        assertEquals(1, game.getCurrentPlayer(), "碰牌者应该成为当前玩家");
        assertFalse(game.isWaitingForReaction(), "碰牌后不应该等待反应");
        
        // player1摸牌
        System.out.println("\n--- player1摸牌 ---");
        Integer drawnTile = game.drawTile(pongPlayerId);
        assertNotNull(drawnTile, "碰牌者应该能摸牌");
        assertEquals(14, game.getPlayerHands().get(pongPlayerId).size(), "摸牌后应该有14张牌");
        
        // player1出牌
        System.out.println("\n--- player1出牌 ---");
        int tileToDiscard = game.getPlayerHands().get(pongPlayerId).get(0);
        game.discardTile(pongPlayerId, tileToDiscard);
        
        // 模拟所有玩家PASS
        simulateAllPass();
        
        System.out.println("\n========== 测试2通过 ==========\n");
    }

    /**
     * 测试3：吃牌流程（只有下家可以吃）
     */
    @Test
    public void testChowFlow() {
        System.out.println("\n========== 测试3：吃牌流程 ==========");
        
        // 准备：给player1（下家）添加可以吃的牌
        String chowPlayerId = "player1";
        List<Integer> hand = game.getPlayerHands().get(chowPlayerId);
        int discardedTile = 5;
        hand.add(3);
        hand.add(4);
        
        // 庄家出牌
        String dealerId = "player0";
        game.discardTile(dealerId, discardedTile);
        
        // player1吃牌
        System.out.println("\n--- player1吃牌 ---");
        boolean chowSuccess = game.chow(chowPlayerId, discardedTile);
        assertTrue(chowSuccess, "下家应该能吃牌");
        assertEquals(13, game.getPlayerHands().get(chowPlayerId).size(), "吃牌后手牌数量不对");
        assertEquals(1, game.getPlayerMelds().get(chowPlayerId).size(), "应该有一个牌组");
        
        // 吃牌后，player1成为当前玩家，需要摸牌
        assertEquals(1, game.getCurrentPlayer(), "吃牌者应该成为当前玩家");
        assertFalse(game.isWaitingForReaction(), "吃牌后不应该等待反应");
        
        // player1摸牌
        System.out.println("\n--- player1摸牌 ---");
        Integer drawnTile = game.drawTile(chowPlayerId);
        assertNotNull(drawnTile, "吃牌者应该能摸牌");
        
        System.out.println("\n========== 测试3通过 ==========\n");
    }

    /**
     * 测试4：对家不能吃牌
     */
    @Test
    public void testCannotChowForOpponent() {
        System.out.println("\n========== 测试4：对家不能吃牌 ==========");
        
        // 准备：给player2（对家）添加可以吃的牌
        String opponentId = "player2";
        List<Integer> hand = game.getPlayerHands().get(opponentId);
        int discardedTile = 5;
        hand.add(3);
        hand.add(4);
        
        // 庄家出牌
        String dealerId = "player0";
        game.discardTile(dealerId, discardedTile);
        
        // player2尝试吃牌（应该失败）
        System.out.println("\n--- player2尝试吃牌（应该失败） ---");
        boolean canChow = game.canChow(opponentId, discardedTile);
        assertFalse(canChow, "对家不能吃牌");
        
        System.out.println("\n========== 测试4通过 ==========\n");
    }

    /**
     * 测试5：杠牌流程
     */
    @Test
    public void testKongFlow() {
        System.out.println("\n========== 测试5：杠牌流程 ==========");
        
        // 准备：给player1添加三张相同的牌
        String kongPlayerId = "player1";
        List<Integer> hand = game.getPlayerHands().get(kongPlayerId);
        int testTile = 7;
        hand.add(testTile);
        hand.add(testTile);
        hand.add(testTile);
        
        // 庄家出这张牌
        String dealerId = "player0";
        game.discardTile(dealerId, testTile);
        
        // player1明杠
        System.out.println("\n--- player1明杠 ---");
        boolean kongSuccess = game.kong(kongPlayerId, testTile);
        assertTrue(kongSuccess, "player1应该能明杠");
        
        // 杠牌后，player1成为当前玩家，需要从杠尾摸牌
        assertEquals(1, game.getCurrentPlayer(), "杠牌者应该成为当前玩家");
        assertFalse(game.isWaitingForReaction(), "杠牌后不应该等待反应");
        
        System.out.println("\n========== 测试5通过 ==========\n");
    }

    /**
     * 测试6：多轮游戏流程
     */
    @Test
    public void testMultipleRounds() {
        System.out.println("\n========== 测试6：多轮游戏流程 ==========");
        
        // 进行5轮游戏
        for (int round = 1; round <= 5; round++) {
            System.out.println("\n--- 第" + round + "轮 ---");
            
            int currentPlayerSeat = game.getCurrentPlayer();
            String currentPlayerId = "player" + currentPlayerSeat;
            
            // 如果不是庄家第一轮，需要先摸牌
            if (!(round == 1 && currentPlayerSeat == 0)) {
                Integer drawnTile = game.drawTile(currentPlayerId);
                assertNotNull(drawnTile, "第" + round + "轮应该能摸牌");
                assertEquals(14, game.getPlayerHands().get(currentPlayerId).size());
            }
            
            // 出牌
            int tileToDiscard = game.getPlayerHands().get(currentPlayerId).get(0);
            boolean discardSuccess = game.discardTile(currentPlayerId, tileToDiscard);
            assertTrue(discardSuccess, "第" + round + "轮应该能出牌");
            assertEquals(13, game.getPlayerHands().get(currentPlayerId).size());
            
            // 模拟所有玩家PASS
            simulateAllPass();
            
            // 检查是否推进到下一位玩家
            int expectedNextPlayer = (currentPlayerSeat + 1) % 4;
            assertEquals(expectedNextPlayer, game.getCurrentPlayer(), 
                "第" + round + "轮后应该推进到player" + expectedNextPlayer);
        }
        
        System.out.println("\n========== 测试6通过 ==========\n");
    }

    /**
     * 测试7：牌数守恒
     */
    @Test
    public void testTileCountConservation() {
        System.out.println("\n========== 测试7：牌数守恒 ==========");
        
        // 初始总牌数
        int initialTotal = countTotalTiles();
        System.out.println("初始总牌数: " + initialTotal);
        assertEquals(136, initialTotal, "初始总牌数应该是136");
        
        // 进行几轮游戏
        for (int i = 0; i < 3; i++) {
            String playerId = "player" + game.getCurrentPlayer();
            
            if (i > 0 || game.getCurrentPlayer() != 0) {
                game.drawTile(playerId);
            }
            
            int tile = game.getPlayerHands().get(playerId).get(0);
            game.discardTile(playerId, tile);
            simulateAllPass();
            
            // 每次操作后检查总牌数
            int currentTotal = countTotalTiles();
            assertEquals(initialTotal, currentTotal, "第" + (i+1) + "轮后总牌数应该守恒");
        }
        
        System.out.println("最终总牌数: " + countTotalTiles());
        System.out.println("\n========== 测试7通过 ==========\n");
    }

    /**
     * 测试8：状态一致性
     */
    @Test
    public void testStateConsistency() {
        System.out.println("\n========== 测试8：状态一致性 ==========");
        
        // 庄家出牌
        String dealerId = "player0";
        int tile = game.getPlayerHands().get(dealerId).get(0);
        game.discardTile(dealerId, tile);
        
        // 检查状态
        assertTrue(game.isWaitingForReaction(), "出牌后应该等待反应");
        assertEquals("DISCARD", game.getLastAction());
        assertEquals(dealerId, game.getLastActionPlayer());
        assertEquals(Integer.valueOf(tile), game.getLastActionTile());
        
        // 模拟PASS
        simulateAllPass();
        
        // 检查状态
        assertFalse(game.isWaitingForReaction(), "所有玩家PASS后不应该等待反应");
        assertEquals(1, game.getCurrentPlayer(), "应该推进到下一位玩家");
        
        System.out.println("\n========== 测试8通过 ==========\n");
    }

    // ==================== 辅助方法 ====================

    /**
     * 模拟所有玩家PASS
     */
    private void simulateAllPass() {
        if (!game.isWaitingForReaction()) {
            return;
        }
        
        List<String> pendingReactions = new ArrayList<>(game.getPendingReactions());
        System.out.println("  模拟 " + pendingReactions.size() + " 位玩家PASS");
        
        for (String playerId : pendingReactions) {
            game.resolveReaction(playerId, "PASS", null);
        }
    }

    /**
     * 计算总牌数
     */
    private int countTotalTiles() {
        int totalInHands = 0;
        for (List<Integer> hand : game.getPlayerHands().values()) {
            totalInHands += hand.size();
        }
        
        int totalDiscarded = 0;
        for (List<Integer> discarded : game.getPlayerDiscarded().values()) {
            totalDiscarded += discarded.size();
        }
        
        int totalInWall = game.getWall().size();
        
        return totalInHands + totalDiscarded + totalInWall;
    }
}
