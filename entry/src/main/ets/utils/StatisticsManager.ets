export interface GameRecord {
  gameId: string;
  timestamp: number;
  players: string[];
  winner: string;
  scores: Record<string, number>;
  duration: number;
}

export interface PlayerStatistics {
  totalGames: number;
  winCount: number;
  loseCount: number;
  drawCount: number;
  totalScore: number;
  averageScore: number;
  winRate: number;
  bestScore: number;
  worstScore: number;
}

export class StatisticsManager {
  private static instance: StatisticsManager;
  private records: GameRecord[] = [];
  private playerStats: Map<string, PlayerStatistics> = new Map();

  private constructor() {
    this.loadFromStorage();
  }

  static getInstance(): StatisticsManager {
    if (!StatisticsManager.instance) {
      StatisticsManager.instance = new StatisticsManager();
    }
    return StatisticsManager.instance;
  }

  // 记录游戏结果
  recordGame(record: GameRecord): void {
    this.records.push(record);
    
    // 更新玩家统计
    record.players.forEach(playerId => {
      const score = record.scores[playerId] || 0;
      this.updatePlayerStats(playerId, score, playerId === record.winner);
    });

    this.saveToStorage();
  }

  // 更新玩家统计
  private updatePlayerStats(playerId: string, score: number, isWinner: boolean): void {
    let stats = this.playerStats.get(playerId);
    
    if (!stats) {
      stats = {
        totalGames: 0,
        winCount: 0,
        loseCount: 0,
        drawCount: 0,
        totalScore: 0,
        averageScore: 0,
        winRate: 0,
        bestScore: -Infinity,
        worstScore: Infinity
      };
    }

    stats.totalGames++;
    stats.totalScore += score;
    
    if (isWinner) {
      stats.winCount++;
    } else if (score < 0) {
      stats.loseCount++;
    } else {
      stats.drawCount++;
    }

    if (score > stats.bestScore) {
      stats.bestScore = score;
    }
    if (score < stats.worstScore) {
      stats.worstScore = score;
    }

    stats.averageScore = stats.totalScore / stats.totalGames;
    stats.winRate = (stats.winCount / stats.totalGames) * 100;

    this.playerStats.set(playerId, stats);
  }

  // 获取玩家统计
  getPlayerStats(playerId: string): PlayerStatistics | null {
    return this.playerStats.get(playerId) || null;
  }

  // 获取所有玩家统计
  getAllPlayerStats(): Map<string, PlayerStatistics> {
    return new Map(this.playerStats);
  }

  // 获取排行榜
  getLeaderboard(): Array<{ playerId: string; stats: PlayerStatistics }> {
    const leaderboard: Array<{ playerId: string; stats: PlayerStatistics }> = [];
    
    this.playerStats.forEach((stats, playerId) => {
      leaderboard.push({ playerId, stats });
    });

    // 按胜率排序
    leaderboard.sort((a, b) => b.stats.winRate - a.stats.winRate);
    
    return leaderboard;
  }

  // 获取游戏历史
  getGameHistory(limit: number = 10): GameRecord[] {
    return this.records.slice(-limit).reverse();
  }

  // 保存到本地存储
  private saveToStorage(): void {
    try {
      const data = {
        records: this.records,
        playerStats: Object.fromEntries(this.playerStats)
      };
      // TODO: 使用 Preferences 或 localStorage 保存
      console.info('统计数据已保存');
    } catch (e) {
      console.error('保存统计数据失败:', e);
    }
  }

  // 从本地存储加载
  private loadFromStorage(): void {
    try {
      // TODO: 从 Preferences 或 localStorage 加载
      console.info('统计数据已加载');
    } catch (e) {
      console.error('加载统计数据失败:', e);
    }
  }

  // 清除所有数据
  clearAll(): void {
    this.records = [];
    this.playerStats.clear();
    this.saveToStorage();
  }
}

export const statisticsManager = StatisticsManager.getInstance();
