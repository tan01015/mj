import { Tile } from './Tile';
import { createShuffledDeck } from './Deck';
import { Hand } from './Hand';

export type PlayerId = number;

export interface GameState {
  deck: Tile[];
  discards: Tile[];
  hands: Hand[];
  currentPlayer: PlayerId;
}

export class Game {
  state: GameState;
  playerCount: number;

  constructor(playerCount = 4) {
    this.playerCount = playerCount;
    const deck = createShuffledDeck();
    const hands: Hand[] = [];
    for (let i = 0; i < playerCount; i++) {
      const drawn: Tile[] = [];
      // draw 13 tiles for each player initially (standard)
      for (let j = 0; j < 13; j++) drawn.push(deck.pop()!);
      hands.push(new Hand(drawn));
    }
    this.state = {
      deck,
      discards: [],
      hands,
      currentPlayer: 0,
    };
  }

  drawTile(player: PlayerId): Tile | null {
    const t = this.state.deck.pop() || null;
    if (t) this.state.hands[player].addTile(t);
    return t;
  }

  discard(player: PlayerId, tileIndex: number): Tile | null {
    const tile = this.state.hands[player].removeTileByIndex(tileIndex);
    if (!tile) return null;
    this.state.discards.push(tile);
    this.state.currentPlayer = (player + 1) % this.playerCount;
    return tile;
  }

  getHand(player: PlayerId) { return this.state.hands[player]; }
}
