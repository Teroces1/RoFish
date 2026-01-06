This is RoFish 1.0, one of Roblox's strongest chess engines.

Inspiration from Sebastian Lague's chess engine (https://www.youtube.com/watch?v=U4ogK0MIzqk) and the Chess Programming Wiki, but many algorithms were custom discovered and adapted for Roblox.






# Chess Engine API (engine.luau)

This document describes the public API and conventions exposed by `engine.luau`.
The module implements a full chess engine with legal move generation, evaluation,
alpha–beta search, quiescence search, iterative deepening, and a transposition table.
This document has been AI-generated.

---

## Module

```lua
local Board = require(path.to.engine)
```

The module returns the `Board` class.

---

## Core Data Types

### Squares
- Internal square indexing: **1–64**
- `encodeSquare(square: number) -> string`
  - Converts to algebraic notation (e.g. `1 -> "a1"`)
- `decodeSquare(str: string) -> number`
  - Converts algebraic notation to internal index

---

### Move Representation

Moves are encoded as `Vector3.new(from, to, special)`:

| Field | Meaning |
|------|--------|
| X | From square (1–64) |
| Y | To square (1–64) |
| Z | Special move flag |

#### Special Move Flags
- `0`  — Normal move
- `1`  — En passant
- `2`  — Promotion to knight
- `5`  — Promotion to rook
- `6`  — Promotion to bishop
- `7`  — Promotion to queen
- `11` — Castle queenside
- `12` — Castle kingside

---

### Move Encoding (UCI-style)

```lua
encodeMove(move: Vector3) -> string
```

Examples:
- `e2e4`
- `e7e8q`

---

## Board Construction & State

### `Board.new() -> Board`
Creates a new board with:
- 64-square board array
- Piece list
- Side to move
- Castling rights
- En passant target
- Move clocks
- Zobrist hashing
- Transposition table

---

### FEN Handling

```lua
Board:loadFEN(fen: string)
Board:getFEN() -> string
```

Supports piece placement, side to move, castling rights, en passant square,
halfmove and fullmove counters.

---

### Legacy Board Conversion

```lua
Board:convetFromOldBoard(oldBoard)
```

Converts from the legacy board format (castling logic is TODO internally).

---

## Move Generation

### `Board:getLegalMoves(onlyCaptures: boolean?) -> (moves, inCheck)`

- Generates fully legal moves
- Orders moves using capture scoring, promotions, pawn-attack penalties,
  and transposition-table best move
- `onlyCaptures = true` generates capture-only moves (quiescence)

Returns:
- `moves`: array of `Vector3`
- `inCheck`: whether the side to move is in check

---

## Making and Unmaking Moves

### `Board:makeMove(move: Vector3)`
Applies a move and updates:
- Board array
- Piece list
- Side to move
- Castling rights
- En passant target
- Move clocks
- Zobrist hash
- Repetition history

### `Board:unMakeMove()`
Reverts the last move and restores all state.

---

## Game Termination

### `Board:isGameOver() -> (isOver, result?)`

Results:
- Checkmate → `(true, -1)`
- Stalemate → `(true, 0)`
- 50-move rule → `(true, 0)`

---

## Evaluation

### `Board:eval() -> number`
Main static evaluation:
- Material balance
- Piece-square tables
- Pawn structure heuristics
- King safety
- Endgame scaling

Returned score is from the side-to-move perspective.

### `Board:eval2(test: boolean?) -> number`
Alternate evaluation implementation.

---

## Search

### Iterative Deepening (Timed)

```lua
Board:startIterativeDeepening(
    searchTimeMs: number,
    maxDepth: number,
    maxTotalDepth: number,
    hideResults: boolean?
) -> (bestMove, bestEval, checkmatePly)
```

Features alpha–beta pruning, transposition tables, quiescence search,
check extensions, and time-based termination.

---

### Infinite / Continuous Search

```lua
Board:limitlessSearch(statsUpdateCallback)
```

Runs increasing depths until checkmate or external abort.

Callback receives:
```lua
{
    bestMove,
    checkmatePly,
    eval,
    maxDepth,
    searchDepth,
    bestMovesList
}
```

---

## Transposition Table

```lua
TranspositionTable.new(size: number)
```

```lua
tt:storeEvaluation(key, eval, matePly, move, depth, nodeType)
tt:lookupEval(key, depth, ply, alpha, beta)
tt:getMove(key)
tt:clear()
```

Node types:
- `lowerBound = -1`
- `exact = 0`
- `upperBound = 1`
- `lookupFailed = math.huge`

---

## Internal Conventions

- Colors:
  - White = `8`
  - Black = `0`
- Piece encoding: `pieceType + color`
- Piece types:
  - `1` King
  - `2` Knight
  - `3` Pawn
  - `5` Rook
  - `6` Bishop
  - `7` Queen
- Hashing:
  - 32-bit Zobrist
  - Includes pieces, castling rights, en passant, and side to move

---
