// 麻将牌类型定义
export enum TileType {
  CHARACTERS = 'characters',    // 万
  BAMBOO = 'bamboo',           // 条
  DOTS = 'dots',               // 筒
  HONORS = 'honors',           // 字牌
  FLOWERS = 'flowers'          // 花牌
}

// 麻将牌结构
export interface MahjongTile {
  id: number;           // 唯一ID (1-136)
  type: TileType;       // 牌类型
  value: number;        // 牌面值
  isRedDragon?: boolean; // 是否红中
  isFlower?: boolean;    // 是否花牌
}

// 玩家动作类型
export enum PlayerAction {
  DRAW = 'draw',        // 摸牌
  DISCARD = 'discard',  // 出牌
  CHOW = 'chow',        // 吃
  PONG = 'pong',        // 碰
  KONG = 'kong',        // 杠
  WIN = 'win',          // 胡牌
  PASS = 'pass'         // 过
}

// 麻将规则引擎
export class MahjongRules {
  private static readonly TOTAL_TILES = 136;
  private static readonly INITIAL_HAND_SIZE = 13;
  
  // 麻将牌映射表
  private static readonly TILE_MAP: {[key: number]: MahjongTile} = {};
  
  static {
    // 初始化麻将牌映射
    this.initializeTileMap();
  }
  
  private static initializeTileMap(): void {
    let tileId = 1;
    
    // 万子 (1-9万, 各4张)
    for (let value = 1; value <= 9; value++) {
      for (let i = 0; i < 4; i++) {
        this.TILE_MAP[tileId] = { id: tileId, type: TileType.CHARACTERS, value };
        tileId++;
      }
    }
    
    // 条子 (1-9条, 各4张)
    for (let value = 1; value <= 9; value++) {
      for (let i = 0; i < 4; i++) {
        this.TILE_MAP[tileId] = { id: tileId, type: TileType.BAMBOO, value };
        tileId++;
      }
    }
    
    // 筒子 (1-9筒, 各4张)
    for (let value = 1; value <= 9; value++) {
      for (let i = 0; i < 4; i++) {
        this.TILE_MAP[tileId] = { id: tileId, type: TileType.DOTS, value };
        tileId++;
      }
    }
    
    // 字牌 (东南西北中发白, 各4张)
    const honors = ['东', '南', '西', '北', '中', '发', '白'];
    for (let value = 1; value <= honors.length; value++) {
      for (let i = 0; i < 4; i++) {
        const isRedDragon = value === 5; // 中为红中
        this.TILE_MAP[tileId] = { 
          id: tileId, 
          type: TileType.HONORS, 
          value,
          isRedDragon 
        };
        tileId++;
      }
    }
    
    // 花牌 (春夏秋冬梅兰竹菊, 各1张)
    const flowers = ['春', '夏', '秋', '冬', '梅', '兰', '竹', '菊'];
    for (let value = 1; value <= flowers.length; value++) {
      this.TILE_MAP[tileId] = { 
        id: tileId, 
        type: TileType.FLOWERS, 
        value,
        isFlower: true 
      };
      tileId++;
    }
  }
  
  // 获取牌信息
  static getTileInfo(tileId: number): MahjongTile | null {
    return this.TILE_MAP[tileId] || null;
  }
  
  // 检查是否可以吃牌
  static canChow(hand: number[], discardedTile: number, position: number): boolean {
    const tileInfo = this.getTileInfo(discardedTile);
    if (!tileInfo || tileInfo.type === TileType.HONORS || tileInfo.isFlower) {
      return false; // 字牌和花牌不能吃
    }
    
    const sameTypeTiles = hand.filter(t => {
      const tInfo = this.getTileInfo(t);
      return tInfo && tInfo.type === tileInfo.type && !tInfo.isFlower;
    }).map(t => this.getTileInfo(t)!.value).sort((a, b) => a - b);
    
    const discardedValue = tileInfo.value;
    
    // 检查是否可以组成顺子
    switch (position) {
      case 0: // 吃左边两张
        return sameTypeTiles.includes(discardedValue - 2) && 
               sameTypeTiles.includes(discardedValue - 1);
      case 1: // 吃中间两张
        return sameTypeTiles.includes(discardedValue - 1) && 
               sameTypeTiles.includes(discardedValue + 1);
      case 2: // 吃右边两张
        return sameTypeTiles.includes(discardedValue + 1) && 
               sameTypeTiles.includes(discardedValue + 2);
      default:
        return false;
    }
  }
  
  // 检查是否可以碰牌
  static canPong(hand: number[], discardedTile: number): boolean {
    const tileInfo = this.getTileInfo(discardedTile);
    if (!tileInfo) return false;
    
    const sameTiles = hand.filter(t => {
      const tInfo = this.getTileInfo(t);
      return tInfo && tInfo.type === tileInfo.type && tInfo.value === tileInfo.value;
    });
    
    return sameTiles.length >= 2; // 手牌中有至少两张相同的牌
  }
  
  // 检查是否可以杠牌
  static canKong(hand: number[], discardedTile: number | null = null): boolean {
    if (discardedTile) {
      // 明杠：碰别人打出的牌
      const tileInfo = this.getTileInfo(discardedTile);
      if (!tileInfo) return false;
      
      const sameTiles = hand.filter(t => {
        const tInfo = this.getTileInfo(t);
        return tInfo && tInfo.type === tileInfo.type && tInfo.value === tileInfo.value;
      });
      
      return sameTiles.length >= 3; // 手牌中有三张相同的牌
    } else {
      // 暗杠：自己摸到四张相同的牌
      const tileCounts: {[key: string]: number} = {};
      
      hand.forEach(tile => {
        const tileInfo = this.getTileInfo(tile);
        if (tileInfo && !tileInfo.isFlower) {
          const key = `${tileInfo.type}-${tileInfo.value}`;
          tileCounts[key] = (tileCounts[key] || 0) + 1;
        }
      });
      
      return Object.values(tileCounts).some(count => count === 4);
    }
  }
  
  // 检查是否可以胡牌（基础胡牌算法）
  static canWin(hand: number[], lastTile: number): boolean {
    const allTiles = [...hand, lastTile];
    
    // 七对子胡牌
    if (this.isSevenPairs(allTiles)) {
      return true;
    }
    
    // 普通胡牌（3n+2模式）
    return this.isStandardWin(allTiles);
  }
  
  // 检查是否为七对子
  private static isSevenPairs(tiles: number[]): boolean {
    if (tiles.length !== 14) return false;
    
    const tileCounts: {[key: string]: number} = {};
    
    tiles.forEach(tile => {
      const tileInfo = this.getTileInfo(tile);
      if (tileInfo && !tileInfo.isFlower) {
        const key = `${tileInfo.type}-${tileInfo.value}`;
        tileCounts[key] = (tileCounts[key] || 0) + 1;
      }
    });
    
    const counts = Object.values(tileCounts);
    return counts.length === 7 && counts.every(count => count === 2);
  }
  
  // 检查标准胡牌（3n+2模式）
  private static isStandardWin(tiles: number[]): boolean {
    if (tiles.length !== 14) return false;
    
    // 按类型分组
    const tilesByType: {[key: string]: number[]} = {};
    tiles.forEach(tile => {
      const tileInfo = this.getTileInfo(tile);
      if (tileInfo && !tileInfo.isFlower) {
        if (!tilesByType[tileInfo.type]) {
          tilesByType[tileInfo.type] = [];
        }
        tilesByType[tileInfo.type].push(tileInfo.value);
      }
    });
    
    // 对每个类型的牌进行胡牌检查
    for (const type in tilesByType) {
      const typeTiles = tilesByType[type].sort((a, b) => a - b);
      
      // 检查是否可以组成3n+2模式
      if (this.canFormWinPattern(typeTiles)) {
        return true;
      }
    }
    
    return false;
  }
  
  // 检查是否可以组成胡牌模式
  private static canFormWinPattern(tiles: number[]): boolean {
    if (tiles.length === 0) return true;
    
    // 尝试找将牌（对子）
    for (let i = 0; i < tiles.length - 1; i++) {
      if (tiles[i] === tiles[i + 1]) {
        // 移除将牌
        const remaining = [...tiles];
        remaining.splice(i, 2);
        
        // 检查剩下的牌是否可以组成顺子或刻子
        if (this.canFormMelds(remaining)) {
          return true;
        }
      }
    }
    
    return false;
  }
  
  // 检查是否可以组成顺子或刻子
  private static canFormMelds(tiles: number[]): boolean {
    if (tiles.length === 0) return true;
    
    const sorted = [...tiles].sort((a, b) => a - b);
    
    // 检查刻子（三张相同的牌）
    if (sorted.length >= 3 && sorted[0] === sorted[1] && sorted[1] === sorted[2]) {
      return this.canFormMelds(sorted.slice(3));
    }
    
    // 检查顺子（三张连续的牌）
    if (sorted.length >= 3) {
      const first = sorted[0];
      if (sorted.includes(first + 1) && sorted.includes(first + 2)) {
        const remaining = [...sorted];
        const index1 = remaining.indexOf(first + 1);
        const index2 = remaining.indexOf(first + 2);
        
        remaining.splice(remaining.indexOf(first), 1);
        remaining.splice(index1 > index2 ? index1 - 1 : index1, 1);
        remaining.splice(index2 > index1 ? index2 - 2 : index2 - 1, 1);
        
        return this.canFormMelds(remaining);
      }
    }
    
    return false;
  }
  
  // 计算胡牌番数
  static calculateScore(hand: number[], winningTile: number, isSelfDraw: boolean): number {
    let score = 1; // 基础番数
    
    const allTiles = [...hand, winningTile];
    
    // 七对子
    if (this.isSevenPairs(allTiles)) {
      score += 4;
    }
    
    // 清一色（检查是否只有一种花色）
    const tileTypes = new Set();
    allTiles.forEach(tile => {
      const tileInfo = this.getTileInfo(tile);
      if (tileInfo && !tileInfo.isFlower) {
        tileTypes.add(tileInfo.type);
      }
    });
    
    if (tileTypes.size === 1) {
      score += 3;
    }
    
    // 碰碰胡（检查是否全是刻子）
    if (this.isAllPongs(allTiles)) {
      score += 2;
    }
    
    // 自摸
    if (isSelfDraw) {
      score += 1;
    }
    
    return score;
  }
  
  // 检查是否全是刻子
  private static isAllPongs(tiles: number[]): boolean {
    const tileCounts: {[key: string]: number} = {};
    
    tiles.forEach(tile => {
      const tileInfo = this.getTileInfo(tile);
      if (tileInfo && !tileInfo.isFlower) {
        const key = `${tileInfo.type}-${tileInfo.value}`;
        tileCounts[key] = (tileCounts[key] || 0) + 1;
      }
    });
    
    const counts = Object.values(tileCounts);
    return counts.every(count => count === 3 || count === 4);
  }
  
  // 获取牌显示文本
  static getTileDisplayText(tileId: number): string {
    const tileInfo = this.getTileInfo(tileId);
    if (!tileInfo) return '?';
    
    if (tileInfo.isFlower) {
      const flowers = ['🌺', '🌼', '🌸', '🌹', '🌷', '💮', '🏵️', '🌻'];
      return flowers[tileInfo.value - 1] || '🌺';
    }
    
    if (tileInfo.isRedDragon) {
      return '🀄';
    }
    
    switch (tileInfo.type) {
      case TileType.CHARACTERS:
        return `${tileInfo.value}万`;
      case TileType.BAMBOO:
        return `${tileInfo.value}条`;
      case TileType.DOTS:
        return `${tileInfo.value}筒`;
      case TileType.HONORS:
        const honors = ['东', '南', '西', '北', '中', '发', '白'];
        return honors[tileInfo.value - 1] || '?';
      default:
        return '?';
    }
  }
  
  // 获取牌显示颜色
  static getTileColor(tileId: number): string {
    const tileInfo = this.getTileInfo(tileId);
    if (!tileInfo) return '#333';
    
    if (tileInfo.isRedDragon) {
      return '#ff0000';
    }
    
    switch (tileInfo.type) {
      case TileType.CHARACTERS:
        return '#c62828';
      case TileType.BAMBOO:
        return '#2e7d32';
      case TileType.DOTS:
        return '#1565c0';
      case TileType.HONORS:
        return '#ff9800';
      case TileType.FLOWERS:
        return '#9c27b0';
      default:
        return '#333';
    }
  }
}