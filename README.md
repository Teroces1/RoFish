# Roblox Chess Engine

I'm attempting to build one of the best chess engines running **purely on Roblox**.

▶ **See V1 in action:**  
https://www.roblox.com/games/14762324905/Ultimate-Chess-Engine

V1 was the first chess engine I've ever written in any programming language, and it turned out pretty well.

V1 is already fairly strong, and I'm hoping **V2 will surpass 2000 ELO** (compared to chess.com ratings) when given **4 seconds of thinking time**.

---

# Recent Achievements

- **V2 reached 15M+ NPS** on a performance test (`perft`) after many optimizations.
- Uses **transposition tables for perft testing**.
- For comparison, **V1 achieved ~1.4M NPS**.
- Currently working on additional optimizations to push performance even further.

---

# Features

## V1

- Uses a **64-length table** for piece storage (main data structure)
- Uses **bitboards** for move generation
- **Precomputed moves** for all pieces  
  - (Rook move generation was split into two tables — fixed in V2)
- Evaluation considers:
  - Material
  - Piece positions
  - Basic king safety
  - Pawn structure
  - Endgame vs midgame scaling
- Uses **iterative deepening**

### Search Strategies

- Minimax (**Negamax**) with **alpha-beta pruning**
- **Quiescence search**
- **Move ordering**
- **Transposition tables** (32-bit hashing)

### Game Rules Implemented

- 50-move rule
- Stalemates
- Checkmates

---

## V2

- Uses the **same core data structure as V1** (64-length piece array)
- Stores **additional bitboard states** for performance improvements

### Move Generation

- Same algorithm as V1 but **heavily optimized**
- Everything possible is **precomputed**
- All sliding pieces now use **magic bitboards**
- Packs **two 32-bit board halves into a single 32-bit integer lookup key** for hashmap access

### Evaluation

Considers:

- Material
- Piece positions
- King safety
- Pawn structure
- Endgame vs middlegame scaling
- Mobility

### Search Strategies

- Minimax (**Negamax**) with **alpha-beta pruning**
- **Quiescence search**
- **Move ordering**
- **Transposition tables**  
  - 64-bit hashing  
  - Buckets of 4 entries each
- **Killer move heuristic**
- **Null move pruning**
- **Late Move Reductions (LMR)**
- **NNUE guessing**

### Planned Strategies

- Additional **move heuristics**

### Game Rules Implemented

- 50-move rule
- 3-fold repetition
- Stalemates
- Checkmates
