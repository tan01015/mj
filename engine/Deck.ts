import { Tile } from './Tile';

export function createStandardDeck(): Tile[] {
  const tiles: Tile[] = [];
  let id = 0;
  // numbered suits: characters, dots, bamboos — ranks 1..9, 4 copies each
  const suits: ('characters' | 'dots' | 'bamboos')[] = ['characters','dots','bamboos'];
  for (const suit of suits) {
    for (let rank = 1; rank <= 9; rank++) {
      for (let copy = 0; copy < 4; copy++) {
        tiles.push({ id: id++, suit, rank, name: `${rank}-${suit}` });
      }
    }
  }
  // honors (winds and dragons): we'll encode using rank numbers for simplicity
  const honors = ['east','south','west','north','white','green','red'];
  for (const h of honors) {
    for (let copy = 0; copy < 4; copy++) {
      tiles.push({ id: id++, suit: 'honor', name: h });
    }
  }
  return tiles;
}

export function shuffle<T>(array: T[]): T[] {
  const a = array.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

export function createShuffledDeck(): Tile[] {
  return shuffle(createStandardDeck());
}
