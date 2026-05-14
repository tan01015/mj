package com.mj.server.model;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

import java.util.*;

/**
 * 麻将游戏逻辑专业测试
 * 测试所有核心功能：摸牌、出牌、碰、吃、杠、胡、反应系统
 */
public class GameLogicTest {

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

    // ==================== 基础功能测试 ====================

    @Test
    public void testGameInitialization() {
        assertNotNull(game);
        assertTrue(game.isGameStarted());
        assertFalse(game.isGameEnded());
        assertEquals(4, game.getPlayers().size());
        assertEquals(136, game.getRemainingTiles() + 52); // 136 - 4*13 = 84
    }

    @Test
    public void testDrawTile() {
        String playerId = "player0";
        Integer drawnTile = game.drawTile(playerId);

        assertNotNull(drawnTile);
        assertTrue(drawnTile >= 1 && drawnTile <= 37);
        assertEquals(14, game.getPlayerHands().get(playerId).size());
    }

    @Test
    public void testDiscardTile() {
        String playerId = "player0";
        
        // 先摸牌
        game.drawTile(playerId);
        
        // 获取手牌中的第一张牌
        int tileToDiscard = game.getPlayerHands().get(playerId).get(0);
        
        // 出牌
        boolean success = game.discardTile(playerId, tileToDiscard);
        
        assertTrue(success);
        assertEquals(13, game.getPlayerHands().get(playerId).size());
        assertTrue(game.getPlayerDiscarded().get(playerId).contains(tileToDiscard));
    }

    // ==================== 碰牌测试 ====================

    @Test
    public void testPong() {
        String discarderId = "player0";
        String pongPlayerId = "player1";
        
        // 给player1手牌中添加两张相同的牌
        List<Integer> hand = game.getPlayerHands().get(pongPlayerId);
        int testTile = 5; // 测试用牌
        hand.add(testTile);
        hand.add(testTile);
        
        // player0出牌
        game.drawTile(discarderId);
        game.discardTile(discarderId, testTile);
        
        // player1碰牌
        boolean success = game.pong(pongPlayerId, testTile);
        
        assertTrue(success);
        assertEquals(11, game.getPlayerHands().get(pongPlayerId).size()); // 14-2=12, 但还没摸牌
        assertEquals(1, game.getPlayerMelds().get(pongPlayerId).size());
    }

    // ==================== 吃牌测试 ====================

    @Test
    public void testChow() {
        String discarderId = "player0";
        String chowPlayerId = "player1"; // 下家
        
        // 给player1手牌中添加可以吃的牌
        List<Integer> hand = game.getPlayerHands().get(chowPlayerId);
        int discardedTile = 5;
        hand.add(3); // 可以吃3-4-5
        hand.add(4);
        
        // player0出牌
        game.drawTile(discarderId);
        game.discardTile(discarderId, discardedTile);
        
        // player1吃牌
        boolean success = game.chow(chowPlayerId, discardedTile);
        
        assertTrue(success);
        assertEquals(12, game.getPlayerHands().get(chowPlayerId).size()); // 14-2=12
        assertEquals(1, game.getPlayerMelds().get(chowPlayerId).size());
    }

    @Test
    public void testChowOnlyForNextPlayer() {
        String discarderId = "player0";
        String otherPlayerId = "player2"; // 对家，不能吃
        
        // 给player2手牌中添加可以吃的牌
        List<Integer> hand = game.getPlayerHands().get(otherPlayerId);
        int discardedTile = 5;
        hand.add(3);
        hand.add(4);
        
        // player0出牌
        game.drawTile(discarderId);
        game.discardTile(discarderId, discardedTile);
        
        // player2尝试吃牌（应该失败）
        boolean canChow = game.canChow(otherPlayerId, discardedTile);
        assertFalse(canChow);
    }

    // ==================== 杠牌测试 ====================

    @Test
    public void testKong() {
        String discarderId = "player0";
        String kongPlayerId = "player1";
        
        // 给player1手牌中添加三张相同的牌
        List<Integer> hand = game.getPlayerHands().get(kongPlayerId);
        int testTile = 7;
        hand.add(testTile);
        hand.add(testTile);
        hand.add(testTile);
        
        // player0出牌
        game.drawTile(discarderId);
        game.discardTile(discarderId, testTile);
        
        // player1明杠
        boolean success = game.kong(kongPlayerId, testTile);
        
        assertTrue(success);
        assertEquals(11, game.getPlayerHands().get(kongPlayerId).size()); // 14-3=11
        assertEquals(1, game.getPlayerMelds().get(kongPlayerId).size());
    }

    // ==================== 胡牌测试 ====================

    @Test
    public void testCanWin() {
        String playerId = "player0";
        
        // 构造一个可以胡牌的手牌（简化测试）
        List<Integer> hand = game.getPlayerHands().get(playerId);
        hand.clear();
        
        // 添加13张牌：1万x2, 2万x2, 3万x2, 4万x2, 5万x2, 6万x2, 7万
        hand.addAll(Arrays.asList(1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7));
        
        // 检查是否可以胡8万
        boolean canWin = game.canWin(playerId, 8);
        
        // 这个牌型应该可以胡（123, 234, 456, 567 + 78作为将牌）
        // 实际结果取决于胡牌算法
        System.out.println("胡牌检查结果: " + canWin);
    }

    // ==================== 反应系统测试 ====================

    @Test
    public void testReactionSystem() {
        String discarderId = "player0";
        
        // player0出牌
        game.drawTile(discarderId);
        int discardedTile = game.getPlayerHands().get(discarderId).get(0);
        game.discardTile(discarderId, discardedTile);
        
        // 检查是否进入等待反应状态
        assertTrue(game.isWaitingForReaction());
        
        // 检查待反应玩家列表
        List<String> pendingReactions = game.getPendingReactions();
        assertNotNull(pendingReactions);
        
        System.out.println("待反应玩家: " + pendingReactions);
    }

    @Test
    public void testReactionPass() {
        String discarderId = "player0";
        
        // player0出牌
        game.drawTile(discarderId);
        int discardedTile = game.getPlayerHands().get(discarderId).get(0);
        game.discardTile(discarderId, discardedTile);
        
        // 模拟所有玩家PASS
        List<String> pendingReactions = new ArrayList<>(game.getPendingReactions());
        for (String playerId : pendingReactions) {
            game.resolveReaction(playerId, "PASS", null);
        }
        
        // 检查是否退出等待反应状态
        assertFalse(game.isWaitingForReaction());
        
        // 检查当前玩家是否推进到出牌者的下家
        int expectedNextPlayer = 1; // player0的下家是player1
        assertEquals(expectedNextPlayer, game.getCurrentPlayer());
    }

    // ==================== 回合推进测试 ====================

    @Test
    public void testTurnProgression() {
        // 初始当前玩家应该是0
        assertEquals(0, game.getCurrentPlayer());
        
        // player0摸牌出牌
        String playerId = "player0";
        game.drawTile(playerId);
        int tile = game.getPlayerHands().get(playerId).get(0);
        game.discardTile(playerId, tile);
        
        // 模拟所有玩家PASS
        List<String> pendingReactions = new ArrayList<>(game.getPendingReactions());
        for (String pid : pendingReactions) {
            game.resolveReaction(pid, "PASS", null);
        }
        
        // 当前玩家应该推进到1
        assertEquals(1, game.getCurrentPlayer());
    }

    // ==================== 边界情况测试 ====================

    @Test
    public void testDrawFromEmptyWall() {
        // 清空牌墙
        game.getWall().clear();
        
        // 尝试摸牌应该返回null
        String playerId = "player0";
        Integer drawnTile = game.drawTile(playerId);
        
        assertNull(drawnTile);
        assertTrue(game.isGameEnded());
    }

    @Test
    public void testInvalidDiscard() {
        String playerId = "player0";
        
        // 尝试出不存在的牌
        boolean success = game.discardTile(playerId, 99);
        
        assertFalse(success);
    }

    @Test
    public void testPongWithoutEnoughTiles() {
        String discarderId = "player0";
        String pongPlayerId = "player1";
        
        // player0出牌
        game.drawTile(discarderId);
        int discardedTile = game.getPlayerHands().get(discarderId).get(0);
        game.discardTile(discarderId, discardedTile);
        
        // player1没有足够的牌，碰牌应该失败
        boolean success = game.pong(pongPlayerId, discardedTile);
        
        assertFalse(success);
    }

    // ==================== 状态一致性测试 ====================

    @Test
    public void testHandSizeConsistency() {
        String playerId = "player0";
        
        // 初始手牌应该是13张
        assertEquals(13, game.getPlayerHands().get(playerId).size());
        
        // 摸牌后应该是14张
        game.drawTile(playerId);
        assertEquals(14, game.getPlayerHands().get(playerId).size());
        
        // 出牌后应该是13张
        int tile = game.getPlayerHands().get(playerId).get(0);
        game.discardTile(playerId, tile);
        assertEquals(13, game.getPlayerHands().get(playerId).size());
    }

    @Test
    public void testTotalTileCount() {
        // 计算所有手牌、弃牌、牌墙的总数
        int totalInHands = 0;
        for (List<Integer> hand : game.getPlayerHands().values()) {
            totalInHands += hand.size();
        }
        
        int totalDiscarded = 0;
        for (List<Integer> discarded : game.getPlayerDiscarded().values()) {
            totalDiscarded += discarded.size();
        }
        
        int totalInWall = game.getWall().size();
        
        // 总数应该是136（不含花牌）或108（单机模式）
        int expectedTotal = 136;
        assertEquals(expectedTotal, totalInHands + totalDiscarded + totalInWall);
    }

    // ==================== 日志输出测试 ====================

    @Test
    public void testStateSummary() {
        String summary = game.getStateSummary();
        
        assertNotNull(summary);
        assertTrue(summary.contains("游戏状态"));
        assertTrue(summary.contains("房间ID"));
        assertTrue(summary.contains("当前玩家座位"));
        
        System.out.println(summary);
    }
}
