import { MahjongRules, MahjongTile, PlayerAction } from './MahjongRules';

// 玩家状态
export interface PlayerState {
  seat: number;
  hand: number[];           // 手牌
  melds: number[][];        // 吃碰杠的牌组
  discarded: number[];      // 弃牌
  score: number;            // 当前得分
  ready: boolean;           // 是否准备
  online: boolean;          // 是否在线
}

// 游戏状态
export interface GameState {
  roomId: string;
  players: PlayerState[];
  currentPlayer: number;    // 当前回合玩家
  deck: number[];           // 牌堆
  wall: number[];           // 牌墙
  remainingTiles: number;   // 剩余牌数
  lastAction?: {
    player: number;
    action: PlayerAction;
    tile?: number;
  };
  gameStarted: boolean;
  gameEnded: boolean;
  winner?: number;          // 获胜玩家
  dealer: number;           // 庄家
  round: number;            // 当前局数
}

// 游戏事件
export interface GameEvent {
  type: 'DRAW' | 'DISCARD' | 'CHOW' | 'PONG' | 'KONG' | 'WIN' | 'GAME_START' | 'GAME_END';
  player: number;
  data?: any;
}

// 麻将游戏引擎
export class MahjongGame {
  private state: GameState;
  private eventListeners: ((event: GameEvent) => void)[] = [];
  
  constructor(roomId: string, playerCount: number = 4) {
    this.state = {
      roomId,
      players: Array.from({ length: playerCount }, (_, seat) => ({
        seat,
        hand: [],
        melds: [],
        discarded: [],
        score: 0,
        ready: false,
        online: true
      })),
      currentPlayer: 0,
      deck: [],
      wall: [],
      remainingTiles: 136,
      gameStarted: false,
      gameEnded: false,
      dealer: 0,
      round: 1
    };
    
    this.initializeDeck();
  }
  
  // 初始化牌堆
  private initializeDeck(): void {
    this.state.deck = [];
    
    // 创建136张标准麻将牌
    for (let i = 1; i <= 136; i++) {
      this.state.deck.push(i);
    }
    
    // 洗牌
    this.shuffleDeck();
    
    // 初始化牌墙
    this.state.wall = [...this.state.deck];
    this.state.remainingTiles = this.state.wall.length;
  }
  
  // 洗牌
  private shuffleDeck(): void {
    const deck = this.state.deck;
    for (let i = deck.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [deck[i], deck[j]] = [deck[j], deck[i]];
    }
  }
  
  // 开始游戏
  startGame(): void {
    if (this.state.gameStarted) return;
    
    this.state.gameStarted = true;
    this.dealInitialHands();
    
    this.emitEvent({
      type: 'GAME_START',
      player: -1
    });
  }
  
  // 发初始手牌
  private dealInitialHands(): void {
    const playerCount = this.state.players.length;
    
    // 每人发13张牌
    for (let i = 0; i < playerCount; i++) {
      for (let j = 0; j < 13; j++) {
        if (this.state.wall.length > 0) {
          const tile = this.state.wall.shift()!;
          this.state.players[i].hand.push(tile);
        }
      }
      // 排序手牌
      this.state.players[i].hand.sort((a, b) => a - b);
    }
    
    this.state.remainingTiles = this.state.wall.length;
  }
  
  // 玩家摸牌
  drawTile(player: number): number | null {
    if (player !== this.state.currentPlayer || !this.state.gameStarted || this.state.gameEnded) {
      return null;
    }
    
    if (this.state.wall.length === 0) {
      this.endGame(); // 流局
      return null;
    }
    
    const tile = this.state.wall.shift()!;
    this.state.players[player].hand.push(tile);
    this.state.remainingTiles = this.state.wall.length;
    
    this.emitEvent({
      type: 'DRAW',
      player,
      data: { tile }
    });
    
    return tile;
  }
  
  // 玩家出牌
  discardTile(player: number, tile: number): boolean {
    if (player !== this.state.currentPlayer || !this.state.gameStarted || this.state.gameEnded) {
      return false;
    }
    
    const playerState = this.state.players[player];
    const tileIndex = playerState.hand.indexOf(tile);
    
    if (tileIndex === -1) {
      return false;
    }
    
    // 移除手牌
    playerState.hand.splice(tileIndex, 1);
    playerState.discarded.push(tile);
    
    this.state.lastAction = {
      player,
      action: PlayerAction.DISCARD,
      tile
    };
    
    // 切换到下一位玩家
    this.state.currentPlayer = (player + 1) % this.state.players.length;
    
    this.emitEvent({
      type: 'DISCARD',
      player,
      data: { tile }
    });
    
    return true;
  }
  
  // 玩家吃牌
  chow(player: number, tiles: number[]): boolean {
    if (!this.state.lastAction || this.state.lastAction.action !== PlayerAction.DISCARD) {
      return false;
    }
    
    const discardedTile = this.state.lastAction.tile!;
    const playerState = this.state.players[player];
    
    // 验证吃牌合法性
    if (!MahjongRules.canChow(playerState.hand, discardedTile, 0)) {
      return false;
    }
    
    // 创建吃牌组合
    const chowMeld = [...tiles, discardedTile].sort((a, b) => a - b);
    
    // 从手牌移除吃牌
    tiles.forEach(tile => {
      const index = playerState.hand.indexOf(tile);
      if (index !== -1) {
        playerState.hand.splice(index, 1);
      }
    });
    
    playerState.melds.push(chowMeld);
    
    this.state.lastAction = {
      player,
      action: PlayerAction.CHOW,
      tile: discardedTile
    };
    
    this.state.currentPlayer = player;
    
    this.emitEvent({
      type: 'CHOW',
      player,
      data: { tiles: chowMeld }
    });
    
    return true;
  }
  
  // 玩家碰牌
  pong(player: number): boolean {
    if (!this.state.lastAction || this.state.lastAction.action !== PlayerAction.DISCARD) {
      return false;
    }
    
    const discardedTile = this.state.lastAction.tile!;
    const playerState = this.state.players[player];
    
    // 验证碰牌合法性
    if (!MahjongRules.canPong(playerState.hand, discardedTile)) {
      return false;
    }
    
    // 从手牌移除两张相同的牌
    const sameTiles = playerState.hand.filter(t => {
      const tileInfo1 = MahjongRules.getTileInfo(t);
      const tileInfo2 = MahjongRules.getTileInfo(discardedTile);
      return tileInfo1 && tileInfo2 && 
             tileInfo1.type === tileInfo2.type && 
             tileInfo1.value === tileInfo2.value;
    }).slice(0, 2);
    
    sameTiles.forEach(tile => {
      const index = playerState.hand.indexOf(tile);
      if (index !== -1) {
        playerState.hand.splice(index, 1);
      }
    });
    
    // 创建碰牌组合
    const pongMeld = [...sameTiles, discardedTile].sort((a, b) => a - b);
    playerState.melds.push(pongMeld);
    
    this.state.lastAction = {
      player,
      action: PlayerAction.PONG,
      tile: discardedTile
    };
    
    this.state.currentPlayer = player;
    
    this.emitEvent({
      type: 'PONG',
      player,
      data: { tiles: pongMeld }
    });
    
    return true;
  }
  
  // 玩家杠牌
  kong(player: number, tile?: number): boolean {
    const playerState = this.state.players[player];
    let kongTiles: number[] = [];
    
    if (tile) {
      // 明杠：杠别人打出的牌
      if (!this.state.lastAction || this.state.lastAction.action !== PlayerAction.DISCARD) {
        return false;
      }
      
      const discardedTile = this.state.lastAction.tile!;
      
      // 验证杠牌合法性
      if (!MahjongRules.canKong(playerState.hand, discardedTile)) {
        return false;
      }
      
      // 从手牌移除三张相同的牌
      const sameTiles = playerState.hand.filter(t => {
        const tileInfo1 = MahjongRules.getTileInfo(t);
        const tileInfo2 = MahjongRules.getTileInfo(discardedTile);
        return tileInfo1 && tileInfo2 && 
               tileInfo1.type === tileInfo2.type && 
               tileInfo1.value === tileInfo2.value;
      }).slice(0, 3);
      
      sameTiles.forEach(tile => {
        const index = playerState.hand.indexOf(tile);
        if (index !== -1) {
          playerState.hand.splice(index, 1);
        }
      });
      
      kongTiles = [...sameTiles, discardedTile];
      
      this.state.lastAction = {
        player,
        action: PlayerAction.KONG,
        tile: discardedTile
      };
      
    } else {
      // 暗杠：杠自己手牌
      if (!MahjongRules.canKong(playerState.hand)) {
        return false;
      }
      
      // 找到四张相同的牌
      const tileCounts: {[key: string]: number[]} = {};
      playerState.hand.forEach(t => {
        const tileInfo = MahjongRules.getTileInfo(t);
        if (tileInfo && !tileInfo.isFlower) {
          const key = `${tileInfo.type}-${tileInfo.value}`;
          if (!tileCounts[key]) {
            tileCounts[key] = [];
          }
          tileCounts[key].push(t);
        }
      });
      
      for (const key in tileCounts) {
        if (tileCounts[key].length === 4) {
          kongTiles = tileCounts[key];
          break;
        }
      }
      
      // 从手牌移除四张牌
      kongTiles.forEach(tile => {
        const index = playerState.hand.indexOf(tile);
        if (index !== -1) {
          playerState.hand.splice(index, 1);
        }
      });
      
      this.state.lastAction = {
        player,
        action: PlayerAction.KONG
      };
    }
    
    kongTiles.sort((a, b) => a - b);
    playerState.melds.push(kongTiles);
    
    this.state.currentPlayer = player;
    
    this.emitEvent({
      type: 'KONG',
      player,
      data: { tiles: kongTiles }
    });
    
    return true;
  }
  
  // 玩家胡牌
  win(player: number, winningTile: number, isSelfDraw: boolean = false): boolean {
    const playerState = this.state.players[player];
    
    // 验证胡牌合法性
    if (!MahjongRules.canWin(playerState.hand, winningTile)) {
      return false;
    }
    
    // 计算得分
    const score = MahjongRules.calculateScore(playerState.hand, winningTile, isSelfDraw);
    playerState.score += score;
    
    this.state.winner = player;
    this.state.gameEnded = true;
    
    this.emitEvent({
      type: 'WIN',
      player,
      data: { 
        score,
        isSelfDraw,
        winningTile 
      }
    });
    
    this.endGame();
    
    return true;
  }
  
  // 结束游戏
  private endGame(): void {
    this.state.gameEnded = true;
    
    this.emitEvent({
      type: 'GAME_END',
      player: -1,
      data: { winner: this.state.winner }
    });
  }
  
  // 获取游戏状态
  getGameState(): GameState {
    return JSON.parse(JSON.stringify(this.state));
  }
  
  // 获取玩家状态
  getPlayerState(player: number): PlayerState | null {
    return this.state.players[player] ? 
           JSON.parse(JSON.stringify(this.state.players[player])) : null;
  }
  
  // 获取当前可用的动作
  getAvailableActions(player: number): PlayerAction[] {
    const actions: PlayerAction[] = [];
    
    if (!this.state.gameStarted || this.state.gameEnded) {
      return actions;
    }
    
    const playerState = this.state.players[player];
    
    // 如果是当前玩家回合，可以摸牌和出牌
    if (player === this.state.currentPlayer) {
      actions.push(PlayerAction.DRAW);
      if (playerState.hand.length > 0) {
        actions.push(PlayerAction.DISCARD);
      }
    }
    
    // 检查是否可以吃碰杠胡
    if (this.state.lastAction && this.state.lastAction.action === PlayerAction.DISCARD) {
      const discardedTile = this.state.lastAction.tile!;
      
      if (MahjongRules.canChow(playerState.hand, discardedTile, 0)) {
        actions.push(PlayerAction.CHOW);
      }
      
      if (MahjongRules.canPong(playerState.hand, discardedTile)) {
        actions.push(PlayerAction.PONG);
      }
      
      if (MahjongRules.canKong(playerState.hand, discardedTile)) {
        actions.push(PlayerAction.KONG);
      }
      
      if (MahjongRules.canWin(playerState.hand, discardedTile)) {
        actions.push(PlayerAction.WIN);
      }
    }
    
    // 检查是否可以暗杠
    if (MahjongRules.canKong(playerState.hand)) {
      actions.push(PlayerAction.KONG);
    }
    
    return actions;
  }
  
  // 事件监听
  onEvent(listener: (event: GameEvent) => void): void {
    this.eventListeners.push(listener);
  }
  
  // 移除事件监听
  offEvent(listener: (event: GameEvent) => void): void {
    const index = this.eventListeners.indexOf(listener);
    if (index > -1) {
      this.eventListeners.splice(index, 1);
    }
  }
  
  // 触发事件
  private emitEvent(event: GameEvent): void {
    this.eventListeners.forEach(listener => listener(event));
  }
  
  // 重置游戏
  reset(): void {
    this.state.gameStarted = false;
    this.state.gameEnded = false;
    this.state.winner = undefined;
    this.state.lastAction = undefined;
    
    // 重置玩家状态
    this.state.players.forEach(player => {
      player.hand = [];
      player.melds = [];
      player.discarded = [];
    });
    
    // 重新初始化牌堆
    this.initializeDeck();
  }
}