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

export interface LastActionInfo {
  player: number;
  action: string;
  tile?: number;
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
  lastAction?: LastActionInfo;
  winner?: number;
  waitingForReaction: boolean;
  discarderSeat: number;
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
      wall: [],
      waitingForReaction: false,
      discarderSeat: -1
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
    
    // 万牌 (1-9)，每种4张
    for (let i = 1; i <= 9; i++) {
      for (let j = 0; j < 4; j++) {
        this.tileWall.push(i);
      }
    }
    
    // 条牌 (11-19)，每种4张
    for (let i = 11; i <= 19; i++) {
      for (let j = 0; j < 4; j++) {
        this.tileWall.push(i);
      }
    }
    
    // 筒牌 (21-29)，每种4张
    for (let i = 21; i <= 29; i++) {
      for (let j = 0; j < 4; j++) {
        this.tileWall.push(i);
      }
    }
    
    // 字牌 (31-37: 东南西北中发白)，每种4张
    for (let i = 31; i <= 37; i++) {
      for (let j = 0; j < 4; j++) {
        this.tileWall.push(i);
      }
    }
    
    // 花牌 (41-48)，每种1张（可选，根据规则）
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
      const temp = this.tileWall[i];
      this.tileWall[i] = this.tileWall[j];
      this.tileWall[j] = temp;
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

      // 记录摸牌动作，UI 层靠此判断是否需要出牌
      this.state.lastAction = {
        player: playerSeat,
        action: 'DRAW',
        tile: tile
      };

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

    if (this.state.waitingForReaction) {
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
    const discardAction: LastActionInfo = {
      player: playerSeat,
      action: 'DISCARD',
      tile: tile
    };
    this.state.lastAction = discardAction;

    // 不自动推进到下一位玩家，先等待所有人响应（碰/杠/胡）
    this.state.waitingForReaction = true;
    this.state.discarderSeat = playerSeat;

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
    const pongAction: LastActionInfo = {
      player: playerSeat,
      action: 'PONG',
      tile: discardedTile
    };
    this.state.lastAction = pongAction;
    
    // 碰牌玩家成为当前玩家（碰牌后不补牌，直接进入出牌阶段）
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
    const kongAction: LastActionInfo = {
      player: playerSeat,
      action: 'KONG',
      tile: tileToKong
    };
    this.state.lastAction = kongAction;
    
    // 杠牌后摸一张牌
    if (this.tileWall.length > 0) {
      const newTile = this.tileWall.pop()!;
      player.hand.push(newTile);
      player.hand.sort((a, b) => a - b);
      this.state.remainingTiles = this.tileWall.length;
    } else {
      // 牌墙为空，流局
      this.endGame();
    }

    // 杠牌玩家成为当前玩家
    this.state.currentPlayer = playerSeat;

    return true;
  }

  // 玩家胡牌
  win(playerSeat: number, winningTile: number): boolean {
    const player = this.getPlayer(playerSeat);
    if (!player) {
      return false;
    }

    // 判断自摸还是点炮：自摸时 hand 已包含 winningTile
    const isSelfDraw = player.hand.indexOf(winningTile) !== -1;

    let canWinResult: boolean;
    if (isSelfDraw) {
      // 自摸：hand 已含牌（14张），临时移除一张再传给 canWin 判断
      const idx = player.hand.indexOf(winningTile);
      player.hand.splice(idx, 1);
      canWinResult = MahjongRules.canWin(player.hand, winningTile);
      player.hand.push(winningTile);
      player.hand.sort((a, b) => a - b);
    } else {
      // 点炮：hand 不含牌（13张），canWin 内部追加
      canWinResult = MahjongRules.canWin(player.hand, winningTile);
    }

    if (!canWinResult) {
      return false;
    }

    // 计算分数
    const score = this.calculateWinScore(playerSeat, winningTile, isSelfDraw);
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

  // 计算胡牌分数
  private calculateWinScore(playerSeat: number, winningTile: number,
                            isSelfDraw: boolean): number {
    const player = this.getPlayer(playerSeat);
    if (!player) return 0;

    let baseScore = 1;

    // 检查七对子：需要构建完整14张手牌
    const fullHand = isSelfDraw ?
      [...player.hand] :
      [...player.hand, winningTile];
    if (MahjongRules.isSevenPairs(fullHand)) {
      baseScore = 4;
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
      wall: [],
      waitingForReaction: false,
      discarderSeat: -1
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

  // ==================== 反应系统 ====================

  // 是否在等待反应
  isWaitingForReaction(): boolean {
    return this.state.waitingForReaction;
  }

  // 获取出牌者的座位
  getDiscarderSeat(): number {
    return this.state.discarderSeat;
  }

  // 获取某个玩家对当前弃牌可用的反应动作
  getAvailableReactions(seat: number): string[] {
    if (!this.state.waitingForReaction || this.state.lastDiscardedTile === undefined) {
      return [];
    }

    const player = this.getPlayer(seat);
    if (!player) return [];

    // 不吃自己的牌
    if (seat === this.state.discarderSeat) return [];

    const tile = this.state.lastDiscardedTile;
    const actions: string[] = [];

    // 优先级：胡 > 杠 > 碰（没有吃牌）
    if (MahjongRules.canWin(player.hand, tile)) {
      actions.push('WIN');
    }
    if (MahjongRules.canKong(player.hand, tile)) {
      actions.push('KONG');
    }
    if (MahjongRules.canPong(player.hand, tile)) {
      actions.push('PONG');
    }

    return actions;
  }

  // 玩家执行反应动作
  resolveReaction(playerSeat: number, action: string): boolean {
    if (!this.state.waitingForReaction || this.state.lastDiscardedTile === undefined) {
      return false;
    }

    const player = this.getPlayer(playerSeat);
    if (!player) return false;

    const tile = this.state.lastDiscardedTile;
    let success = false;

    switch (action) {
      case 'WIN':
        success = this.win(playerSeat, tile);
        if (success) {
          this.state.waitingForReaction = false;
        }
        break;
      case 'KONG':
        success = this.kong(playerSeat, tile);
        if (success && !this.isGameEnded()) {
          this.state.waitingForReaction = false;
          this.state.currentPlayer = playerSeat;
        }
        break;
      case 'PONG':
        success = this.pong(playerSeat, tile);
        if (success && !this.isGameEnded()) {
          this.state.waitingForReaction = false;
          this.state.currentPlayer = playerSeat;
        }
        break;
      default:
        break;
    }

    return success;
  }

  // 玩家跳过反应（PASS）
  passReaction(playerSeat: number): void {
    // 仅标记，不推进——调用方需要等所有人PASS后调用advanceToNextPlayer
  }

  // 推进到下一位玩家
  advanceToNextPlayer(): void {
    if (this.state.waitingForReaction) {
      this.state.waitingForReaction = false;
      // 推进到出牌者的下家
      this.state.currentPlayer = (this.state.discarderSeat + 1) % 4;
    }
  }

  // 获取玩家分数
  getPlayerScore(seat: number): number {
    const player = this.getPlayer(seat);
    return player ? player.score : 0;
  }
}