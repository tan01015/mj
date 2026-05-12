import { Hand } from '../engine/Hand';

export class SimpleAI {
  playerId: number;
  constructor(playerId: number) { this.playerId = playerId; }

  // Very simple discard policy: remove the tile with highest id (placeholder)
  decideDiscardIndex(hand: Hand): number {
    if (hand.tiles.length === 0) return -1;
    let best = 0;
    for (let i = 1; i < hand.tiles.length; i++) {
      if (hand.tiles[i].id > hand.tiles[best].id) best = i;
    }
    return best;
  }
}
