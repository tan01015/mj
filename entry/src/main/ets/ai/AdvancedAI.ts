import { MahjongRules, MahjongTile, PlayerAction } from '../engine/MahjongRules';
import { PlayerState } from '../engine/MahjongGame';

// AI难度级别
export enum AIDifficulty {
  EASY = 'easy',
  MEDIUM = 'medium', 
  HARD = 'hard'
}

// AI决策结果
export interface AIDecision {
  action: PlayerAction;
  tile?: number;
  confidence: number; // 0-1 置信度
  reasoning: string;  // 决策理由
}

// 高级AI系统
export class AdvancedAI {
  private difficulty: AIDifficulty;
  private playerSeat: number;
  
  constructor(seat: number, difficulty: AIDifficulty = AIDifficulty.MEDIUM) {
    this.playerSeat = seat;
    this.difficulty = difficulty;
  }
  
  // 设置难度
  setDifficulty(difficulty: AIDifficulty): void {
    this.difficulty = difficulty;
  }
  
  // 决策主函数
  makeDecision(
    playerState: PlayerState,
    availableActions: PlayerAction[],
    lastDiscardedTile?: number,
    remainingTiles: number = 136
  ): AIDecision | null {
    if (availableActions.length === 0) {
      return null;
    }
    
    // 根据难度选择决策策略
    switch (this.difficulty) {
      case AIDifficulty.EASY:
        return this.easyDecision(playerState, availableActions, lastDiscardedTile, remainingTiles);
      case AIDifficulty.MEDIUM:
        return this.mediumDecision(playerState, availableActions, lastDiscardedTile, remainingTiles);
      case AIDifficulty.HARD:
        return this.hardDecision(playerState, availableActions, lastDiscardedTile, remainingTiles);
      default:
        return this.mediumDecision(playerState, availableActions, lastDiscardedTile, remainingTiles);
    }
  }
  
  // 简单AI决策（随机选择）
  private easyDecision(
    playerState: PlayerState,
    availableActions: PlayerAction[],
    lastDiscardedTile?: number,
    remainingTiles: number = 136
  ): AIDecision {
    // 优先胡牌
    if (availableActions.includes(PlayerAction.WIN)) {
      return {
        action: PlayerAction.WIN,
        confidence: 0.9,
        reasoning: '简单AI：检测到胡牌机会，直接胡牌'
      };
    }
    
    // 随机选择动作
    const randomAction = availableActions[Math.floor(Math.random() * availableActions.length)];
    let tile: number | undefined;
    let reasoning = '';
    
    switch (randomAction) {
      case PlayerAction.DISCARD:
        tile = this.chooseDiscardTileEasy(playerState.hand);
        reasoning = `简单AI：随机出牌 ${MahjongRules.getTileDisplayText(tile!)}`;
        break;
      case PlayerAction.PONG:
        reasoning = '简单AI：随机选择碰牌';
        break;
      case PlayerAction.CHOW:
        reasoning = '简单AI：随机选择吃牌';
        break;
      case PlayerAction.KONG:
        reasoning = '简单AI：随机选择杠牌';
        break;
      default:
        reasoning = `简单AI：执行 ${randomAction} 动作`;
    }
    
    return {
      action: randomAction,
      tile,
      confidence: 0.3,
      reasoning
    };
  }
  
  // 中等AI决策（基础策略）
  private mediumDecision(
    playerState: PlayerState,
    availableActions: PlayerAction[],
    lastDiscardedTile?: number,
    remainingTiles: number = 136
  ): AIDecision {
    // 1. 优先胡牌
    if (availableActions.includes(PlayerAction.WIN)) {
      return {
        action: PlayerAction.WIN,
        confidence: 0.95,
        reasoning: '中等AI：检测到胡牌机会，立即胡牌'
      };
    }
    
    // 2. 优先杠牌（得分高）
    if (availableActions.includes(PlayerAction.KONG)) {
      return {
        action: PlayerAction.KONG,
        confidence: 0.8,
        reasoning: '中等AI：检测到杠牌机会，优先杠牌'
      };
    }
    
    // 3. 考虑碰牌
    if (availableActions.includes(PlayerAction.PONG)) {
      const shouldPong = this.shouldPongMedium(playerState, lastDiscardedTile!);
      if (shouldPong) {
        return {
          action: PlayerAction.PONG,
          confidence: 0.7,
          reasoning: '中等AI：判断碰牌有利于组牌，选择碰牌'
        };
      }
    }
    
    // 4. 考虑吃牌
    if (availableActions.includes(PlayerAction.CHOW)) {
      const shouldChow = this.shouldChowMedium(playerState, lastDiscardedTile!);
      if (shouldChow) {
        return {
          action: PlayerAction.CHOW,
          confidence: 0.6,
          reasoning: '中等AI：判断吃牌有利于组牌，选择吃牌'
        };
      }
    }
    
    // 5. 出牌策略
    if (availableActions.includes(PlayerAction.DISCARD)) {
      const tile = this.chooseDiscardTileMedium(playerState.hand, remainingTiles);
      return {
        action: PlayerAction.DISCARD,
        tile,
        confidence: 0.5,
        reasoning: `中等AI：策略性出牌 ${MahjongRules.getTileDisplayText(tile)}`
      };
    }
    
    // 6. 默认摸牌
    return {
      action: PlayerAction.DRAW,
      confidence: 0.4,
      reasoning: '中等AI：没有更好的选择，摸牌等待机会'
    };
  }
  
  // 困难AI决策（高级策略）
  private hardDecision(
    playerState: PlayerState,
    availableActions: PlayerAction[],
    lastDiscardedTile?: number,
    remainingTiles: number = 136
  ): AIDecision {
    // 1. 评估胡牌概率
    if (availableActions.includes(PlayerAction.WIN)) {
      const winProbability = this.calculateWinProbability(playerState, lastDiscardedTile!);
      if (winProbability > 0.7) {
        return {
          action: PlayerAction.WIN,
          confidence: winProbability,
          reasoning: `困难AI：胡牌概率 ${(winProbability * 100).toFixed(1)}%，选择胡牌`
        };
      }
    }
    
    // 2. 杠牌策略
    if (availableActions.includes(PlayerAction.KONG)) {
      const kongValue = this.evaluateKongValue(playerState, lastDiscardedTile);
      if (kongValue > 0.6) {
        return {
          action: PlayerAction.KONG,
          confidence: kongValue,
          reasoning: '困难AI：杠牌价值高，优先杠牌'
        };
      }
    }
    
    // 3. 碰牌策略
    if (availableActions.includes(PlayerAction.PONG)) {
      const pongValue = this.evaluatePongValue(playerState, lastDiscardedTile!);
      if (pongValue > 0.5) {
        return {
          action: PlayerAction.PONG,
          confidence: pongValue,
          reasoning: '困难AI：碰牌有利于牌型发展，选择碰牌'
        };
      }
    }
    
    // 4. 吃牌策略
    if (availableActions.includes(PlayerAction.CHOW)) {
      const chowValue = this.evaluateChowValue(playerState, lastDiscardedTile!);
      if (chowValue > 0.4) {
        return {
          action: PlayerAction.CHOW,
          confidence: chowValue,
          reasoning: '困难AI：吃牌有利于顺子形成，选择吃牌'
        };
      }
    }
    
    // 5. 高级出牌策略
    if (availableActions.includes(PlayerAction.DISCARD)) {
      const tile = this.chooseDiscardTileHard(playerState.hand, remainingTiles);
      const discardValue = this.evaluateDiscardValue(playerState.hand, tile);
      
      return {
        action: PlayerAction.DISCARD,
        tile,
        confidence: discardValue,
        reasoning: `困难AI：高级策略出牌 ${MahjongRules.getTileDisplayText(tile)}，安全度 ${(discardValue * 100).toFixed(1)}%`
      };
    }
    
    // 6. 摸牌等待
    return {
      action: PlayerAction.DRAW,
      confidence: 0.3,
      reasoning: '困难AI：等待更好的机会，选择摸牌'
    };
  }
  
  // 简单AI出牌选择（随机出单张）
  private chooseDiscardTileEasy(hand: number[]): number {
    // 随机选择一张牌
    return hand[Math.floor(Math.random() * hand.length)];
  }
  
  // 中等AI出牌选择（出孤张牌）
  private chooseDiscardTileMedium(hand: number[], remainingTiles: number): number {
    const tileValues = this.analyzeHand(hand);
    
    // 优先出孤张牌（没有相邻牌的牌）
    for (const tile of hand) {
      const tileInfo = MahjongRules.getTileInfo(tile);
      if (!tileInfo || tileInfo.isFlower) continue;
      
      if (this.isIsolatedTile(hand, tile)) {
        return tile;
      }
    }
    
    // 其次出字牌
    for (const tile of hand) {
      const tileInfo = MahjongRules.getTileInfo(tile);
      if (tileInfo && tileInfo.type === 'honors' && !tileInfo.isRedDragon) {
        return tile;
      }
    }
    
    // 最后随机出牌
    return this.chooseDiscardTileEasy(hand);
  }
  
  // 困难AI出牌选择（安全牌策略）
  private chooseDiscardTileHard(hand: number[], remainingTiles: number): number {
    const safeTiles = this.identifySafeTiles(hand);
    
    if (safeTiles.length > 0) {
      // 从安全牌中选择价值最低的
      return safeTiles.reduce((worst, current) => {
        const currentValue = this.calculateTileValue(current);
        const worstValue = this.calculateTileValue(worst);
        return currentValue < worstValue ? current : worst;
      });
    }
    
    // 没有安全牌，选择价值最低的牌
    return hand.reduce((worst, current) => {
      const currentValue = this.calculateTileValue(current);
      const worstValue = this.calculateTileValue(worst);
      return currentValue < worstValue ? current : worst;
    });
  }
  
  // 分析手牌结构
  private analyzeHand(hand: number[]): any {
    const analysis = {
      singles: [] as number[],      // 单张牌
      pairs: [] as number[],        // 对子
      sequences: [] as number[][],  // 顺子
      triplets: [] as number[][]    // 刻子
    };
    
    // 按类型和值分组
    const groups: {[key: string]: number[]} = {};
    hand.forEach(tile => {
      const tileInfo = MahjongRules.getTileInfo(tile);
      if (tileInfo && !tileInfo.isFlower) {
        const key = `${tileInfo.type}-${tileInfo.value}`;
        if (!groups[key]) {
          groups[key] = [];
        }
        groups[key].push(tile);
      }
    });
    
    // 分析牌型
    for (const key in groups) {
      const tiles = groups[key];
      if (tiles.length === 1) {
        analysis.singles.push(tiles[0]);
      } else if (tiles.length === 2) {
        analysis.pairs.push(tiles[0]);
      } else if (tiles.length >= 3) {
        analysis.triplets.push(tiles.slice(0, 3));
      }
    }
    
    return analysis;
  }
  
  // 检查是否为孤张牌
  private isIsolatedTile(hand: number[], tile: number): boolean {
    const tileInfo = MahjongRules.getTileInfo(tile);
    if (!tileInfo || tileInfo.isFlower || tileInfo.type === 'honors') {
      return true; // 字牌和花牌默认为孤张
    }
    
    const adjacentTiles = hand.filter(t => {
      const tInfo = MahjongRules.getTileInfo(t);
      return tInfo && 
             tInfo.type === tileInfo.type && 
             Math.abs(tInfo.value - tileInfo.value) <= 2;
    });
    
    return adjacentTiles.length <= 1; // 相邻牌少于等于1张则为孤张
  }
  
  // 识别安全牌
  private identifySafeTiles(hand: number[]): number[] {
    const safeTiles: number[] = [];
    
    hand.forEach(tile => {
      const tileInfo = MahjongRules.getTileInfo(tile);
      if (!tileInfo) return;
      
      // 字牌相对安全
      if (tileInfo.type === 'honors') {
        safeTiles.push(tile);
      }
      
      // 边缘牌相对安全（1和9）
      if (tileInfo.value === 1 || tileInfo.value === 9) {
        safeTiles.push(tile);
      }
    });
    
    return safeTiles;
  }
  
  // 计算牌的价值
  private calculateTileValue(tile: number): number {
    const tileInfo = MahjongRules.getTileInfo(tile);
    if (!tileInfo) return 0;
    
    let value = 1;
    
    // 中张牌价值高（2-8）
    if (tileInfo.value >= 2 && tileInfo.value <= 8) {
      value += 2;
    }
    
    // 红中价值最高
    if (tileInfo.isRedDragon) {
      value += 3;
    }
    
    return value;
  }
  
  // 中等AI碰牌判断
  private shouldPongMedium(playerState: PlayerState, discardedTile: number): boolean {
    // 简单策略：有对子就碰
    const hand = playerState.hand;
    const sameTiles = hand.filter(t => {
      const tileInfo1 = MahjongRules.getTileInfo(t);
      const tileInfo2 = MahjongRules.getTileInfo(discardedTile);
      return tileInfo1 && tileInfo2 && 
             tileInfo1.type === tileInfo2.type && 
             tileInfo1.value === tileInfo2.value;
    });
    
    return sameTiles.length >= 2;
  }
  
  // 中等AI吃牌判断
  private shouldChowMedium(playerState: PlayerState, discardedTile: number): boolean {
    // 简单策略：能吃就吃
    return MahjongRules.canChow(playerState.hand, discardedTile, 0);
  }
  
  // 困难AI胡牌概率计算
  private calculateWinProbability(playerState: PlayerState, winningTile: number): number {
    const hand = playerState.hand;
    const allTiles = [...hand, winningTile];
    
    if (MahjongRules.canWin(hand, winningTile)) {
      return 1.0; // 一定能胡
    }
    
    // 简化版概率计算
    const neededTiles = this.estimateNeededTiles(hand);
    return Math.max(0.1, 1 - (neededTiles / 10)); // 基于所需牌数估算
  }
  
  // 估算需要多少张牌才能胡牌
  private estimateNeededTiles(hand: number[]): number {
    // 简化实现：计算手牌中单张牌的数量
    const analysis = this.analyzeHand(hand);
    return analysis.singles.length;
  }
  
  // 评估杠牌价值
  private evaluateKongValue(playerState: PlayerState, discardedTile?: number): number {
    // 杠牌通常有价值
    return 0.7;
  }
  
  // 评估碰牌价值
  private evaluatePongValue(playerState: PlayerState, discardedTile: number): number {
    const tileInfo = MahjongRules.getTileInfo(discardedTile);
    if (!tileInfo) return 0;
    
    // 字牌和中张牌碰牌价值高
    if (tileInfo.type === 'honors' || (tileInfo.value >= 2 && tileInfo.value <= 8)) {
      return 0.6;
    }
    
    return 0.4;
  }
  
  // 评估吃牌价值
  private evaluateChowValue(playerState: PlayerState, discardedTile: number): number {
    // 吃牌价值相对较低
    return 0.3;
  }
  
  // 评估出牌安全度
  private evaluateDiscardValue(hand: number[], tile: number): number {
    const tileInfo = MahjongRules.getTileInfo(tile);
    if (!tileInfo) return 0;
    
    let safety = 0.5; // 基础安全度
    
    // 字牌相对安全
    if (tileInfo.type === 'honors') {
      safety += 0.2;
    }
    
    // 边缘牌相对安全
    if (tileInfo.value === 1 || tileInfo.value === 9) {
      safety += 0.1;
    }
    
    // 红中非常安全
    if (tileInfo.isRedDragon) {
      safety += 0.3;
    }
    
    return Math.min(1.0, safety);
  }
}