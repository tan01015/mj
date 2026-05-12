// tests/tile.spec.ts
import { createStandardDeck } from '../engine/Deck';

test('standard deck has 136 tiles', () => {
  const deck = createStandardDeck();
  expect(deck.length).toBe(136);
});
