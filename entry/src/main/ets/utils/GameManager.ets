export interface Player {
  seat: number;
  nickname: string;
  ready: boolean;
  online: boolean;
}

export interface GameState {
  roomId: string;
  playerId: string;
  seat: number;
  players: Player[];
  gameStarted: boolean;
  currentTurn: number;
  lastDiscardTile: number | null;
  lastDiscardPlayer: number | null;
  remainingTiles: number;
  myHand: number[];
  discardPile: string[];
  scores: Record<string, number>;
}

export class GameManager {
  private state: GameState = {
    roomId: '',
    playerId: '',
    seat: -1,
    players: [],
    gameStarted: false,
    currentTurn: 0,
    lastDiscardTile: null,
    lastDiscardPlayer: null,
    remainingTiles: 136,
    myHand: [],
    discardPile: [],
    scores: {}
  };

  private listeners: ((state: GameState) => void)[] = [];

  get gameState(): GameState {
    const result: GameState = {
      roomId: this.state.roomId,
      playerId: this.state.playerId,
      seat: this.state.seat,
      players: this.state.players,
      gameStarted: this.state.gameStarted,
      currentTurn: this.state.currentTurn,
      lastDiscardTile: this.state.lastDiscardTile,
      lastDiscardPlayer: this.state.lastDiscardPlayer,
      remainingTiles: this.state.remainingTiles,
      myHand: this.state.myHand,
      discardPile: this.state.discardPile,
      scores: this.state.scores
    };
    return result;
  }

  setRoomId(roomId: string) {
    this.state.roomId = roomId;
    this.notifyListeners();
  }

  setPlayerId(playerId: string) {
    this.state.playerId = playerId;
    this.notifyListeners();
  }

  setSeat(seat: number) {
    this.state.seat = seat;
    this.notifyListeners();
  }

  updatePlayers(players: Player[]) {
    this.state.players = players;
    this.notifyListeners();
  }

  setGameStarted(started: boolean) {
    this.state.gameStarted = started;
    this.notifyListeners();
  }

  updateTurn(currentTurn: number) {
    this.state.currentTurn = currentTurn;
    this.notifyListeners();
  }

  updateLastDiscard(tile: number, player: number) {
    this.state.lastDiscardTile = tile;
    this.state.lastDiscardPlayer = player;
    if (tile > 0) {
      this.state.discardPile.push(tile.toString());
    }
    this.notifyListeners();
  }

  updateRemainingTiles(count: number) {
    this.state.remainingTiles = count;
    this.notifyListeners();
  }

  updateMyHand(hand: number[]) {
    this.state.myHand = hand.sort((a, b) => a - b);
    this.notifyListeners();
  }

  addDiscardTile(tile: string) {
    this.state.discardPile.push(tile);
    this.notifyListeners();
  }

  updateScores(scores: Record<string, number>) {
    this.state.scores = scores;
    this.notifyListeners();
  }

  subscribe(listener: (state: GameState) => void) {
    this.listeners.push(listener);
    listener(this.state);
    
    return () => {
      const index = this.listeners.indexOf(listener);
      if (index > -1) {
        this.listeners.splice(index, 1);
      }
    };
  }

  private notifyListeners() {
    this.listeners.forEach(listener => listener(this.state));
  }

  reset() {
    this.state = {
      roomId: '',
      playerId: '',
      seat: -1,
      players: [],
      gameStarted: false,
      currentTurn: 0,
      lastDiscardTile: null,
      lastDiscardPlayer: null,
      remainingTiles: 136,
      myHand: [],
      discardPile: [],
      scores: {}
    };
    this.notifyListeners();
  }

  getCurrentPlayer(): Player | undefined {
    return this.state.players.find(p => p.seat === this.state.currentTurn);
  }

  isMyTurn(): boolean {
    return this.state.currentTurn === this.state.seat;
  }

  getPlayerBySeat(seat: number): Player | undefined {
    return this.state.players.find(p => p.seat === seat);
  }
}

export const gameManager = new GameManager();
