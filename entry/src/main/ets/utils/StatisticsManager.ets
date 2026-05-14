import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

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

export interface LeaderboardItem {
  playerId: string;
  stats: PlayerStatistics;
}

export class StatisticsManager {
  private static instance: StatisticsManager;
  private records: GameRecord[] = [];
  private playerStats: Map<string, PlayerStatistics> = new Map();
  private dataPrefs: preferences.Preferences | null = null;
  private initialized: boolean = false;

  private constructor() {
  }

  static getInstance(): StatisticsManager {
    if (!StatisticsManager.instance) {
      StatisticsManager.instance = new StatisticsManager();
    }
    return StatisticsManager.instance;
  }

  async init(context: common.Context): Promise<void> {
    if (this.initialized) return;
    try {
      this.dataPrefs = await preferences.getPreferences(context, 'mahjong_stats');
      await this.loadFromStorage();
      this.initialized = true;
    } catch (e) {
      console.error('StatisticsManager init failed:', e);
    }
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
        bestScore: 0,
        worstScore: 0
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

    if (stats.totalGames === 1) {
      stats.bestScore = score;
      stats.worstScore = score;
    } else {
      if (score > stats.bestScore) {
        stats.bestScore = score;
      }
      if (score < stats.worstScore) {
        stats.worstScore = score;
      }
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
  getLeaderboard(): Array<LeaderboardItem> {
    const leaderboard: Array<LeaderboardItem> = [];
    
    this.playerStats.forEach((stats: PlayerStatistics, playerId: string) => {
      const item: LeaderboardItem = { playerId: playerId, stats: stats };
      leaderboard.push(item);
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
  private async saveToStorage(): Promise<void> {
    if (!this.dataPrefs) return;
    try {
      await this.dataPrefs.put('records', JSON.stringify(this.records));
      const statsObj: Record<string, PlayerStatistics> = {};
      this.playerStats.forEach((value, key) => {
        statsObj[key] = value;
      });
      await this.dataPrefs.put('playerStats', JSON.stringify(statsObj));
      await this.dataPrefs.flush();
    } catch (e) {
      console.error('保存统计数据失败:', e);
    }
  }

  // 从本地存储加载
  private async loadFromStorage(): Promise<void> {
    if (!this.dataPrefs) return;
    try {
      const recordsStr = await this.dataPrefs.get('records', '[]') as string;
      const playerStatsStr = await this.dataPrefs.get('playerStats', '{}') as string;

      if (recordsStr) {
        this.records = JSON.parse(recordsStr);
      }
      if (playerStatsStr) {
        const statsObj = JSON.parse(playerStatsStr) as Record<string, PlayerStatistics>;
        Object.keys(statsObj).forEach(key => {
          this.playerStats.set(key, statsObj[key]);
        });
      }
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
