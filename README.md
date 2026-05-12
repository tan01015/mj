# mahjong-core (feature/mahjong-core)

This folder contains an initial skeleton of the Mahjong core engine and a minimal AI and UI placeholder.

Structure added:
- engine/Tile.ts, Deck.ts, Hand.ts, Game.ts — core types and simple game flow
- ai/SimpleAI.ts — very small rule-based AI skeleton
- pages/GamePage.ets — placeholder page for integrating the engine
- tests/tile.spec.ts — initial unit test (expects 136 tiles)

How to run tests
- This repo uses the existing project tooling. You can run your JS/TS tests according to the project's test runner (jest/mocha). The added test is a template; adapt to repo test config as needed.

Next steps
- Implement turn state machine and action priorities (chow/pong/kan/ron)
- Add hu/hand-evaluation engine and configurable scoring
- Implement AI improvements (listen evaluation, discard heuristics)
- Connect GamePage with the engine for an interactive single-player vs 3 AI demo
