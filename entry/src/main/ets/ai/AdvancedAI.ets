// 高级AI系统
// 包含不同难度级别的AI决策算法

import { MahjongRules, MahjongTile } from '../engine/MahjongRules';

export enum AIDifficulty {
  EASY = 'easy',
  MEDIUM = 'medium', 
  HARD = 'hard'
}

export interface AIDecision {
  action: 'DISCARD' | 'PONG' | 'CHOW' | 'KONG' | 'WIN' | 'PASS';
  tile?: number;
  targetTile?: number;
  confidence: number;
}

export class AdvancedAI {
  private difficulty: AIDifficulty;
  private playerSeat: number;
  private gameState: object = {};

  constructor(difficulty: AIDifficulty = AIDifficulty.MEDIUM, playerSeat: number = 0) {
    this.difficulty = difficulty;
    this.playerSeat = playerSeat;
  }

  // 设置游戏状态
  setGameState(state: object): void {
    this.gameState = state;
  }

  // AI决策主函数
  makeDecision(hand: number[], lastTile?: number): AIDecision {
    if (!lastTile) {
      // 主动出牌
      return this.decideDiscard(hand);
    } else {
      // 响应其他玩家出牌
      return this.decideResponse(hand, lastTile);
    }
  }

  // 决定出哪张牌
  private decideDiscard(hand: number[]): AIDecision {
    const sortedHand = [...hand].sort((a, b) => a - b);
    
    // 根据难度选择策略
    switch (this.difficulty) {
      case AIDifficulty.EASY:
        return this.easyDiscard(sortedHand);
      case AIDifficulty.MEDIUM:
        return this.mediumDiscard(sortedHand);
      case AIDifficulty.HARD:
        return this.hardDiscard(sortedHand);
      default:
        return this.mediumDiscard(sortedHand);
    }
  }

  // 简单难度出牌策略
  private easyDiscard(hand: number[]): AIDecision {
    // 随机出牌
    const randomIndex = Math.floor(Math.random() * hand.length);
    return {
      action: 'DISCARD',
      tile: hand[randomIndex],
      confidence: 0.3
    };
  }

  // 中等难度出牌策略
  private mediumDiscard(hand: number[]): AIDecision {
    // 优先出孤张和字牌
    const tileScores = this.calculateTileScores(hand);
    const worstTile = this.findWorstTile(tileScores);
    
    return {
      action: 'DISCARD',
      tile: worstTile,
      confidence: 0.7
    };
  }

  // 困难难度出牌策略
  private hardDiscard(hand: number[]): AIDecision {
    // 基于概率计算和策略树
    const tileScores = this.calculateAdvancedScores(hand);
    const bestDiscard = this.findOptimalDiscard(tileScores, hand);
    
    return {
      action: 'DISCARD',
      tile: bestDiscard,
      confidence: 0.9
    };
  }

  // 计算牌的价值分数
  private calculateTileScores(hand: number[]): Map<number, number> {
    const scores = new Map<number, number>();
    
    hand.forEach(tile => {
      let score = 0;
      const tileInfo = MahjongRules.getTileInfo(tile);
      
      if (!tileInfo) {
        scores.set(tile, 0);
        return;
      }

      // 基础分数
      switch (tileInfo.type) {
        case 0: // CHARACTER
        case 1: // BAMBOO  
        case 2: // DOT
          score = this.calculateNumberTileScore(hand, tile);
          break;
        case 3: // HONOR
          score = this.calculateHonorTileScore(hand, tile);
          break;
        case 4: // FLOWER
          score = 0.1; // 花牌价值低
          break;
      }
      
      scores.set(tile, score);
    });
    
    return scores;
  }

  // 计算数字牌分数
  private calculateNumberTileScore(hand: number[], tile: number): number {
    let score = 0;
    const count = hand.filter(t => t === tile).length;
    
    // 对子/刻子价值高
    if (count >= 2) score += count * 2;
    
    // 检查是否形成顺子
    const tileInfo = MahjongRules.getTileInfo(tile);
    if (tileInfo && tileInfo.value <= 7) {
      const hasSequence = hand.includes(tile + 1) && hand.includes(tile + 2);
      if (hasSequence) score += 3;
    }
    
    // 边张价值低
    if (tileInfo && (tileInfo.value === 1 || tileInfo.value === 9)) {
      score -= 1;
    }
    
    return Math.max(score, 0.1);
  }

  // 计算字牌分数
  private calculateHonorTileScore(hand: number[], tile: number): number {
    const count = hand.filter(t => t === tile).length;
    
    // 字牌只有成对/刻子才有价值
    if (count >= 2) {
      return count * 3;
    }
    
    return 0.1; // 单张字牌价值低
  }

  // 找到最差的牌
  private findWorstTile(scores: Map<number, number>): number {
    let worstTile = 0;
    let worstScore = Infinity;
    
    scores.forEach((score, tile) => {
      if (score < worstScore) {
        worstScore = score;
        worstTile = tile;
      }
    });
    
    return worstTile;
  }

  // 高级分数计算
  private calculateAdvancedScores(hand: number[]): Map<number, number> {
    const scores = this.calculateTileScores(hand);
    
    // 考虑听牌概率
    hand.forEach(tile => {
      const currentScore = scores.get(tile) || 0;
      const tingProbability = this.calculateTingProbability(hand, tile);
      scores.set(tile, currentScore + tingProbability * 5);
    });
    
    return scores;
  }

  // 计算听牌概率
  private calculateTingProbability(hand: number[], discardTile: number): number {
    const simulatedHand = hand.filter(t => t !== discardTile);
    let tingCount = 0;
    const totalTiles = 34; // 麻将牌总数
    
    // 模拟所有可能的摸牌
    for (let tile = 1; tile <= totalTiles; tile++) {
      if (MahjongRules.canWin(simulatedHand, tile)) {
        tingCount++;
      }
    }
    
    return tingCount / totalTiles;
  }

  // 找到最优出牌
  private findOptimalDiscard(scores: Map<number, number>, hand: number[]): number {
    // 考虑安全性和进攻性
    const safeTiles = this.identifySafeTiles(hand);
    
    let bestTile = 0;
    let bestScore = -Infinity;
    
    scores.forEach((score, tile) => {
      // 安全牌加分
      if (safeTiles.has(tile)) {
        score += 2;
      }
      
      if (score > bestScore) {
        bestScore = score;
        bestTile = tile;
      }
    });
    
    return bestTile;
  }

  // 识别安全牌
  private identifySafeTiles(hand: number[]): Set<number> {
    const safeTiles = new Set<number>();
    
    // 这里可以添加更复杂的安全牌识别逻辑
    // 暂时返回空集
    return safeTiles;
  }

  // 决定响应动作
  private decideResponse(hand: number[], lastTile: number): AIDecision {
    const actions = MahjongRules.getAvailableActions(hand, lastTile);
    
    if (actions.length === 0) {
      return { action: 'PASS', confidence: 1.0 };
    }

    // 根据难度选择响应策略
    switch (this.difficulty) {
      case AIDifficulty.EASY:
        return this.easyResponse(actions, lastTile);
      case AIDifficulty.MEDIUM:
        return this.mediumResponse(actions, lastTile, hand);
      case AIDifficulty.HARD:
        return this.hardResponse(actions, lastTile, hand);
      default:
        return this.mediumResponse(actions, lastTile, hand);
    }
  }

  // 简单响应策略
  private easyResponse(actions: string[], lastTile: number): AIDecision {
    // 优先胡牌，否则随机选择
    if (actions.includes('WIN')) {
      return { action: 'WIN', confidence: 0.8 };
    }
    
    const randomAction = actions[Math.floor(Math.random() * actions.length)];
    return {
      action: randomAction as AIDecision['action'],
      targetTile: lastTile,
      confidence: 0.4
    };
  }

  // 中等响应策略
  private mediumResponse(actions: string[], lastTile: number, hand: number[]): AIDecision {
    // 优先胡牌，然后考虑杠、碰、吃
    if (actions.includes('WIN')) {
      return { action: 'WIN', confidence: 0.9 };
    }
    
    if (actions.includes('KONG')) {
      return { action: 'KONG', targetTile: lastTile, confidence: 0.8 };
    }
    
    if (actions.includes('PONG')) {
      // 检查碰牌是否有利
      const benefit = this.assessPongBenefit(hand, lastTile);
      if (benefit > 0.5) {
        return { action: 'PONG', targetTile: lastTile, confidence: 0.7 };
      }
    }
    
    if (actions.includes('CHOW')) {
      // 检查吃牌是否有利
      const benefit = this.assessChowBenefit(hand, lastTile);
      if (benefit > 0.6) {
        return { action: 'CHOW', targetTile: lastTile, confidence: 0.6 };
      }
    }
    
    return { action: 'PASS', confidence: 0.8 };
  }

  // 困难响应策略
  private hardResponse(actions: string[], lastTile: number, hand: number[]): AIDecision {
    // 基于概率计算的最优决策
    const actionScores = new Map<string, number>();
    
    actions.forEach(action => {
      let score = 0;
      
      switch (action) {
        case 'WIN':
          score = this.calculateWinScore(hand, lastTile);
          break;
        case 'KONG':
          score = this.calculateKongScore(hand, lastTile);
          break;
        case 'PONG':
          score = this.calculatePongScore(hand, lastTile);
          break;
        case 'CHOW':
          score = this.calculateChowScore(hand, lastTile);
          break;
      }
      
      actionScores.set(action, score);
    });
    
    // 选择分数最高的动作
    let bestAction = 'PASS';
    let bestScore = 0;
    
    actionScores.forEach((score, action) => {
      if (score > bestScore) {
        bestScore = score;
        bestAction = action;
      }
    });
    
    return {
      action: bestAction as AIDecision['action'],
      targetTile: lastTile,
      confidence: bestScore
    };
  }

  // 计算胡牌收益
  private calculateWinScore(hand: number[], lastTile: number): number {
    return 1.0; // 胡牌总是最优选择
  }

  // 计算杠牌收益
  private calculateKongScore(hand: number[], lastTile: number): number {
    return 0.8; // 杠牌收益高
  }

  // 计算碰牌收益
  private calculatePongScore(hand: number[], lastTile: number): number {
    const count = hand.filter(t => t === lastTile).length;
    return count === 2 ? 0.7 : 0.3;
  }

  // 计算吃牌收益
  private calculateChowScore(hand: number[], lastTile: number): number {
    return 0.5; // 吃牌收益中等
  }

  // 评估碰牌收益
  private assessPongBenefit(hand: number[], tile: number): number {
    const count = hand.filter(t => t === tile).length;
    return count === 2 ? 0.8 : 0.3;
  }

  // 评估吃牌收益
  private assessChowBenefit(hand: number[], tile: number): number {
    const tileInfo = MahjongRules.getTileInfo(tile);
    if (!tileInfo || tileInfo.type === 3) return 0; // 字牌不能吃
    
    // 检查吃牌后是否有利于听牌
    return 0.6;
  }

  // 设置AI难度
  setDifficulty(difficulty: AIDifficulty): void {
    this.difficulty = difficulty;
  }

  // 获取AI难度
  getDifficulty(): AIDifficulty {
    return this.difficulty;
  }
}