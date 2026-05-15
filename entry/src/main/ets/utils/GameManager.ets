import { MahjongRules, MahjongTile } from '../engine/MahjongRules';
import { MahjongGame, GameState as LocalGameState, GamePlayer as EngineGamePlayer, GamePhase } from '../engine/MahjongGame';
import { MessageData } from './NetworkManager';

export interface AIDecisionResult {
  action: 'DISCARD' | 'PONG' | 'CHOW' | 'KONG' | 'WIN' | 'PASS';
  tile?: number;
  targetTile?: number;
  confidence: number;
}

// 玩家状态
export interface GamePlayer {
  seat: number;
  nickname: string;
  ready: boolean;
  online: boolean;
  score?: number;
  playerId?: string;
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
  isSinglePlayer: boolean;
  isSinglePlayerServer: boolean;
  allHands: Map<number, number[]>;
  allMelds: Map<number, number[][]>;
  allDiscarded: Map<number, number[]>;
  gameId: string | null;
  handVersion: number;
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
    round: 1,
    isSinglePlayer: false,
    isSinglePlayerServer: false,
    allHands: new Map(),
    allMelds: new Map(),
    allDiscarded: new Map(),
    gameId: null,
    handVersion: 0
  };

  private subscribers: Array<(state: GameManagerState) => void> = [];
  private localGame: MahjongGame | null = null;
  private aiHands: Map<number, number[]> = new Map();
  private aiMelds: Map<number, number[][]> = new Map();
  private aiDiscarded: Map<number, number[]> = new Map();
  // 多人模式对手手牌数量追踪
  private multiplayerHandCounts: Map<number, number> = new Map();
  private multiplayerDiscards: Map<number, number[]> = new Map();

  // 获取游戏状态
  get gameState(): GameManagerState {
    // 不使用 JSON.stringify — Map 无法被 JSON 序列化
    return {
      roomId: this.state.roomId,
      playerId: this.state.playerId,
      seat: this.state.seat,
      players: this.state.players.map((p: GamePlayer): GamePlayer => ({
        seat: p.seat,
        nickname: p.nickname,
        ready: p.ready,
        online: p.online,
        score: p.score,
        playerId: p.playerId
      })),
      myHand: [...this.state.myHand],
      myDiscarded: [...this.state.myDiscarded],
      myMelds: this.state.myMelds.map(m => [...m]),
      currentPlayer: this.state.currentPlayer,
      remainingTiles: this.state.remainingTiles,
      gameStarted: this.state.gameStarted,
      gameEnded: this.state.gameEnded,
      winner: this.state.winner,
      dealer: this.state.dealer,
      round: this.state.round,
      lastAction: this.state.lastAction ? {
        player: this.state.lastAction.player,
        action: this.state.lastAction.action,
        tile: this.state.lastAction.tile
      } : undefined,
      isSinglePlayer: this.state.isSinglePlayer,
      isSinglePlayerServer: this.state.isSinglePlayerServer,
      allHands: new Map(this.state.allHands),
      allMelds: new Map(this.state.allMelds),
      allDiscarded: new Map(this.state.allDiscarded),
      gameId: this.state.gameId,
      handVersion: this.state.handVersion
    };
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
    // 不排序，保持原始顺序（新摸的牌在末尾）
    this.state.myHand = [...hand];
    this.state.handVersion++;
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

  // 检查是否可以吃牌（已禁用）
  canChow(discardedTile: number, position: number): boolean {
    // 本游戏不支持吃牌
    return false;
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

  // ==================== 单机模式 ====================

  // 设置单机模式
  setSinglePlayerMode(enabled: boolean): void {
    this.state.isSinglePlayer = enabled;
    this.notifySubscribers();
  }

  // 初始化单机游戏
  initSinglePlayerGame(): MahjongGame {
    this.localGame = new MahjongGame();

    const player0: EngineGamePlayer = { seat: 0, nickname: '玩家', hand: [], discarded: [], melds: [], score: 0, ready: true, online: true };
    const player1: EngineGamePlayer = { seat: 1, nickname: 'AI-简单', hand: [], discarded: [], melds: [], score: 0, ready: true, online: true };
    const player2: EngineGamePlayer = { seat: 2, nickname: 'AI-中等', hand: [], discarded: [], melds: [], score: 0, ready: true, online: true };
    const player3: EngineGamePlayer = { seat: 3, nickname: 'AI-困难', hand: [], discarded: [], melds: [], score: 0, ready: true, online: true };
    const players: EngineGamePlayer[] = [player0, player1, player2, player3];

    this.localGame.initializeGame(players);
    this.state.gameStarted = true;
    this.state.seat = 0; // 人类玩家座位号
    this.state.currentPlayer = this.localGame.getState().currentPlayer;

    // 同步人类玩家的手牌到UI
    const humanPlayer = players[0];
    this.state.myHand = [...humanPlayer.hand];
    this.state.players = players.map(p => {
      const gp: GamePlayer = {
        seat: p.seat,
        nickname: p.nickname,
        ready: p.ready,
        online: p.online,
        score: p.score
      };
      return gp;
    });

    // 同步AI手牌数据
    this.syncAIHands();

    this.notifySubscribers();
    return this.localGame;
  }

  // 获取本地游戏引擎实例
  getLocalGame(): MahjongGame | null {
    return this.localGame;
  }

  // 同步AI手牌数据
  syncAIHands(): void {
    if (!this.localGame) return;
    const gameState = this.localGame.getState();
    for (const player of gameState.players) {
      if (player.seat !== this.state.seat) {
        this.aiHands.set(player.seat, [...player.hand]);
        this.aiMelds.set(player.seat, [...player.melds]);
        this.aiDiscarded.set(player.seat, [...player.discarded]);
      }
    }
  }

  // 获取指定座位玩家的手牌
  getPlayerHand(seat: number): number[] {
    if (seat === this.state.seat) {
      return [...this.state.myHand];
    }
    const hand = this.aiHands.get(seat);
    return hand ? [...hand] : [];
  }

  // 获取指定座位玩家的牌组
  getPlayerMelds(seat: number): number[][] {
    if (seat === this.state.seat) {
      return [...this.state.myMelds];
    }
    const melds = this.aiMelds.get(seat);
    return melds ? [...melds] : [];
  }

  // 获取指定座位玩家的弃牌
  getPlayerDiscarded(seat: number): number[] {
    if (seat === this.state.seat) {
      return [...this.state.myDiscarded];
    }
    const discarded = this.aiDiscarded.get(seat);
    return discarded ? [...discarded] : [];
  }

  // ==================== 多人模式对手追踪 ====================

  // 多人模式：同步初始手牌数量
  syncMultiplayerHands(hands: Record<string, Array<number>>): void {
    this.multiplayerHandCounts.clear();
    this.multiplayerDiscards.clear();
    const keys = Object.keys(hands);
    for (let i = 0; i < keys.length; i++) {
      const seat = parseInt(keys[i]);
      if (!isNaN(seat) && seat !== this.state.seat) {
        const hand = hands[keys[i]] as Array<number>;
        this.multiplayerHandCounts.set(seat, hand.length);
      }
    }
  }

  // 多人模式：对手摸牌
  opponentDrewTile(seat: number): void {
    const count = this.multiplayerHandCounts.get(seat) || 13;
    this.multiplayerHandCounts.set(seat, count + 1);
    this.notifySubscribers();
  }

  // 多人模式：记录对手弃牌
  addPlayerDiscard(seat: number, tile: number): void {
    // 更新手牌数量
    const count = this.multiplayerHandCounts.get(seat) || 13;
    this.multiplayerHandCounts.set(seat, Math.max(0, count - 1));

    // 记录弃牌
    if (!this.multiplayerDiscards.has(seat)) {
      this.multiplayerDiscards.set(seat, []);
    }
    const discards = this.multiplayerDiscards.get(seat);
    if (discards) {
      discards.push(tile);
    }
    this.notifySubscribers();
  }

  // 多人模式：更新对手手牌数量（服务器同步）
  updateOpponentHandCount(seat: number, count: number): void {
    this.multiplayerHandCounts.set(seat, count);
    this.notifySubscribers();
  }

  // ==================== 多人模式本地动作更新 ====================

  // 多人模式：碰牌 - 从手牌移除2张，添加碰牌组
  multiPong(tile: number): void {
    let removed = 0;
    this.state.myHand = this.state.myHand.filter(t => {
      if (t === tile && removed < 2) {
        removed++;
        return false;
      }
      return true;
    });
    this.state.myMelds.push([tile, tile, tile]);
    this.notifySubscribers();
  }

  // 多人模式：杠牌 - 从手牌移除3-4张，添加杠牌组
  multiKong(tile: number, isConcealed: boolean): void {
    const removeCount = isConcealed ? 4 : 3;
    let removed = 0;
    this.state.myHand = this.state.myHand.filter(t => {
      if (t === tile && removed < removeCount) {
        removed++;
        return false;
      }
      return true;
    });
    this.state.myMelds.push([tile, tile, tile, tile]);
    this.notifySubscribers();
  }

  // 本地游戏摸牌（人类玩家）
  localDrawTile(): number | null {
    if (!this.localGame) return null;
    const tile = this.localGame.drawTile(this.state.seat);
    if (tile !== null) {
      this.syncLocalStateToUI();
    }
    return tile;
  }

  // 本地游戏出牌（人类玩家）
  localDiscardTile(tile: number): boolean {
    if (!this.localGame) return false;
    const result = this.localGame.discardTile(this.state.seat, tile);
    if (result) {
      // 使用完整的本地状态同步，确保 gameEnded/winner/lastAction 都正确同步
      this.syncLocalStateToUI();
      this.syncAIHands();
    }
    return result;
  }

  // 本地游戏碰牌（人类玩家）
  localPong(tile: number): boolean {
    if (!this.localGame) return false;
    const result = this.localGame.pong(this.state.seat, tile);
    if (result) {
      this.syncLocalStateToUI();
    }
    return result;
  }

  // 本地游戏杠牌（人类玩家）
  localKong(tile: number): boolean {
    if (!this.localGame) return false;
    const result = this.localGame.kong(this.state.seat, tile);
    if (result) {
      this.syncLocalStateToUI();
    }
    return result;
  }

  // 本地游戏胡牌（人类玩家）
  localWin(tile: number): boolean {
    if (!this.localGame) return false;
    const result = this.localGame.win(this.state.seat, tile);
    if (result) {
      this.syncLocalStateToUI();
    }
    return result;
  }

  // AI回合处理
  processAITurn(ai: (hand: number[], lastDiscarded: number, melds: number[][]) => AIDecisionResult): number | null {
    if (!this.localGame) return null;

    const gameState = this.localGame.getState();
    const currentSeat = gameState.currentPlayer;
    const aiPlayer = gameState.players[currentSeat];

    if (!aiPlayer || currentSeat === this.state.seat) return null;

    // 如果引擎在等待反应，AI要先判断是否响应上家的出牌
    if (gameState.waitingForReaction) {
      const reactions = this.localGame.getAvailableReactions(currentSeat);
      if (reactions.length > 0) {
        // AI有可用的反应动作
        const lastTile = gameState.lastDiscardedTile || 0;
        const decision = ai([...aiPlayer.hand], lastTile, [...aiPlayer.melds]);
        if (decision.action === 'WIN' || decision.action === 'KONG' ||
            decision.action === 'PONG') {
          this.localGame.resolveReaction(currentSeat, decision.action);
          this.syncLocalStateToUI();
          this.syncAIHands();
          return null; // AI执行了反应，当前玩家不变
        }
      }
      // AI没有反应动作或选择PASS
      this.localGame.passReaction(currentSeat);
      this.syncLocalStateToUI();
      this.syncAIHands();
      return null;
    }

    // 正常回合：检查是否刚摸牌/碰/杠（已经有牌可出，不需要再摸）
    const stateBeforeAction = this.localGame.getState();
    const justReacted = stateBeforeAction.lastAction &&
      stateBeforeAction.lastAction.player === currentSeat &&
      (stateBeforeAction.lastAction.action === 'DRAW' ||
       stateBeforeAction.lastAction.action === 'PONG' ||
       stateBeforeAction.lastAction.action === 'KONG');

    let drawnTile: number | null = null;
    if (!justReacted) {
      // 正常摸牌
      drawnTile = this.localGame.drawTile(currentSeat);
      if (drawnTile === null) {
        this.syncLocalStateToUI();
        this.syncAIHands();
        return null;
      }
    }

    // 重新获取状态
    const afterDrawState = this.localGame.getState();
    const updatedAiPlayer = afterDrawState.players[currentSeat];

    // AI用自己手牌做决策
    const decision = ai([...updatedAiPlayer.hand], afterDrawState.lastDiscardedTile || 0, [...updatedAiPlayer.melds]);

    let discardedTile: number | null = null;

    switch (decision.action) {
      case 'DISCARD':
        if (decision.tile !== undefined) {
          this.localGame.discardTile(currentSeat, decision.tile);
          discardedTile = decision.tile;
        }
        break;
      case 'WIN':
        // 自摸胡牌 - drawnTile可能为null（刚碰/杠后的情况，此时用手中的牌）
        if (drawnTile !== null) {
          this.localGame.win(currentSeat, drawnTile);
        } else if (decision.tile !== undefined) {
          this.localGame.win(currentSeat, decision.tile);
        }
        break;
      case 'KONG':
        // 暗杠：杠后已补牌，需要立即出牌
        if (decision.tile !== undefined) {
          this.localGame.kong(currentSeat, decision.tile);
          // 杠后出牌
          const afterKongState = this.localGame.getState();
          const afterKongPlayer = afterKongState.players[currentSeat];
          if (afterKongPlayer && afterKongPlayer.hand.length > 0) {
            const kongDiscard = afterKongPlayer.hand[afterKongPlayer.hand.length - 1];
            this.localGame.discardTile(currentSeat, kongDiscard);
            discardedTile = kongDiscard;
          }
        }
        break;
      default:
        // 无有效操作，随机出牌
        if (updatedAiPlayer.hand.length > 0) {
          const randomTile = updatedAiPlayer.hand[Math.floor(Math.random() * updatedAiPlayer.hand.length)];
          this.localGame.discardTile(currentSeat, randomTile);
          discardedTile = randomTile;
        }
        break;
    }

    this.syncLocalStateToUI();
    this.syncAIHands();

    return discardedTile;
  }

  // 检查本地引擎是否在等待反应
  isLocalWaitingForReaction(): boolean {
    if (!this.localGame) return false;
    return this.localGame.isWaitingForReaction();
  }

  // 获取人类玩家的本地可用反应
  getLocalReactions(): string[] {
    if (!this.localGame) return [];
    return this.localGame.getAvailableReactions(this.state.seat);
  }

  // 人类玩家执行本地反应
  resolveLocalReaction(action: string): boolean {
    if (!this.localGame) return false;
    const result = this.localGame.resolveReaction(this.state.seat, action);
    this.syncLocalStateToUI();
    this.syncAIHands();
    return result;
  }

  // 人类玩家PASS反应
  passLocalReaction(): void {
    if (!this.localGame) return;
    this.localGame.passReaction(this.state.seat);
    this.syncLocalStateToUI();
    this.syncAIHands();
  }

  // AI自动摸牌出牌流程
  aiDrawAndDiscard(aiDecision: (hand: number[]) => number): void {
    if (!this.localGame) return;

    const gameState = this.localGame.getState();
    const currentSeat = gameState.currentPlayer;

    if (currentSeat === this.state.seat) return;

    // AI摸牌
    const drawnTile = this.localGame.drawTile(currentSeat);
    if (drawnTile !== null) {
      // AI决定出哪张牌
      const aiPlayer = gameState.players[currentSeat];
      const discardTile = aiDecision([...aiPlayer.hand]);
      this.localGame.discardTile(currentSeat, discardTile);
    }

    this.syncLocalStateToUI();
    this.syncAIHands();
  }

  // 本地状态同步到UI
  syncLocalStateToUI(): void {
    if (!this.localGame) return;

    const gameState = this.localGame.getState();
    const humanPlayer = gameState.players[this.state.seat];

    if (humanPlayer) {
      // 检查手牌是否变化，变化时递增版本号
      const oldHand = JSON.stringify(this.state.myHand);
      const newHand = JSON.stringify(humanPlayer.hand);
      if (oldHand !== newHand) {
        this.state.handVersion++;
      }
      this.state.myHand = [...humanPlayer.hand];
      this.state.myDiscarded = [...humanPlayer.discarded];
      this.state.myMelds = [...humanPlayer.melds];
    }
    this.state.currentPlayer = gameState.currentPlayer;
    this.state.remainingTiles = gameState.remainingTiles;
    this.state.gameEnded = gameState.phase === GamePhase.ENDED;

    // 同步赢家（引擎无赢家时清除）
    this.state.winner = gameState.winner !== undefined ? gameState.winner : undefined;

    // 同步最后动作（引擎无动作时清除）
    if (gameState.lastAction) {
      this.state.lastAction = {
        player: gameState.lastAction.player,
        action: gameState.lastAction.action,
        tile: gameState.lastAction.tile
      };
    } else {
      this.state.lastAction = undefined;
    }

    // 更新分数
    for (const player of gameState.players) {
      this.updatePlayerScore(player.seat, player.score);
    }

    this.notifySubscribers();
  }

  // 检查本地游戏中其他玩家是否可以响应
  getLocalAvailableActions(lastDiscardedTile: number): string[] {
    const actions: string[] = [];

    if (!this.localGame || !this.state.gameStarted || this.state.gameEnded) {
      return actions;
    }

    const gameState = this.localGame.getState();
    const humanPlayer = gameState.players[this.state.seat];

    if (MahjongRules.canWin(humanPlayer.hand, lastDiscardedTile)) {
      actions.push('WIN');
    }
    if (MahjongRules.canPong(humanPlayer.hand, lastDiscardedTile)) {
      actions.push('PONG');
    }
    if (MahjongRules.canChow(humanPlayer.hand, lastDiscardedTile)) {
      actions.push('CHOW');
    }
    if (MahjongRules.canKong(humanPlayer.hand, lastDiscardedTile)) {
      actions.push('KONG');
    }

    return actions;
  }

  // 获取对手手牌数量
  getOpponentHandCount(seat: number): number {
    if (seat === this.state.seat) return this.state.myHand.length;
    if (this.state.isSinglePlayer) {
      const hand = this.aiHands.get(seat);
      return hand ? hand.length : 0;
    }
    if (this.state.isSinglePlayerServer) {
      const hand = this.state.allHands.get(seat);
      return hand ? hand.length : 0;
    }
    // 多人模式
    return this.multiplayerHandCounts.get(seat) || 0;
  }

  // ==================== 服务端单机模式 ====================

  initServerSinglePlayerGame(data: MessageData): void {
    this.state.isSinglePlayerServer = true;
    this.state.isSinglePlayer = true;
    this.state.gameId = (data.gameId as string) || '';
    this.state.currentPlayer = Number(data.currentPlayer) || 0;
    this.state.remainingTiles = Number(data.remainingTiles) || 108;
    this.state.dealer = Number(data.dealerSeat) || 0;
    this.state.round = 1;
    this.state.gameStarted = true;
    this.state.gameEnded = false;
    this.state.seat = 0;

    if (data.players) {
      this.state.players = data.players.map(p => {
        const gp: GamePlayer = {
          seat: p.seat,
          nickname: p.nickname,
          ready: p.ready,
          online: p.online,
          score: 0
        };
        return gp;
      });
    }

    this.parseAllState(data);
    this.notifySubscribers();
  }

  updateServerSinglePlayerState(data: MessageData): void {
    this.parseAllState(data);
    if (data.currentPlayer !== undefined) {
      this.state.currentPlayer = Number(data.currentPlayer);
    }
    if (data.remainingTiles !== undefined) {
      this.state.remainingTiles = Number(data.remainingTiles);
    }
    if (data.seat !== undefined) {
      this.state.seat = Number(data.seat);
    }
    this.notifySubscribers();
  }

  private parseAllState(data: MessageData): void {
    const hands = data.hands;
    if (hands) {
      this.state.allHands = new Map();
      const keys = Object.keys(hands);
      for (let i = 0; i < keys.length; i++) {
        const seat = parseInt(keys[i]);
        if (!isNaN(seat)) {
          const hand = hands[keys[i]] as Array<number>;
          // 不排序，保持原始顺序（新摸的牌在末尾）
          this.state.allHands.set(seat, [...hand]);
        }
      }
      const seat0Hand = this.state.allHands.get(0);
      if (seat0Hand) {
        this.state.myHand = [...seat0Hand];
      }
    }

    const melds = data.melds;
    if (melds) {
      this.state.allMelds = new Map();
      const keys = Object.keys(melds);
      for (let i = 0; i < keys.length; i++) {
        const seat = parseInt(keys[i]);
        if (!isNaN(seat)) {
          this.state.allMelds.set(seat, melds[keys[i]] as number[][]);
        }
      }
      const seat0Melds = this.state.allMelds.get(0);
      if (seat0Melds) {
        this.state.myMelds = [...seat0Melds];
      }
    }

    const discarded = data.discarded;
    if (discarded) {
      console.info(`[parseAllState] 收到弃牌数据: ${JSON.stringify(discarded)}`);
      this.state.allDiscarded = new Map();
      const keys = Object.keys(discarded);
      for (let i = 0; i < keys.length; i++) {
        const seat = parseInt(keys[i]);
        if (!isNaN(seat)) {
          const seatDiscarded = discarded[keys[i]] as number[];
          this.state.allDiscarded.set(seat, seatDiscarded);
          console.info(`[parseAllState] 座位${seat}弃牌: ${JSON.stringify(seatDiscarded)}`);
        }
      }
      const seat0Discarded = this.state.allDiscarded.get(0);
      if (seat0Discarded) {
        this.state.myDiscarded = [...seat0Discarded];
      }
    } else {
      console.info(`[parseAllState] 未收到弃牌数据`);
    }

    // 更新所有玩家分数
    const scores = data.scores;
    if (scores) {
      const keys = Object.keys(scores);
      for (let i = 0; i < keys.length; i++) {
        const playerId = keys[i];
        const score = scores[playerId];
        // 从playerId后缀解析seat (格式: gameId-seatN)
        const seatMatch = playerId.match(/seat(\d+)$/);
        if (seatMatch) {
          const seat = parseInt(seatMatch[1]);
          this.updatePlayerScore(seat, score);
        }
      }
    }
  }

  getSeatHand(seat: number): number[] {
    if (this.state.isSinglePlayerServer) {
      const hand = this.state.allHands.get(seat);
      return hand ? [...hand] : [];
    }
    return this.getPlayerHand(seat);
  }

  getSeatMelds(seat: number): number[][] {
    if (this.state.isSinglePlayerServer) {
      const melds = this.state.allMelds.get(seat);
      return melds ? [...melds] : [];
    }
    return this.getPlayerMelds(seat);
  }

  getSeatDiscarded(seat: number): number[] {
    if (this.state.isSinglePlayerServer) {
      const discarded = this.state.allDiscarded.get(seat);
      return discarded ? [...discarded] : [];
    }
    return this.getPlayerDiscarded(seat);
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
      round: 1,
      isSinglePlayer: false,
      isSinglePlayerServer: false,
      allHands: new Map(),
      allMelds: new Map(),
      allDiscarded: new Map(),
      gameId: null,
      handVersion: 0
    };
    this.localGame = null;
    this.aiHands.clear();
    this.aiMelds.clear();
    this.aiDiscarded.clear();
    this.multiplayerHandCounts.clear();
    this.multiplayerDiscards.clear();
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

  // 根据playerId获取座位号（多人模式）
  getSeatByPlayerId(playerId: string): number {
    const player = this.state.players.find(p => p.playerId === playerId);
    return player ? player.seat : -1;
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