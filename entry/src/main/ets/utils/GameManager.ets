import { MahjongRules, MahjongTile } from '../engine/MahjongRules';

// 玩家状态
export interface GamePlayer {
  seat: number;
  nickname: string;
  ready: boolean;
  online: boolean;
  score?: number;
}

// 最后动作
interface LastAction {
  player: number;
  action: string;
  tile?: number;
}

// 游戏状态
export interface GameManagerState {
  roomId: string | null;
  playerId: string | null;
  seat: number;
  players: GamePlayer[];
  myHand: number[];
  myDiscarded: number[];
  myMelds: number[][];
  currentPlayer: number;
  remainingTiles: number;
  gameStarted: boolean;
  gameEnded: boolean;
  winner?: number;
  dealer: number;
  round: number;
  lastAction?: LastAction;
}

// 游戏管理器
class GameManager {
  private state: GameManagerState = {
    roomId: null,
    playerId: null,
    seat: -1,
    players: [],
    myHand: [],
    myDiscarded: [],
    myMelds: [],
    currentPlayer: -1,
    remainingTiles: 136,
    gameStarted: false,
    gameEnded: false,
    dealer: 0,
    round: 1
  };

  private subscribers: Array<(state: GameManagerState) => void> = [];

  // 获取游戏状态
  get gameState(): GameManagerState {
    return JSON.parse(JSON.stringify(this.state));
  }

  // 订阅状态变化
  subscribe(callback: (state: GameManagerState) => void): () => void {
    this.subscribers.push(callback);
    return () => {
      const index = this.subscribers.indexOf(callback);
      if (index > -1) {
        this.subscribers.splice(index, 1);
      }
    };
  }

  // 通知订阅者
  private notifySubscribers(): void {
    const currentState = this.gameState;
    this.subscribers.forEach(callback => callback(currentState));
  }

  // 设置房间信息
  setRoomInfo(roomId: string, playerId: string, seat: number): void {
    this.state.roomId = roomId;
    this.state.playerId = playerId;
    this.state.seat = seat;
    this.notifySubscribers();
  }

  // 更新玩家列表
  updatePlayers(players: GamePlayer[]): void {
    this.state.players = players;
    this.notifySubscribers();
  }

  // 更新我的手牌
  updateMyHand(hand: number[]): void {
    const sortedHand = hand.slice().sort((a, b) => a - b);
    this.state.myHand = sortedHand;
    this.notifySubscribers();
  }

  // 添加弃牌
  addDiscardTile(tile: string): void {
    const tileNumber = parseInt(tile);
    if (!isNaN(tileNumber)) {
      this.state.myDiscarded.push(tileNumber);
      this.notifySubscribers();
    }
  }

  // 设置游戏开始
  setGameStarted(started: boolean): void {
    this.state.gameStarted = started;
    if (started) {
      this.state.gameEnded = false;
    }
    this.notifySubscribers();
  }

  // 设置游戏结束
  setGameEnded(ended: boolean, winner?: number): void {
    this.state.gameEnded = ended;
    if (ended) {
      this.state.winner = winner;
    }
    this.notifySubscribers();
  }

  // 更新当前玩家
  updateCurrentPlayer(player: number): void {
    this.state.currentPlayer = player;
    this.notifySubscribers();
  }

  // 更新剩余牌数
  updateRemainingTiles(count: number): void {
    this.state.remainingTiles = count;
    this.notifySubscribers();
  }

  // 更新回合信息
  updateRoundInfo(dealer: number, round: number): void {
    this.state.dealer = dealer;
    this.state.round = round;
    this.notifySubscribers();
  }

  // 添加牌组（吃碰杠）
  addMeld(meld: number[]): void {
    const sortedMeld = meld.slice().sort((a, b) => a - b);
    this.state.myMelds.push(sortedMeld);
    this.notifySubscribers();
  }

  // 更新玩家分数
  updatePlayerScore(seat: number, score: number): void {
    const playerIndex = this.state.players.findIndex(p => p.seat === seat);
    if (playerIndex > -1) {
      this.state.players[playerIndex].score = score;
      this.notifySubscribers();
    }
  }

  // 检查是否可以吃牌
  canChow(discardedTile: number, position: number): boolean {
    return MahjongRules.canChow(this.state.myHand, discardedTile);
  }

  // 检查是否可以碰牌
  canPong(discardedTile: number): boolean {
    return MahjongRules.canPong(this.state.myHand, discardedTile);
  }

  // 检查是否可以杠牌
  canKong(discardedTile?: number): boolean {
    if (discardedTile === undefined) {
      // 检查暗杠
      const tileCounts = new Map<number, number>();
      this.state.myHand.forEach(tile => {
        tileCounts.set(tile, (tileCounts.get(tile) || 0) + 1);
      });
      for (const count of tileCounts.values()) {
        if (count >= 4) return true;
      }
      return false;
    } else {
      return MahjongRules.canKong(this.state.myHand, discardedTile);
    }
  }

  // 检查是否可以胡牌
  canWin(winningTile: number): boolean {
    return MahjongRules.canWin(this.state.myHand, winningTile);
  }

  // 获取牌显示文本
  getTileDisplayText(tileId: number): string {
    return MahjongRules.getTileDisplayText(tileId);
  }

  // 获取牌颜色
  getTileColor(tileId: number): string {
    const tileInfo = MahjongRules.getTileInfo(tileId);
    if (!tileInfo) return '#cccccc';
    
    switch (tileInfo.type) {
      case 0: // CHARACTER
        return '#e74c3c';
      case 1: // BAMBOO
        return '#2ecc71';  
      case 2: // DOT
        return '#3498db';
      case 3: // HONOR
        return '#f39c12';
      case 4: // FLOWER
        return '#9b59b6';
      default:
        return '#cccccc';
    }
  }

  // 获取牌信息
  getTileInfo(tileId: number): MahjongTile | null {
    const tileInfo = MahjongRules.getTileInfo(tileId);
    return tileInfo ? tileInfo : null;
  }

  // 计算胡牌分数
  calculateWinScore(winType: string, isSelfDraw: boolean, fanCount: number): number {
    return MahjongRules.calculateScore(winType, isSelfDraw, fanCount);
  }

  // 重置游戏状态
  reset(): void {
    this.state = {
      roomId: null,
      playerId: null,
      seat: -1,
      players: [],
      myHand: [],
      myDiscarded: [],
      myMelds: [],
      currentPlayer: -1,
      remainingTiles: 136,
      gameStarted: false,
      gameEnded: false,
      dealer: 0,
      round: 1
    };
    this.notifySubscribers();
  }

  // 是否为我的回合
  isMyTurn(): boolean {
    return this.state.gameStarted && !this.state.gameEnded && 
           this.state.currentPlayer === this.state.seat;
  }

  // 获取当前玩家昵称
  getCurrentPlayerName(): string {
    const player = this.state.players.find(p => p.seat === this.state.currentPlayer);
    return player ? player.nickname : '未知玩家';
  }

  // 获取玩家昵称
  getPlayerName(seat: number): string {
    const player = this.state.players.find(p => p.seat === seat);
    return player ? player.nickname : `玩家${seat}`;
  }

  // 获取玩家分数
  getPlayerScore(seat: number): number {
    const player = this.state.players.find(p => p.seat === seat);
    return player?.score || 0;
  }

  // 检查游戏是否可开始
  canStartGame(): boolean {
    return this.state.players.length >= 2 && 
           this.state.players.every(p => p.ready) &&
           !this.state.gameStarted;
  }

  // 检查是否所有玩家准备
  allPlayersReady(): boolean {
    return this.state.players.length > 0 && 
           this.state.players.every(p => p.ready);
  }

  // 获取可用的动作
  getAvailableActions(lastDiscardedTile?: number): string[] {
    const actions: string[] = [];

    if (!this.state.gameStarted || this.state.gameEnded) {
      return actions;
    }

    // 如果是我的回合，可以摸牌和出牌
    if (this.isMyTurn()) {
      actions.push('DRAW');
      if (this.state.myHand.length > 0) {
        actions.push('DISCARD');
      }
    }

    // 检查吃碰杠胡
    if (lastDiscardedTile !== undefined) {
      if (this.canChow(lastDiscardedTile, 0)) {
        actions.push('CHOW');
      }
      
      if (this.canPong(lastDiscardedTile)) {
        actions.push('PONG');
      }
      
      if (this.canKong(lastDiscardedTile)) {
        actions.push('KONG');
      }
      
      if (this.canWin(lastDiscardedTile)) {
        actions.push('WIN');
      }
    }

    // 检查暗杠
    if (this.canKong()) {
      actions.push('KONG');
    }

    return actions;
  }
}

export const gameManager = new GameManager();