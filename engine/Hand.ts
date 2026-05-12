import { Tile } from './Tile';

export class Hand {
  tiles: Tile[] = [];

  constructor(initial: Tile[] = []) {
    this.tiles = initial.slice();
  }

  addTile(t: Tile) {
    this.tiles.push(t);
  }

  removeTileByIndex(index: number): Tile | null {
    if (index < 0 || index >= this.tiles.length) return null;
    return this.tiles.splice(index, 1)[0];
  }

  sort() {
    this.tiles.sort((a,b) => a.id - b.id);
  }

  size() { return this.tiles.length; }
}
