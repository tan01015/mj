// 麻将游戏引擎
// 包含游戏状态管理、回合控制、牌局逻辑

import { MahjongRules, MahjongTile } from './MahjongRules';

export enum GamePhase {
  WAITING,      // 等待开始
  DEALING,      // 发牌阶段
  PLAYING,      // 游戏进行中
  ENDED         // 游戏结束
}

export interface GamePlayer {
  seat: number;
  nickname: string;
  hand: number[];
  discarded: number[];
  melds: number[][];
  score: number;
  ready: boolean;
  online: boolean;
}

export interface GameState {
  phase: GamePhase;
  players: GamePlayer[];
  currentPlayer: number;
  dealer: number;
  round: number;
  remainingTiles: number;
  wall: number[];
  lastDiscardedTile?: number;
  lastAction?: {
    player: number;
    action: string;
    tile?: number;
  };
  winner?: number;
}

export class MahjongGame {
  private state: GameState;
  private tileWall: number[] = [];

  constructor() {
    this.state = {
      phase: GamePhase.WAITING,
      players: [],
      currentPlayer: 0,
      dealer: 0,
      round: 1,
      remainingTiles: 136,
      wall: []
    };
  }

  // 初始化游戏
  initializeGame(players: GamePlayer[]): void {
    this.state.players = players;
    this.state.phase = GamePhase.DEALING;
    this.initializeTileWall();
    this.dealInitialTiles();
    this.state.phase = GamePhase.PLAYING;
    this.state.currentPlayer = this.state.dealer;
  }

  // 初始化牌墙
  private initializeTileWall(): void {
    this.tileWall = [];
    
    // 创建麻将牌 (1-37, 41-48)
    for (let i = 1; i <= 37; i++) {
      if (i <= 29 || (i >= 31 && i <= 37)) {
        // 添加4张相同的牌
        for (let j = 0; j < 4; j++) {
          this.tileWall.push(i);
        }
      }
    }
    
    // 添加花牌 (41-48)
    for (let i = 41; i <= 48; i++) {
      this.tileWall.push(i);
    }
    
    // 洗牌
    this.shuffleTiles();
    this.state.wall = [...this.tileWall];
    this.state.remainingTiles = this.tileWall.length;
  }

  // 洗牌
  private shuffleTiles(): void {
    for (let i = this.tileWall.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [this.tileWall[i], this.tileWall[j]] = [this.tileWall[j], this.tileWall[i]];
    }
  }

  // 发初始牌
  private dealInitialTiles(): void {
    const players = this.state.players;
    const tilesPerPlayer = 13;
    
    players.forEach(player => {
      player.hand = [];
      for (let i = 0; i < tilesPerPlayer; i++) {
        if (this.tileWall.length > 0) {
          const tile = this.tileWall.pop()!;
          player.hand.push(tile);
        }
      }
      player.hand.sort((a, b) => a - b);
    });
    
    this.state.remainingTiles = this.tileWall.length;
  }

  // 玩家摸牌
  drawTile(playerSeat: number): number | null {
    if (this.state.currentPlayer !== playerSeat) {
      return null;
    }
    
    if (this.tileWall.length === 0) {
      this.endGame(); // 流局
      return null;
    }
    
    const tile = this.tileWall.pop()!;
    const player = this.getPlayer(playerSeat);
    if (player) {
      player.hand.push(tile);
      player.hand.sort((a, b) => a - b);
      this.state.remainingTiles = this.tileWall.length;
      return tile;
    }
    
    return null;
  }

  // 玩家出牌
  discardTile(playerSeat: number, tile: number): boolean {
    const player = this.getPlayer(playerSeat);
    if (!player || this.state.currentPlayer !== playerSeat) {
      return false;
    }
    
    const tileIndex = player.hand.indexOf(tile);
    if (tileIndex === -1) {
      return false;
    }
    
    player.hand.splice(tileIndex, 1);
    player.discarded.push(tile);
    this.state.lastDiscardedTile = tile;
    
    // 记录最后动作
    this.state.lastAction = {
      player: playerSeat,
      action: 'DISCARD',
      tile: tile
    };
    
    // 轮到下一位玩家
    this.nextPlayer();
    
    return true;
  }

  // 玩家吃牌
  chow(playerSeat: number, discardedTile: number, position: number): boolean {
    const player = this.getPlayer(playerSeat);
    if (!player || !this.state.lastDiscardedTile) {
      return false;
    }
    
    // 检查是否可以吃牌
    if (!MahjongRules.canChow(player.hand, discardedTile)) {
      return false;
    }
    
    // 创建顺子
    const chowTiles = this.getChowTiles(player.hand, discardedTile, position);
    if (!chowTiles) {
      return false;
    }
    
    // 从手牌移除顺子牌
    chowTiles.forEach(tile => {
      const index = player.hand.indexOf(tile);
      if (index !== -1) {
        player.hand.splice(index, 1);
      }
    });
    
    // 添加牌组
    player.melds.push(chowTiles);
    
    // 记录动作
    this.state.lastAction = {
      player: playerSeat,
      action: 'CHOW',
      tile: discardedTile
    };
    
    // 吃牌玩家成为当前玩家
    this.state.currentPlayer = playerSeat;
    
    return true;
  }

  // 玩家碰牌
  pong(playerSeat: number, discardedTile: number): boolean {
    const player = this.getPlayer(playerSeat);
    if (!player || !this.state.lastDiscardedTile) {
      return false;
    }
    
    if (!MahjongRules.canPong(player.hand, discardedTile)) {
      return false;
    }
    
    // 移除两张相同的牌
    let count = 0;
    player.hand = player.hand.filter(tile => {
      if (tile === discardedTile && count < 2) {
        count++;
        return false;
      }
      return true;
    });
    
    // 添加碰牌牌组
    player.melds.push([discardedTile, discardedTile, discardedTile]);
    
    // 记录动作
    this.state.lastAction = {
      player: playerSeat,
      action: 'PONG',
      tile: discardedTile
    };
    
    // 碰牌玩家成为当前玩家
    this.state.currentPlayer = playerSeat;
    
    return true;
  }

  // 玩家杠牌
  kong(playerSeat: number, tile?: number): boolean {
    const player = this.getPlayer(playerSeat);
    if (!player) {
      return false;
    }
    
    const tileToKong = tile || this.state.lastDiscardedTile;
    if (!tileToKong) {
      return false;
    }
    
    if (!MahjongRules.canKong(player.hand, tileToKong)) {
      return false;
    }
    
    // 移除三张相同的牌
    let count = 0;
    player.hand = player.hand.filter(t => {
      if (t === tileToKong && count < 3) {
        count++;
        return false;
      }
      return true;
    });
    
    // 添加杠牌牌组
    player.melds.push([tileToKong, tileToKong, tileToKong, tileToKong]);
    
    // 记录动作
    this.state.lastAction = {
      player: playerSeat,
      action: 'KONG',
      tile: tileToKong
    };
    
    // 杠牌后摸一张牌
    if (this.tileWall.length > 0) {
      const newTile = this.tileWall.pop()!;
      player.hand.push(newTile);
      player.hand.sort((a, b) => a - b);
      this.state.remainingTiles = this.tileWall.length;
    }
    
    return true;
  }

  // 玩家胡牌
  win(playerSeat: number, winningTile: number): boolean {
    const player = this.getPlayer(playerSeat);
    if (!player) {
      return false;
    }
    
    // 检查是否可以胡牌
    if (!MahjongRules.canWin(player.hand, winningTile)) {
      return false;
    }
    
    // 计算分数
    const score = this.calculateWinScore(playerSeat, winningTile);
    player.score += score;
    
    // 设置赢家
    this.state.winner = playerSeat;
    this.endGame();
    
    // 记录动作
    this.state.lastAction = {
      player: playerSeat,
      action: 'WIN',
      tile: winningTile
    };
    
    return true;
  }

  // 获取吃牌的三张牌
  private getChowTiles(hand: number[], discardedTile: number, position: number): number[] | null {
    const tileInfo = MahjongRules.getTileInfo(discardedTile);
    if (!tileInfo || tileInfo.type === 3) { // HONOR
      return null;
    }
    
    const possibleCombinations = [
      [discardedTile - 2, discardedTile - 1, discardedTile],
      [discardedTile - 1, discardedTile, discardedTile + 1],
      [discardedTile, discardedTile + 1, discardedTile + 2]
    ];
    
    if (position < 0 || position >= possibleCombinations.length) {
      return null;
    }
    
    const combo = possibleCombinations[position];
    if (combo.every(t => hand.includes(t))) {
      return combo;
    }
    
    return null;
  }

  // 计算胡牌分数
  private calculateWinScore(playerSeat: number, winningTile: number): number {
    const player = this.getPlayer(playerSeat);
    if (!player) return 0;
    
    // 简化计分逻辑
    let baseScore = 1;
    const isSelfDraw = winningTile !== this.state.lastDiscardedTile;
    
    // 检查特殊牌型
    if (MahjongRules.isSevenPairs([...player.hand, winningTile])) {
      baseScore = 4; // 七对子
    }
    
    if (isSelfDraw) {
      baseScore *= 2; // 自摸加倍
    }
    
    return baseScore;
  }

  // 轮到下一位玩家
  private nextPlayer(): void {
    this.state.currentPlayer = (this.state.currentPlayer + 1) % 4;
  }

  // 结束游戏
  private endGame(): void {
    this.state.phase = GamePhase.ENDED;
  }

  // 获取玩家
  private getPlayer(seat: number): GamePlayer | undefined {
    return this.state.players.find(p => p.seat === seat);
  }

  // 获取游戏状态
  getState(): GameState {
    return JSON.parse(JSON.stringify(this.state));
  }

  // 重置游戏
  reset(): void {
    this.state = {
      phase: GamePhase.WAITING,
      players: [],
      currentPlayer: 0,
      dealer: 0,
      round: 1,
      remainingTiles: 136,
      wall: []
    };
    this.tileWall = [];
  }

  // 检查是否游戏结束
  isGameEnded(): boolean {
    return this.state.phase === GamePhase.ENDED;
  }

  // 获取当前玩家
  getCurrentPlayer(): number {
    return this.state.currentPlayer;
  }

  // 获取玩家手牌
  getPlayerHand(seat: number): number[] {
    const player = this.getPlayer(seat);
    return player ? [...player.hand] : [];
  }

  // 获取玩家弃牌
  getPlayerDiscarded(seat: number): number[] {
    const player = this.getPlayer(seat);
    return player ? [...player.discarded] : [];
  }

  // 获取玩家牌组
  getPlayerMelds(seat: number): number[][] {
    const player = this.getPlayer(seat);
    return player ? [...player.melds] : [];
  }

  // 获取玩家分数
  getPlayerScore(seat: number): number {
    const player = this.getPlayer(seat);
    return player ? player.score : 0;
  }
}