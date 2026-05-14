// 麻将规则引擎
// 包含麻将牌定义、胡牌算法、吃碰杠逻辑、计分系统

export enum TileType {
  CHARACTER,    // 万
  BAMBOO,       // 条  
  DOT,          // 筒
  HONOR,        // 字牌
  FLOWER        // 花牌
}

export enum HonorType {
  EAST, SOUTH, WEST, NORTH,  // 东南西北
  RED, GREEN, WHITE          // 中发白
}

export interface MahjongTile {
  id: number;
  type: TileType;
  value: number;
  honorType?: HonorType;
  isRedDora?: boolean;
}

export class MahjongRules {
  private static tileMap: Map<number, MahjongTile> = new Map();
  private static displayMap: Map<number, string> = new Map();

  // 初始化麻将牌映射
  static initialize(): void {
    // 万牌 (1-9万)
    for (let i = 1; i <= 9; i++) {
      const id = i;
      MahjongRules.tileMap.set(id, { id, type: TileType.CHARACTER, value: i });
      MahjongRules.displayMap.set(id, `${i}万`);
    }

    // 条牌 (11-19条)
    for (let i = 1; i <= 9; i++) {
      const id = i + 10;
      MahjongRules.tileMap.set(id, { id, type: TileType.BAMBOO, value: i });
      MahjongRules.displayMap.set(id, `${i}条`);
    }

    // 筒牌 (21-29筒)
    for (let i = 1; i <= 9; i++) {
      const id = i + 20;
      MahjongRules.tileMap.set(id, { id, type: TileType.DOT, value: i });
      MahjongRules.displayMap.set(id, `${i}筒`);
    }

    // 字牌 (31-37: 东南西北中发白)
    const honors = ['东', '南', '西', '北', '中', '发', '白'];
    for (let i = 0; i < honors.length; i++) {
      const id = i + 31;
      MahjongRules.tileMap.set(id, { 
        id, 
        type: TileType.HONOR, 
        value: i + 1,
        honorType: i as HonorType
      });
      MahjongRules.displayMap.set(id, honors[i]);
    }

    // 花牌 (41-48)
    for (let i = 1; i <= 8; i++) {
      const id = i + 40;
      MahjongRules.tileMap.set(id, { id, type: TileType.FLOWER, value: i });
      MahjongRules.displayMap.set(id, `花${i}`);
    }
  }

  // 获取麻将牌显示文本
  static getTileDisplayText(tileId: number): string {
    return MahjongRules.displayMap.get(tileId) || '?';
  }

  // 获取麻将牌信息
  static getTileInfo(tileId: number): MahjongTile | undefined {
    return MahjongRules.tileMap.get(tileId);
  }

  // 检查是否可以胡牌
  static canWin(hand: number[], lastTile: number): boolean {
    const completeHand = [...hand, lastTile].sort((a, b) => a - b);
    
    // 七对子判断
    if (MahjongRules.isSevenPairs(completeHand)) {
      return true;
    }

    // 普通胡牌判断
    return MahjongRules.isStandardWin(completeHand);
  }

  // 七对子判断
  static isSevenPairs(hand: number[]): boolean {
    if (hand.length !== 14) return false;
    
    const tileCount = new Map<number, number>();
    hand.forEach(tile => {
      tileCount.set(tile, (tileCount.get(tile) || 0) + 1);
    });

    for (const count of tileCount.values()) {
      if (count !== 2) return false;
    }
    return true;
  }

  // 标准胡牌判断
  private static isStandardWin(hand: number[]): boolean {
    if (hand.length % 3 !== 2) return false;
    
    const tileCount = new Map<number, number>();
    hand.forEach(tile => {
      tileCount.set(tile, (tileCount.get(tile) || 0) + 1);
    });

    // 寻找将牌（对子）
    for (const tile of tileCount.keys()) {
      const count = tileCount.get(tile);
      if (count && count >= 2) {
        const remaining = [...hand];
        MahjongRules.removePair(remaining, tile);
        
        if (MahjongRules.isAllMelds(remaining)) {
          return true;
        }
      }
    }
    return false;
  }

  // 移除一对牌
  private static removePair(hand: number[], tile: number): void {
    const index1 = hand.indexOf(tile);
    const index2 = hand.indexOf(tile, index1 + 1);
    if (index1 !== -1 && index2 !== -1) {
      hand.splice(index2, 1);
      hand.splice(index1, 1);
    }
  }

  // 检查是否全部是刻子或顺子
  private static isAllMelds(hand: number[]): boolean {
    if (hand.length === 0) return true;
    
    const sortedHand = [...hand].sort((a, b) => a - b);
    
    // 检查刻子
    if (sortedHand[0] === sortedHand[2]) {
      const remaining = sortedHand.slice(3);
      if (MahjongRules.isAllMelds(remaining)) {
        return true;
      }
    }
    
    // 检查顺子
    const firstTile = sortedHand[0];
    const secondTile = firstTile + 1;
    const thirdTile = firstTile + 2;
    
    if (sortedHand.includes(secondTile) && sortedHand.includes(thirdTile)) {
      const remaining = [...sortedHand];
      MahjongRules.removeTile(remaining, firstTile);
      MahjongRules.removeTile(remaining, secondTile);
      MahjongRules.removeTile(remaining, thirdTile);
      
      if (MahjongRules.isAllMelds(remaining)) {
        return true;
      }
    }
    
    return false;
  }

  private static removeTile(hand: number[], tile: number): void {
    const index = hand.indexOf(tile);
    if (index !== -1) {
      hand.splice(index, 1);
    }
  }

  // 检查是否可以碰牌
  static canPong(hand: number[], tile: number): boolean {
    const count = hand.filter(t => t === tile).length;
    return count >= 2;
  }

  // 检查是否可以吃牌（已禁用）
  static canChow(hand: number[], tile: number): boolean {
    // 本游戏不支持吃牌
    return false;
  }

  // 检查是否可以杠牌
  static canKong(hand: number[], tile: number): boolean {
    const count = hand.filter(t => t === tile).length;
    return count >= 3;
  }

  // 获取可用的操作
  static getAvailableActions(hand: number[], lastTile: number): string[] {
    const actions: string[] = [];
    
    // 优先级：胡 > 杠 > 碰（没有吃牌）
    if (MahjongRules.canWin(hand, lastTile)) {
      actions.push('WIN');
    }
    if (MahjongRules.canKong(hand, lastTile)) {
      actions.push('KONG');
    }
    if (MahjongRules.canPong(hand, lastTile)) {
      actions.push('PONG');
    }
    
    return actions;
  }

  // 计算分数
  static calculateScore(winType: string, isSelfDrawn: boolean, fanCount: number): number {
    let baseScore = 0;
    
    switch (winType) {
      case 'PINGHU':
        baseScore = 1;
        break;
      case 'SEVEN_PAIRS':
        baseScore = 4;
        break;
      case 'PONGPONG':
        baseScore = 6;
        break;
      default:
        baseScore = 2;
    }
    
    if (isSelfDrawn) {
      baseScore *= 2;
    }
    
    return baseScore * Math.pow(2, fanCount);
  }
}

// 初始化麻将规则
MahjongRules.initialize();