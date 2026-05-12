// engine/Tile.ts
export type Suit = 'characters' | 'dots' | 'bamboos' | 'honor';

export interface Tile {
  // unique id across the full deck (0..135)
  id: number;
  suit: Suit;
  // 1..9 for numbered suits, absent for honors
  rank?: number;
  // human readable name, e.g. "1-dot" or "east"
  name: string;
}

export function tileName(suit: Suit, rank?: number) {
  if (suit === 'honor') return `${rank}`;
  return `${rank}` + '-' + suit[0];
}
