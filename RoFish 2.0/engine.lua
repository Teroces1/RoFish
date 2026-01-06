--!native

local engine = {}
engine.__index = engine

--[[ Pieces
	1: king
	2: knight
	3: pawn
	4:
	5: rook
	6: bishop
	7: queen

]]

local PieceValues = {
	[1] = 200,
	[2] = 300,
	[3] = 100,
	[5] = 500,
	[6] = 320,
	[7] = 900,
	[1+8] = 200,
	[2+8] = 300,
	[3+8] = 100,
	[5+8] = 500,
	[6+8] = 320,
	[7+8] = 900
}

local kingSquareBonus = {
	30, 50, 20,-15,-15, 20, 50, 30,
	20, 20,  0,  0,  0,  0, 20, 20,
	-10,-20,-20,-20,-20,-20,-20,-10,
	-20,-30,-30,-40,-40,-30,-30,-20,
	-30,-40,-40,-50,-50,-40,-40,-30,
	-30,-40,-40,-50,-50,-40,-40,-30,
	-30,-40,-40,-50,-50,-40,-40,-30,
	-30,-40,-40,-50,-50,-40,-40,-30,
}

local kingSquareEndgameBonus = {
	-50,-30,-30,-30,-30,-30,-30,-50,
	-30,-30,  0,  0,  0,  0,-30,-30,
	-30,-10, 20, 30, 30, 20,-10,-30,
	-30,-10, 30, 40, 40, 30,-10,-30,
	-30,-10, 30, 40, 40, 30,-10,-30,
	-30,-10, 20, 30, 30, 20,-10,-30,
	-30,-20,-10,  0,  0,-10,-20,-30,
	-50,-40,-30,-20,-20,-30,-40,-50,
}

local pawnSquareBonus = {
	0,  0,  0,  0,  0,  0,  0,  0,
	5, 10, 10,-40,-40, 10, 10,  5,
	5, -5,-10,  0,  0,-10, -5,  5,
	0,  0,  0, 25, 25,  0,  0,  0,
	5,  5, 12, 28, 28, 12,  5,  5,
	10, 10, 20, 30, 30, 20, 10, 10,
	50, 50, 50, 50, 50, 50, 50, 50,		
	0,  0,  0,  0,  0,  0,  0,  0,
}

local pawnSquareEndgameBonus = {
	0,	0,	0,	0,	0,	0,	0,	0,
	5,	5,	5,	5,	5,	5,	5,	5,
	5,	5,	5,	5,	5,	5,	5,	5,
	15,	15,	15,	15,	15,	15,	15,	15,
	30,	30,	30,	30,	30,	30,	30,	30,
	45,	45,	45,	45,	45,	45,	45,	45,
	85,	85,	85,	85,	85,	85,	85,	85,
	0,	0,	0,	0,	0,	0,	0,	0,

}

local piecePositionBonuses = {
	[1] = {
		-50,-30,-30,-30,-30,-30,-30,-50,
		-30,-30,  0,  0,  0,  0,-30,-30,
		-30,-10, 20, 30, 30, 20,-10,-30,
		-30,-10, 30, 40, 40, 30,-10,-30,
		-30,-10, 30, 40, 40, 30,-10,-30,
		-30,-10, 20, 30, 30, 20,-10,-30,
		-30,-20,-10,  0,  0,-10,-20,-30,
		-50,-40,-30,-20,-20,-30,-40,-50,
	},
	[2] = {
		-50,-40,-30,-30,-30,-30,-40,-50,
		-40,-20,  0,  0,  0,  0,-20,-40,
		-30,  0, 10, 15, 15, 10,  0,-30,
		-30,  5, 15, 20, 20, 15,  5,-30,
		-30,  0, 15, 20, 20, 15,  0,-30,
		-30,  5, 10, 15, 15, 10,  5,-30,
		-40,-20,  0,  5,  5,  0,-20,-40,
		-50,-40,-30,-30,-30,-30,-40,-50,
	},
	[3] = {
		0,  0,  0,  0,  0,  0,  0,  0,
		5, 10, 10,-40,-40, 10, 10,  5,
		5, -5,-10,  0,  0,-10, -5,  5,
		0,  0,  0, 25, 25,  0,  0,  0,
		5,  5, 12, 28, 28, 12,  5,  5,
		10, 10, 20, 30, 30, 20, 10, 10,
		50, 50, 50, 50, 50, 50, 50, 50,		
		0,  0,  0,  0,  0,  0,  0,  0,
	},
	[5] = {
		0,  0,  0,  5,  5,  0,  0,  0,
		-5,  0,  0,  0,  0,  0,  0, -5,
		-5,  0,  0,  0,  0,  0,  0, -5,
		-5,  0,  0,  0,  0,  0,  0, -5,
		-5,  0,  0,  0,  0,  0,  0, -5,
		-5,  0,  0,  0,  0,  0,  0, -5,
		5, 10, 10, 10, 10, 10, 10,  5,
		0,  0,  0,  0,  0,  0,  0,  0,
	},
	[6] = {
		-20,-10,-10,-10,-10,-10,-10,-20,
		-10,  5,  0,  0,  0,  0,  5,-10,
		-10, 10, 10, 10, 10, 10, 10,-10,
		-10,  0, 10, 10, 10, 10,  0,-10,
		-10,  5,  5, 10, 10,  5,  5,-10,
		-10,  0,  5, 10, 10,  5,  0,-10,
		-10,  0,  0,  0,  0,  0,  0,-10,
		-20,-10,-10,-10,-10,-10,-10,-20,
	},
	[7] = {
		-20,-10,-10, -5, -5,-10,-10,-20,
		-10,  0,  5,  0,  0,  0,  0,-10,
		-10,  5,  5,  5,  5,  5,  0,-10,
		0,  0,  5,  5,  5,  5,  0, -5,
		-5,  0,  5,  5,  5,  5,  0, -5,
		-10,  0,  5,  5,  5,  5,  0,-10,
		-10,  0,  0,  0,  0,  0,  0,-10,
		-20,-10,-10, -5, -5,-10,-10,-20,
	},
}

local endGamePieceValues = {
	[2] = 10,
	[5] = 20,
	[6] = 10,
	[7] = 45,
}
local endGameStartWeight = 1/125

local moves = require(script.Parent.moves)

function engine.new()
	local self = setmetatable({}, engine)
	
	-- bitboards are split since integers are 32 bits
	-- lower bitboard are squares 1-32 (a1 to h4) and upper 33-64 (a5 to h8)
	
	self.kl = 0	-- kings bitboard lower
	self.nl = 0	-- knights bitboard lower
	self.pl = 0	-- pawns bitboard lower
	self.rl = 0	-- rooks bitboard lower
	self.bl = 0	-- bishops bitboard lower
	self.ql = 0	-- queens bitboard lower
	self.ku = 0	-- kings bitboard upper
	self.nu = 0	-- knights bitboard upper
	self.pu = 0	-- pawns bitboard upper
	self.ru = 0	-- rooks bitboard upper
	self.bu = 0	-- bishops bitboard upper
	self.qu = 0	-- queens bitboard upper
	
	self.lightL = 0	-- light side bitboard lower
	self.darkL = 0	-- dark side bitboard lower
	self.lightU = 0	-- light side bitboard upper
	self.darkU = 0	-- dark side bitboard upper
	
	self.lightKing = 0	-- these are 1-64 if valid, 0 if not available
	self.darkKing = 0
	self.enPassantTarget = 0
	
	self.board = table.create(64, 0)	-- 0 means empty, a number from 1-15 means a piece (side + piece id, where side is either 8 or 0)
	
	self.totalMoves = 0
	self.halfTimeClock = 0
	
	self.castlingRights = 0
	self.sideToMove = 8	-- switches between 0 (black) and 8 (white)
	self.moveLog = table.create(128 * 10, 0)
	
	self.eval_pawnsOnFilesTableWhite = table.create(8, 0)
	self.eval_pawnsOnFilesTableBlack = table.create(8, 0)
	
	self.positionHistory = {}
	
	self.killerMoves = {}
	
	self:initializeZobristKeys()
	self:initializeTranspositionTable(1*256*4096)
	
	
	self.bestLine = table.create(100,0)
	self.pvLength = table.create(100,0)
	self.lines = false
	
	return self
end

function engine:extractPosition()
	return {
		board = self.board,
		lastMove = if self.totalMoves == 0 then nil else self.moveLog[10*self.totalMoves - 9],
		castlingRights = self.castlingRights,
		sideToMove = self.sideToMove
	}
end

function engine:loadFEN(fen)
	fen = fen or "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
	-- Clear alightL existing board state
	self.kl, self.nl, self.pl, self.rl, self.bl, self.ql = 0, 0, 0, 0, 0, 0
	self.ku, self.nu, self.pu, self.ru, self.bu, self.qu = 0, 0, 0, 0, 0, 0
	self.lightL, self.darkL, self.lightU, self.darkU = 0, 0, 0, 0
	self.lightKing, self.darkKing, self.enPassantTarget = 0, 0, 0
	self.castlingRights = 0
	self.board = table.create(64, 0)
	self.totalMoves = 0
	self.halfTimeClock = 0
	self.sideToMove = 8

	local parts = string.split(fen, " ")
	local piecePlacement = parts[1]
	local side = parts[2]
	local castling = parts[3]
	local enPassant = parts[4]
	local halfClock = tonumber(parts[5])
	local fulightLMoves = tonumber(parts[6])

	-- Parse the piece placement string
	local rank = 8
	local file = 1
	for char in piecePlacement:gmatch(".") do
		if char == "/" then
			rank -= 1
			file = 1
		elseif char:match("%d") then
			file += tonumber(char)
		else
			local piece, side = nil, nil
			if char:match("%l") then
				side = 0 -- dark (black)
			else
				side = 8 -- light (white)
			end

			if char:lower() == "k" then
				piece = 1 -- King
			elseif char:lower() == "n" then
				piece = 2 -- Knight
			elseif char:lower() == "p" then
				piece = 3 -- Pawn
			elseif char:lower() == "r" then
				piece = 5 -- Rook
			elseif char:lower() == "b" then
				piece = 6 -- Bishop
			elseif char:lower() == "q" then
				piece = 7 -- Queen
			end

			local squareIndex = (rank - 1) * 8 + file - 1
			local bitMask = bit32.lshift(1, squareIndex % 32)
			local isUpper = squareIndex >= 32

			self.board[squareIndex + 1] = bit32.bor(side, piece)

			-- Update the specific bitboards
			if piece == 1 then
				if isUpper then self.ku = bit32.bor(self.ku, bitMask) else self.kl = bit32.bor(self.kl, bitMask) end
				if side == 8 then self.lightKing = squareIndex + 1 else self.darkKing = squareIndex + 1 end
			elseif piece == 2 then
				if isUpper then self.nu = bit32.bor(self.nu, bitMask) else self.nl = bit32.bor(self.nl, bitMask) end
			elseif piece == 3 then
				if isUpper then self.pu = bit32.bor(self.pu, bitMask) else self.pl = bit32.bor(self.pl, bitMask) end
			elseif piece == 5 then
				if isUpper then self.ru = bit32.bor(self.ru, bitMask) else self.rl = bit32.bor(self.rl, bitMask) end
			elseif piece == 6 then
				if isUpper then self.bu = bit32.bor(self.bu, bitMask) else self.bl = bit32.bor(self.bl, bitMask) end
			elseif piece == 7 then
				if isUpper then self.qu = bit32.bor(self.qu, bitMask) else self.ql = bit32.bor(self.ql, bitMask) end
			end

			-- Update side bitboards
			if side == 8 then
				if isUpper then self.lightU = bit32.bor(self.lightU, bitMask) else self.lightL = bit32.bor(self.lightL, bitMask) end
			else
				if isUpper then self.darkU = bit32.bor(self.darkU, bitMask) else self.darkL = bit32.bor(self.darkL, bitMask) end
			end

			file += 1
		end
	end

	-- Parse side to move
	self.sideToMove = (side == "w") and 8 or 0

	-- Parse castling rights
	self.castlingRights = 0
	if castling:find("K") then self.castlingRights = bit32.bor(self.castlingRights, 0b1000) end
	if castling:find("Q") then self.castlingRights = bit32.bor(self.castlingRights, 0b0100) end
	if castling:find("k") then self.castlingRights = bit32.bor(self.castlingRights, 0b0010) end
	if castling:find("q") then self.castlingRights = bit32.bor(self.castlingRights, 0b0001) end

	-- Parse en passant
	if enPassant ~= "-" then
		local file = string.byte(enPassant:sub(1, 1)) - string.byte("a")
		local rank = tonumber(enPassant:sub(2, 2)) - 1
		self.enPassantTarget = rank * 8 + file + 1
	else
		self.enPassantTarget = 0
	end

	-- Parse halfmove clock and fulightLmove number
	self.halfTimeClock = halfClock or 0
	self.totalMoves = (fulightLMoves or 1) - 1
	
	self:generateZobristHash()
	self:TTclear()
end

function engine:getFEN()
	local str = ""
	
	local pieceMappings = {
		[1] = "k",
		[2] = "n",
		[3] = "p",
		[5] = "r",
		[6] = "b",
		[7] = "q",
		[9] = "K",
		[10] = "N",
		[11] = "P",
		[13] = "R",
		[14] = "B",
		[15] = "Q",
	}
	
	local numEmpty = 0
	
	for rank = 7, 0, -1 do
		for file = 0, 7 do
			local piece = self.board[rank*8 + file + 1]
			
			if piece == 0 then
				numEmpty += 1
			else
				if numEmpty > 0 then
					str ..= numEmpty
					numEmpty = 0
				end
				
				str ..= pieceMappings[piece]
			end
		end
		if numEmpty > 0 then
			str ..= numEmpty
			numEmpty = 0
		end
		
		if rank ~= 0 then
			str ..= "/"
		end
	end
	
	str ..= " ".. (if self.sideToMove == 0 then "b" else "w") .. " "
	
	if self.castlingRights == 0 then
		str ..= "- "
	else
		if bit32.btest(0b1000, self.castlingRights) then str..="K" end
		if bit32.btest(0b0100, self.castlingRights) then str..="Q" end
		if bit32.btest(0b0010, self.castlingRights) then str..="k" end
		if bit32.btest(0b0001, self.castlingRights) then str..="q" end
		str ..= " "
	end
	
	if self.enPassantTarget == 0 then
		str ..= "- "
	else
		str ..= string.char(97 + (self.enPassantTarget-1)%8) .. ((self.enPassantTarget-1)//8+1) .. " "
	end
	
	str ..= self.halfTimeClock .. " " .. (self.totalMoves+1)
	
	return str
end

@native
function engine:convertMovesFromBitboard(moves, pos, lower, upper, isApawn)
	local c = 0
	while lower > 0 do
		local newC = bit32.countrz(lower)+1
		c+=newC
		-- V3 (start, end, special id)
		if isApawn and c == self.enPassantTarget then
			table.insert(moves, Vector3.new(pos, c,1))
		elseif isApawn and c < 9 then
			-- promotion
			table.insert(moves, Vector3.new(pos, c,2))
			table.insert(moves, Vector3.new(pos, c,5))
			table.insert(moves, Vector3.new(pos, c,6))
			table.insert(moves, Vector3.new(pos, c,7))
		else
			table.insert(moves, Vector3.new(pos, c))
		end
		lower = bit32.rshift(lower, newC)
	end
	c = 32
	while upper > 0 do
		local newC = bit32.countrz(upper)+1
		c+=newC
		-- V3 (start, end, special id)
		if isApawn and c == self.enPassantTarget then
			table.insert(moves, Vector3.new(pos, c,1))
		elseif isApawn and c > 56 then
			-- promotion
			table.insert(moves, Vector3.new(pos, c,2))
			table.insert(moves, Vector3.new(pos, c,5))
			table.insert(moves, Vector3.new(pos, c,6))
			table.insert(moves, Vector3.new(pos, c,7))
		else
			table.insert(moves, Vector3.new(pos, c))
		end
		upper = bit32.rshift(upper, newC)
	end
end

@native
function engine:_getLegalMoves(noSort, ply, onlyCaptures)
	local lightKing = self.lightKing
	local darkKing = self.darkKing
	
	local sideToMove = self.sideToMove
	local myKing = if sideToMove == 0 then darkKing else lightKing
	
	local myKingRank, myKingFile = (myKing-1)//8, (myKing-1)%8	-- from 0-7
	
	local myKingBBL, myKingBBU = bit32.lshift(1, myKing-1), bit32.lshift(1, myKing-33)
	
	local enPassantTarget, enPassantPiece, enPassantPieceRank = self.enPassantTarget, 0, 0
	local enPassantTargetL, enPassantTargetU, enPassantPieceL, enPassantPieceU = 0,0,0,0
	if enPassantTarget ~= 0 then
		enPassantTargetL, enPassantTargetU = bit32.lshift(1, enPassantTarget-1), bit32.lshift(1, enPassantTarget-33)
		
		if sideToMove == 0 then
			enPassantPieceL = bit32.bnot(bit32.lshift(enPassantTargetL, 8))
			enPassantPiece = enPassantTarget + 8
		else
			enPassantPieceU = bit32.bnot(bit32.rshift(enPassantTargetU, 8))
			enPassantPiece = enPassantTarget - 8
		end
		
		enPassantPieceRank = enPassantPiece // 8
	end
	
	
	
	local mySideL = if sideToMove == 0 then self.darkL else self.lightL
	local mySideU = if sideToMove == 0 then self.darkU else self.lightU
	
	local enemyL = if sideToMove == 8 then self.darkL else self.lightL
	local enemyU = if sideToMove == 8 then self.darkU else self.lightU
	
	
	local piecesL, piecesU = mySideL + enemyL, mySideU + enemyU
	
	local piecesNoMyKingL, piecesNoMyKingU = bit32.band(piecesL, bit32.bnot(myKingBBL)), bit32.band(piecesU, bit32.bnot(myKingBBU))
	
	local pieceMovesLower,pieceMovesUpper
		
	if onlyCaptures then
		pieceMovesLower = table.create(64, enemyL)
		pieceMovesUpper = table.create(64, enemyU)
	else
		pieceMovesLower= table.create(64, bit32.bnot(mySideL))
		pieceMovesUpper = table.create(64, bit32.bnot(mySideU))
	end
	
	local enemyAttacksL, enemyAttacksU = 0,0
	
	local blockersL, blockersU = 0,0
	local pinMaskL, pinMaskU = 0,0
	
	-- generate king pin masks
	local kingBishopMaskL, kingBishopMaskU = moves.bishopMaskL[myKing], moves.bishopMaskU[myKing]
	local index = bit32.band(kingBishopMaskL, piecesL) + bit32.band(kingBishopMaskU, piecesU)//2
	local kingBishopPinL, kingBishopPinU = moves.bishopMovesL[myKing][index],moves.bishopMovesU[myKing][index]
	

	local kingRookMaskL, kingRookMaskU = moves.rookMaskL[myKing], moves.rookMaskU[myKing]
	-- by default dont checkf or en passant pin. however, IF the king is on the same rank as the en passant pawn, and on the same square as a pinning rook/ queen, then check
	index = bit32.band(kingRookMaskL, piecesL) *31 + bit32.band(kingRookMaskU, piecesU) *3 	-- really cool function: TOOK ME HOURS | 3 and 31 are one of the only numbers that allow for index calculation that does not overlap with other blocker arrangements
	local kingRookPinL, kingRookPinU = moves.rookMovesL[myKing][index],moves.rookMovesU[myKing][index]
	
	
	-- check handeling variables
	
	local incheck = false
	local limitMovesForChecksL, limitMoveForChecksU = 0xffffffff, 0xffffffff
	
	local attacksL, attacksU = 0,0
	
	local enPassantAllowed = true
	local canEnpassantOnCheck = false
	
	local pawnAttacksL, pawnAttacksU = 0,0
	
	for pos, fullPiece in ipairs(self.board) do
		if fullPiece == 0 then continue end
		
		local posBbL = bit32.lshift(1, pos-1)
		local posBbU = bit32.lshift(1, pos-33)
		
		local piece = fullPiece % 8	-- native:	% seems to be slightly faster than bit32.band()
		
		local color = fullPiece//8 * 8	-- native:	// and * seems to be slightly faster than just using bit32.band()	-wierd lol
		
		if color == sideToMove then
			if piece == 1 then
				pieceMovesLower[pos] = moves.kingMovesL[pos]
				pieceMovesUpper[pos] = moves.kingMovesU[pos]
			elseif piece == 2 then
				pieceMovesLower[pos], pieceMovesUpper[pos] = bit32.band(pieceMovesLower[pos], moves.knightAttacksL[pos]), bit32.band(pieceMovesUpper[pos], moves.knightAttacksU[pos])
			elseif piece == 3 then
				if color == 0 then
					local oneStepL, oneStepU = bit32.lshift(1, pos-9), bit32.lshift(1, pos-41)	-- native: using bit shifts instead of precomputed move lookups seems to be slightly faster
					if pos >= 49 and not bit32.btest(oneStepU, piecesU) then
						-- can move double
						oneStepL += bit32.lshift(1, pos-17)
						oneStepU += bit32.lshift(1, pos-49)
					end
					pieceMovesLower[pos] = bit32.band(pieceMovesLower[pos], bit32.band(moves.darkPawnAttackL[pos], piecesL+enPassantTargetL) + bit32.band(oneStepL, bit32.bnot(piecesL)))
					pieceMovesUpper[pos] = bit32.band(pieceMovesUpper[pos], bit32.band(moves.darkPawnAttackU[pos], piecesU+enPassantTargetU) + bit32.band(oneStepU, bit32.bnot(piecesU)))
				else
					local oneStepL, oneStepU = bit32.lshift(1, pos+7), bit32.lshift(1, pos-25)	-- native: using bit shifts instead of precomputed move lookups seems to be slightly faster
					if pos <= 16 and not bit32.btest(oneStepL, piecesL) then
						-- can move double
						oneStepL += bit32.lshift(1, pos+15)
						oneStepU += bit32.lshift(1, pos-18)
					end
					pieceMovesLower[pos] = bit32.band(pieceMovesLower[pos], bit32.band(moves.lightPawnAttackL[pos], piecesL+enPassantTargetL) + bit32.band(oneStepL, bit32.bnot(piecesL)))
					pieceMovesUpper[pos] = bit32.band(pieceMovesUpper[pos], bit32.band(moves.lightPawnAttackU[pos], piecesU+enPassantTargetU) + bit32.band(oneStepU, bit32.bnot(piecesU)))
				end
			elseif piece == 5 then
				blockersL, blockersU = bit32.band(moves.rookMaskL[pos],piecesL), bit32.band(moves.rookMaskU[pos],piecesU)
				index = blockersL * 31 + blockersU * 3	-- really cool function: TOOK ME HOURS | 3 and 31 are one of the only numbers that allow for index calculation that does not overlap with other blocker arrangements
				pieceMovesLower[pos], pieceMovesUpper[pos] = bit32.band(pieceMovesLower[pos], moves.rookMovesL[pos][index]), bit32.band(pieceMovesUpper[pos], moves.rookMovesU[pos][index])
			elseif piece == 6 then
				blockersL, blockersU = bit32.band(moves.bishopMaskL[pos],piecesL), bit32.band(moves.bishopMaskU[pos],piecesU)
				index = blockersL + blockersU//2
				pieceMovesLower[pos], pieceMovesUpper[pos] = bit32.band(pieceMovesLower[pos], moves.bishopMovesL[pos][index]), bit32.band(pieceMovesUpper[pos], moves.bishopMovesU[pos][index])
			elseif piece == 7 then
				blockersL, blockersU = bit32.band(moves.rookMaskL[pos],piecesL), bit32.band(moves.rookMaskU[pos],piecesU)
				local index2 = blockersL * 31 + blockersU * 3	-- really cool function: TOOK ME HOURS | 3 and 31 are one of the only numbers that allow for index calculation that does not overlap with other blocker arrangements
				blockersL, blockersU = bit32.band(moves.bishopMaskL[pos],piecesL), bit32.band(moves.bishopMaskU[pos],piecesU)
				index = blockersL + blockersU//2
				pieceMovesLower[pos], pieceMovesUpper[pos] = bit32.band(pieceMovesLower[pos], moves.rookMovesL[pos][index2] + moves.bishopMovesL[pos][index]), bit32.band(pieceMovesUpper[pos], moves.rookMovesU[pos][index2] + moves.bishopMovesU[pos][index])
			end
		else
			if piece == 1 then		-- king
				enemyAttacksL = bit32.bor(enemyAttacksL, moves.kingAttacksL[pos])
				enemyAttacksU = bit32.bor(enemyAttacksU, moves.kingAttacksU[pos])
			elseif piece == 2 then	-- knight
				attacksL, attacksU = moves.knightAttacksL[pos], moves.knightAttacksU[pos]
				enemyAttacksL = bit32.bor(enemyAttacksL, attacksL)
				enemyAttacksU = bit32.bor(enemyAttacksU, attacksU)
				
				if bit32.btest(attacksL, myKingBBL) or bit32.btest(attacksU, myKingBBU) then
					incheck = true
					
					limitMovesForChecksL, limitMoveForChecksU = bit32.band(limitMovesForChecksL, posBbL), bit32.band(limitMoveForChecksU, posBbU)
				end
			elseif piece == 3 then	-- pawn
				if color == 0 then
					attacksL, attacksU = moves.darkPawnAttackL[pos], moves.darkPawnAttackU[pos]
				else
					attacksL, attacksU = moves.lightPawnAttackL[pos], moves.lightPawnAttackU[pos]
				end
				
				enemyAttacksL = bit32.bor(enemyAttacksL, attacksL)
				enemyAttacksU = bit32.bor(enemyAttacksU, attacksU)
				pawnAttacksL = bit32.bor(pawnAttacksL, attacksL)
				pawnAttacksU = bit32.bor(pawnAttacksU, attacksU)
				
				if bit32.btest(attacksL, myKingBBL) or bit32.btest(attacksU, myKingBBU) then
					incheck = true
					if enPassantPiece == pos then
						canEnpassantOnCheck = true
						limitMovesForChecksL, limitMoveForChecksU = bit32.band(limitMovesForChecksL, posBbL), bit32.band(limitMoveForChecksU, posBbU)
					else
						limitMovesForChecksL, limitMoveForChecksU = bit32.band(limitMovesForChecksL, posBbL), bit32.band(limitMoveForChecksU, posBbU)
					end
				end
			elseif piece == 5 then	-- rook
				blockersL, blockersU = bit32.band(moves.rookMaskL[pos],piecesNoMyKingL), bit32.band(moves.rookMaskU[pos],piecesNoMyKingU)
				index = blockersL * 31 + blockersU * 3	-- really cool function: TOOK ME HOURS | 3 and 31 are one of the only numbers that allow for index calculation that does not overlap with other blocker arrangements
				attacksL, attacksU = moves.rookMovesL[pos][index], moves.rookMovesU[pos][index]
				enemyAttacksL, enemyAttacksU = bit32.bor(enemyAttacksL, attacksL), bit32.bor(enemyAttacksU, attacksU)
				
				if bit32.btest(attacksL, myKingBBL) or bit32.btest(attacksU, myKingBBU) then
					incheck = true
					
					-- current, the possible attacks IF the king IS there needs to be recalculated to find the legal check blocking moves
					blockersL, blockersU = bit32.band(moves.rookMaskL[pos],piecesL), bit32.band(moves.rookMaskU[pos],piecesU)	-- TODO fix this so that its more efficient
					index = blockersL * 31 + blockersU * 3	-- really cool function: TOOK ME HOURS | 3 and 31 are one of the only numbers that allow for index calculation that does not overlap with other blocker arrangements
					attacksL, attacksU = moves.rookMovesL[pos][index], moves.rookMovesU[pos][index]
					
					limitMovesForChecksL, limitMoveForChecksU = bit32.band(limitMovesForChecksL, bit32.band(attacksL+posBbL, kingRookPinL)), bit32.band(limitMoveForChecksU, bit32.band(attacksU+posBbU, kingRookPinU))
					continue
				end

				-- pin detection

				local drank, dfile = (pos-1)//8, (pos-1)%8

				if drank == myKingRank or dfile == myKingFile then
					pinMaskL, pinMaskU = bit32.band(attacksL, kingRookPinL), bit32.band(attacksU, kingRookPinU)	-- TODO: optimize this
					blockersL, blockersU = bit32.band(pinMaskL, piecesL), bit32.band(pinMaskU, piecesU)
					
					local tzerosL, tzerosU = bit32.countrz(blockersL), bit32.countrz(blockersU)
					if tzerosU == 32 and bit32.countlz(blockersL) + tzerosL == 31 then	-- pin occured in lower half of board
						tzerosL += 1
						pieceMovesLower[tzerosL],pieceMovesUpper[tzerosL] = bit32.band(pieceMovesLower[tzerosL], bit32.bor(posBbL,bit32.band(kingRookMaskL, moves.rookMaskL[pos]))), bit32.band(pieceMovesUpper[tzerosL], bit32.bor(posBbU,bit32.band(kingRookMaskU, moves.rookMaskU[pos])))
					elseif tzerosL == 32 and bit32.countlz(blockersU) + tzerosU == 31 then	-- pin occured in upper half of board
						tzerosU += 33
						pieceMovesLower[tzerosU],pieceMovesUpper[tzerosU] = bit32.band(pieceMovesLower[tzerosU], bit32.bor(posBbL,bit32.band(kingRookMaskL, moves.rookMaskL[pos]))), bit32.band(pieceMovesUpper[tzerosU], bit32.bor(posBbU,bit32.band(kingRookMaskU, moves.rookMaskU[pos])))
						
					elseif enPassantTarget > 0 and drank == enPassantPieceRank then
						local index2 = bit32.band(kingRookMaskL, piecesL, enPassantPieceL) *31 + bit32.band(kingRookMaskU, piecesU, enPassantPieceU) *3 	-- really cool function: TOOK ME HOURS | 3 and 31 are one of the only numbers that allow for index calculation that does not overlap with other blocker arrangements

						index = bit32.band(moves.rookMaskL[pos], piecesL, enPassantPieceL) * 31 + bit32.band(moves.rookMaskU[pos], piecesU, enPassantPieceU) * 3	-- really cool function: TOOK ME HOURS | 3 and 31 are one of the only numbers that allow for index calculation that does not overlap with other blocker arrangements
						attacksL, attacksU = moves.rookMovesL[pos][index], moves.rookMovesU[pos][index]
						
						pinMaskL, pinMaskU = bit32.band(attacksL, moves.rookMovesL[myKing][index2]), bit32.band(attacksU, moves.rookMovesU[myKing][index2])	-- TODO: optimize this
						blockersL, blockersU = bit32.band(pinMaskL, piecesL), bit32.band(pinMaskU, piecesU)
						
						tzerosL, tzerosU = bit32.countrz(blockersL), bit32.countrz(blockersU)
						if tzerosU == 32 and bit32.countlz(blockersL) + tzerosL == 31 then	-- pin occured in lower half of board
							tzerosL += 1
							if math.abs(enPassantPiece-tzerosL) == 1 then
								enPassantAllowed = false
							end
						elseif tzerosL == 32 and bit32.countlz(blockersU) + tzerosU == 31 then	-- pin occured in upper half of board
							tzerosU += 33
							if math.abs(enPassantPiece-tzerosU) == 1 then
								enPassantAllowed = false
							end
						end
					end
				end
			elseif piece == 6 then	-- bishop
				blockersL, blockersU = bit32.band(moves.bishopMaskL[pos],piecesNoMyKingL), bit32.band(moves.bishopMaskU[pos],piecesNoMyKingU)
				index = blockersL + blockersU//2
				attacksL = moves.bishopMovesL[pos][index]
				attacksU = moves.bishopMovesU[pos][index]
				enemyAttacksL, enemyAttacksU = bit32.bor(enemyAttacksL, attacksL), bit32.bor(enemyAttacksU, attacksU)
				
				
				-- check detection
				if bit32.btest(attacksL, myKingBBL) or bit32.btest(attacksU, myKingBBU) then
					incheck = true
					
					-- current, the possible attacks IF the king IS there needs to be recalculated to find the legal check blocking moves
					blockersL, blockersU = bit32.band(moves.bishopMaskL[pos],piecesL), bit32.band(moves.bishopMaskU[pos],piecesU)	-- TODO fix this so that its more efficient
					index = blockersL + blockersU//2
					attacksL, attacksU = moves.bishopMovesL[pos][index], moves.bishopMovesU[pos][index]
					
					-- intersection between king and bishop's diagonal moves, plus the bishops position bb, gives the legal moves available to get out of check
					limitMovesForChecksL, limitMoveForChecksU = bit32.band(limitMovesForChecksL, bit32.band(attacksL+posBbL, kingBishopPinL)), bit32.band(limitMoveForChecksU, bit32.band(attacksU+posBbU, kingBishopPinU))
					continue
				end
				
				-- pin detection
				
				local drank, dfile = (pos-1)//8 - myKingRank, (pos-1)%8 - myKingFile	-- computing difference between piece's file/rank and kings
				
				if math.abs(drank) == math.abs(dfile) then	-- native: using math.abs is faster than using the equal expression (rank == file or rank == -file)
					-- if |difference rank| == |difference file| then the 2 pieces must share a diagonal
					
					--print("possible pin detected")
					
					pinMaskL, pinMaskU = bit32.band(attacksL, kingBishopPinL), bit32.band(attacksU, kingBishopPinU)
					blockersL, blockersU = bit32.band(pinMaskL, piecesL), bit32.band(pinMaskU, piecesU)
					local tzerosL, tzerosU = bit32.countrz(blockersL), bit32.countrz(blockersU)
					if tzerosU == 32 and bit32.countlz(blockersL) + tzerosL == 31 then
						-- there is a single piece in between king and bishop
						tzerosL += 1
						pieceMovesLower[tzerosL],pieceMovesUpper[tzerosL] = bit32.band(pieceMovesLower[tzerosL], bit32.bor(posBbL,bit32.band(kingBishopMaskL, moves.bishopMaskL[pos]))), bit32.band(pieceMovesUpper[tzerosL], bit32.bor(posBbU,bit32.band(kingBishopMaskU, moves.bishopMaskU[pos])))
						
					elseif tzerosL == 32 and bit32.countlz(blockersU) + tzerosU == 31 then
						-- there is a single piece in between king and bishop
						tzerosU += 33
						
						pieceMovesLower[tzerosU],pieceMovesUpper[tzerosU] = bit32.band(pieceMovesLower[tzerosU], bit32.bor(posBbL,bit32.band(kingBishopMaskL, moves.bishopMaskL[pos]))), bit32.band(pieceMovesUpper[tzerosU], bit32.bor(posBbU,bit32.band(kingBishopMaskU, moves.bishopMaskU[pos])))
					end
				end
				
			elseif piece == 7 then	-- queen
				blockersL, blockersU = bit32.band(moves.rookMaskL[pos],piecesNoMyKingL), bit32.band(moves.rookMaskU[pos],piecesNoMyKingU)
				index = blockersL * 31 + blockersU * 3	-- really cool function: TOOK ME HOURS | 3 and 31 are one of the only numbers that allow for index calculation that does not overlap with other blocker arrangements
				attacksL, attacksU = moves.rookMovesL[pos][index], moves.rookMovesU[pos][index]
				enemyAttacksL, enemyAttacksU = bit32.bor(enemyAttacksL, attacksL), bit32.bor(enemyAttacksU, attacksU)
				
				local drank, dfile = (pos-1)//8, (pos-1)%8
				
				if bit32.btest(attacksL, myKingBBL) or bit32.btest(attacksU, myKingBBU) then
					incheck = true
					
					-- current, the possible attacks IF the king IS there needs to be recalculated to find the legal check blocking moves
					blockersL, blockersU = bit32.band(moves.rookMaskL[pos],piecesL), bit32.band(moves.rookMaskU[pos],piecesU)	-- TODO fix this so that its more efficient
					index = blockersL * 31 + blockersU * 3	-- really cool function: TOOK ME HOURS | 3 and 31 are one of the only numbers that allow for index calculation that does not overlap with other blocker arrangements
					attacksL, attacksU = moves.rookMovesL[pos][index], moves.rookMovesU[pos][index]

					limitMovesForChecksL, limitMoveForChecksU = bit32.band(limitMovesForChecksL, bit32.band(attacksL+posBbL, kingRookPinL)), bit32.band(limitMoveForChecksU, bit32.band(attacksU+posBbU, kingRookPinU))
				else

					-- pin detection

					

					if drank == myKingRank or dfile == myKingFile then
						pinMaskL, pinMaskU = bit32.band(attacksL, kingRookPinL), bit32.band(attacksU, kingRookPinU)	-- TODO: optimize this
						blockersL, blockersU = bit32.band(pinMaskL, piecesL), bit32.band(pinMaskU, piecesU)

						local tzerosL, tzerosU = bit32.countrz(blockersL), bit32.countrz(blockersU)
						if tzerosU == 32 and bit32.countlz(blockersL) + tzerosL == 31 then	-- pin occured in lower half of board
							tzerosL += 1
							pieceMovesLower[tzerosL],pieceMovesUpper[tzerosL] = bit32.band(pieceMovesLower[tzerosL], bit32.bor(posBbL,bit32.band(kingRookMaskL, moves.rookMaskL[pos]))), bit32.band(pieceMovesUpper[tzerosL], bit32.bor(posBbU,bit32.band(kingRookMaskU, moves.rookMaskU[pos])))
						elseif tzerosL == 32 and bit32.countlz(blockersU) + tzerosU == 31 then	-- pin occured in upper half of board
							tzerosU += 33
							pieceMovesLower[tzerosU],pieceMovesUpper[tzerosU] = bit32.band(pieceMovesLower[tzerosU], bit32.bor(posBbL,bit32.band(kingRookMaskL, moves.rookMaskL[pos]))), bit32.band(pieceMovesUpper[tzerosU], bit32.bor(posBbU,bit32.band(kingRookMaskU, moves.rookMaskU[pos])))

						elseif enPassantTarget > 0 and drank == enPassantPieceRank then
							local index2 = bit32.band(kingRookMaskL, piecesL, enPassantPieceL) *31 + bit32.band(kingRookMaskU, piecesU, enPassantPieceU) *3 	-- really cool function: TOOK ME HOURS | 3 and 31 are one of the only numbers that allow for index calculation that does not overlap with other blocker arrangements

							index = bit32.band(moves.rookMaskL[pos], piecesL, enPassantPieceL) * 31 + bit32.band(moves.rookMaskU[pos], piecesU, enPassantPieceU) * 3	-- really cool function: TOOK ME HOURS | 3 and 31 are one of the only numbers that allow for index calculation that does not overlap with other blocker arrangements
							attacksL, attacksU = moves.rookMovesL[pos][index], moves.rookMovesU[pos][index]

							pinMaskL, pinMaskU = bit32.band(attacksL, moves.rookMovesL[myKing][index2]), bit32.band(attacksU, moves.rookMovesU[myKing][index2])	-- TODO: optimize this
							blockersL, blockersU = bit32.band(pinMaskL, piecesL), bit32.band(pinMaskU, piecesU)

							tzerosL, tzerosU = bit32.countrz(blockersL), bit32.countrz(blockersU)
							if tzerosU == 32 and bit32.countlz(blockersL) + tzerosL == 31 then	-- pin occured in lower half of board
								tzerosL += 1
								if math.abs(enPassantPiece-tzerosL) == 1 then
									enPassantAllowed = false
								end
							elseif tzerosL == 32 and bit32.countlz(blockersU) + tzerosU == 31 then	-- pin occured in upper half of board
								tzerosU += 33
								if math.abs(enPassantPiece-tzerosU) == 1 then
									enPassantAllowed = false
								end
							end
						end
					end
				end
				
				
				
				blockersL, blockersU = bit32.band(moves.bishopMaskL[pos],piecesNoMyKingL), bit32.band(moves.bishopMaskU[pos],piecesNoMyKingU)
				index = blockersL + blockersU//2
				attacksL, attacksU = moves.bishopMovesL[pos][index], moves.bishopMovesU[pos][index]
				enemyAttacksL, enemyAttacksU = bit32.bor(enemyAttacksL, attacksL), bit32.bor(enemyAttacksU, attacksU)
				
				if bit32.btest(attacksL, myKingBBL) or bit32.btest(attacksU, myKingBBU) then
					incheck = true
					
					-- current, the possible attacks IF the king IS there needs to be recalculated to find the legal check blocking moves
					blockersL, blockersU = bit32.band(moves.bishopMaskL[pos],piecesL), bit32.band(moves.bishopMaskU[pos],piecesU)	-- TODO fix this so that its more efficient
					index = blockersL + blockersU//2
					attacksL, attacksU = moves.bishopMovesL[pos][index], moves.bishopMovesU[pos][index]
					
					-- intersection between king and bishop's diagonal moves, plus the bishops position bb, gives the legal moves available to get out of check
					limitMovesForChecksL, limitMoveForChecksU = bit32.band(limitMovesForChecksL, bit32.band(attacksL+posBbL, kingBishopPinL)), bit32.band(limitMoveForChecksU, bit32.band(attacksU+posBbU, kingBishopPinU))
					continue
				end

				-- pin detection

				if math.abs(drank-myKingRank) == math.abs(dfile-myKingFile) then	-- native: using math.abs is faster than using the equal expression (rank == file or rank == -file)
					-- if |difference rank| == |difference file| then the 2 pieces must share a diagonal

					pinMaskL, pinMaskU = bit32.band(attacksL, kingBishopPinL), bit32.band(attacksU, kingBishopPinU)
					blockersL, blockersU = bit32.band(pinMaskL, piecesL), bit32.band(pinMaskU, piecesU)
					local tzerosL, tzerosU = bit32.countrz(blockersL), bit32.countrz(blockersU)
					if tzerosU == 32 and bit32.countlz(blockersL) + tzerosL == 31 then
						-- there is a single piece in between king and bishop
						tzerosL += 1
						pieceMovesLower[tzerosL],pieceMovesUpper[tzerosL] = bit32.band(pieceMovesLower[tzerosL], bit32.bor(posBbL,bit32.band(kingBishopMaskL, moves.bishopMaskL[pos]))), bit32.band(pieceMovesUpper[tzerosL], bit32.bor(posBbU,bit32.band(kingBishopMaskU, moves.bishopMaskU[pos])))

					elseif tzerosL == 32 and bit32.countlz(blockersU) + tzerosU == 31 then
						-- there is a single piece in between king and bishop
						tzerosU += 33
						pieceMovesLower[tzerosU],pieceMovesUpper[tzerosU] = bit32.band(pieceMovesLower[tzerosU], bit32.bor(posBbL,bit32.band(kingBishopMaskL, moves.bishopMaskL[pos]))), bit32.band(pieceMovesUpper[tzerosU], bit32.bor(posBbU,bit32.band(kingBishopMaskU, moves.bishopMaskU[pos])))
					end
				end
				
				
			end
		end
	end
	
	-- special moves:
	-- 1 = en passant
	-- 2, 5, 6, 7 = promotions (numbers represent pieces that will replace pawn)
	-- 11 = castle queen side
	-- 12 = castle king side
	
	pieceMovesLower[myKing] = bit32.band(pieceMovesLower[myKing],bit32.bnot(bit32.bor(mySideL,enemyAttacksL)))
	pieceMovesUpper[myKing] = bit32.band(pieceMovesUpper[myKing],bit32.bnot(bit32.bor(mySideU,enemyAttacksU)))


	local totalMoves = 0
	local results = table.create(60,0)
	local moveScores = table.create(60,0)
	
	if incheck == false then
		if sideToMove == 0 and myKing == 61 then -- blacks turn to move and king is on home square
			-- applying castling rights mask
			local kingMovesU = bit32.band(pieceMovesUpper[myKing], moves.castlingRightsMaskU[self.castlingRights+1])
			
			-- adding the castling moves and clearing the castling moves from the king moves
			if bit32.band(kingMovesU, 201326592) == 201326592 and not bit32.btest(piecesU,234881024) then
				totalMoves += 1
				results[totalMoves] = Vector3.new(61, 59, 11)
			end
			if bit32.band(kingMovesU, 1610612736) == 1610612736 and not bit32.btest(piecesU,1610612736) then
				totalMoves += 1
				results[totalMoves] = Vector3.new(61, 63, 12)
			end
		elseif sideToMove ~= 0 and myKing == 5 then	-- whites turn to move and king is on home square
			-- applying castling rights mask
			local kingMovesL = bit32.band(pieceMovesLower[myKing], moves.castlingRightsMaskL[self.castlingRights+1])

			-- adding the castling moves and clearing the castling moves from the king moves
			if bit32.band(kingMovesL, 12) == 12 and not bit32.btest(piecesL,14) then
				totalMoves += 1
				results[totalMoves] = Vector3.new(5, 3, 11)
			end
			if bit32.band(kingMovesL, 96) == 96 and not bit32.btest(piecesL,96) then
				totalMoves += 1
				results[totalMoves] = Vector3.new(5, 7, 12)
			end
		end
		if myKing == 5 then
			pieceMovesLower[myKing] = bit32.band(pieceMovesLower[myKing], 14376)
		elseif myKing == 61 then
			pieceMovesUpper[myKing] = bit32.band(pieceMovesUpper[myKing], 674758656)
		end
	else
		if myKing == 61 then
			pieceMovesUpper[myKing] = bit32.band(pieceMovesUpper[myKing], 674758656)
		elseif myKing == 5 then
			pieceMovesLower[myKing] = bit32.band(pieceMovesLower[myKing], 14376)
		end
	end
	
	
	
	--print(enemyAttacksL, enemyAttacksU)
	--warn(pieceMovesLower, pieceMovesUpper)
	--warn("en passant allowed: ", enPassantAllowed)
	--warn("in check: ", incheck)
	--warn("limitted moves: ")
	local score
	
	local hashedMove = self:TTgetMove(self.hash)
	
	for pos, piece in self.board do
		if piece > 0 and piece//8 * 8 == sideToMove then	-- native: that same trick again as explained above
			local bbl, bbu = pieceMovesLower[pos], pieceMovesUpper[pos]
			piece %= 8
			if incheck then
				if piece == 3 and canEnpassantOnCheck then
					bbl, bbu = bit32.band(bbl, limitMovesForChecksL + enPassantTargetL), bit32.band(bbu, limitMoveForChecksU + enPassantTargetU)
				elseif piece ~= 1 then
					bbl, bbu = bit32.band(bbl, limitMovesForChecksL), bit32.band(bbu, limitMoveForChecksU)
				end
			end
			
			local ispawn = piece == 3
			
			local c = 0
			while bbl > 0 do
				local newC = bit32.countrz(bbl)+1
				c+=newC
				bbl = bit32.rshift(bbl, newC)
				
				if onlyCaptures and self.board[c] == 0 then continue end
				
				score = 0
				if self.board[c] > 0 then
					score += 1000 + 10*PieceValues[self.board[c]] - PieceValues[piece]
				end
				
				if bit32.btest(pawnAttacksU, bit32.lshift(1, c-1)) then
					score -= PieceValues[piece]
				end
				
				score += piecePositionBonuses[piece][c] - piecePositionBonuses[piece][pos]	-- TODO: maybe add this back later?
				
				
				if ispawn and c <= 8 then
					totalMoves += 4
					
					results[totalMoves] = Vector3.new(pos, c, 2)
					moveScores[totalMoves] = score + 300
					results[totalMoves-1] = Vector3.new(pos, c, 5)
					moveScores[totalMoves-1] = score + 500
					results[totalMoves-2] = Vector3.new(pos, c, 6)
					moveScores[totalMoves-2] = score + 320
					results[totalMoves-3] = Vector3.new(pos, c, 7)
					moveScores[totalMoves-3] = score + 900
					
					if results[totalMoves-1] == hashedMove then	-- prob gonna be a good move: should search this first
						moveScores[totalMoves-1] += 100000
					elseif results[totalMoves-2] == hashedMove then	-- prob gonna be a good move: should search this first
						moveScores[totalMoves-2] += 100000
					elseif results[totalMoves-3] == hashedMove then	-- prob gonna be a good move: should search this first
						moveScores[totalMoves-3] += 100000
					end
				elseif ispawn and c == enPassantTarget then
					if enPassantAllowed then
						totalMoves += 1
						results[totalMoves] = Vector3.new(pos, c, 1)
						moveScores[totalMoves] = score
					end
					-- if en passant isnt allowed, trash this move
				else
					totalMoves += 1
					results[totalMoves] = Vector3.new(pos, c)
					moveScores[totalMoves] = score
				end
				
				if noSort then continue end	-- need to continue, because if this function is called not in a search (no sorting required), there is no ply variable
				
				if results[totalMoves] == hashedMove then	-- prob gonna be a good move: should search this first
					moveScores[totalMoves] += 100000
				elseif results[totalMoves] == self.killerMoves[ply*2 + 1] then
					moveScores[totalMoves] += 9000
				elseif results[totalMoves] == self.killerMoves[ply*2 + 2] then
					moveScores[totalMoves] += 8000
				end
			end
			
			c = 32
			while bbu > 0 do
				local newC = bit32.countrz(bbu)+1
				c+=newC
				bbu = bit32.rshift(bbu, newC)

				if onlyCaptures and self.board[c] == 0 then continue end
				
				score = 0
				if self.board[c] > 0 then
					score += 1000 + 10*PieceValues[self.board[c]] - PieceValues[piece]
				end
				
				if bit32.btest(pawnAttacksU, bit32.lshift(1, c-33)) then
					score -= PieceValues[piece]
				end

				score += piecePositionBonuses[piece][c] - piecePositionBonuses[piece][pos]	-- TODO: maybe add this back later?
				
				if ispawn and c > 56 then
					totalMoves += 4
					
					results[totalMoves] = Vector3.new(pos, c, 2)
					moveScores[totalMoves] = score + 300
					results[totalMoves-1] = Vector3.new(pos, c, 5)
					moveScores[totalMoves-1] = score + 500
					results[totalMoves-2] = Vector3.new(pos, c, 6)
					moveScores[totalMoves-2] = score + 320
					results[totalMoves-3] = Vector3.new(pos, c, 7)
					moveScores[totalMoves-3] = score + 900
					
					if results[totalMoves-1] == hashedMove then	-- prob gonna be a good move: should search this first
						moveScores[totalMoves-1] += 100000
					elseif results[totalMoves-2] == hashedMove then	-- prob gonna be a good move: should search this first
						moveScores[totalMoves-2] += 100000
					elseif results[totalMoves-3] == hashedMove then	-- prob gonna be a good move: should search this first
						moveScores[totalMoves-3] += 100000
					end
				elseif ispawn and c == enPassantTarget then
					if enPassantAllowed then
						totalMoves += 1
						results[totalMoves] = Vector3.new(pos, c, 1)
						moveScores[totalMoves] = score
					end
					-- if en passant isnt allowed, trash this move
				else
					totalMoves += 1
					results[totalMoves] = Vector3.new(pos, c)
					moveScores[totalMoves] = score
				end

				if noSort then continue end	-- need to continue, because if this function is called not in a search (no sorting required), there is no ply variable

				if results[totalMoves] == hashedMove then	-- prob gonna be a good move: should search this first
					moveScores[totalMoves] += 100000
				elseif results[totalMoves] == self.killerMoves[ply*2 + 1] then
					moveScores[totalMoves] += 9000
				elseif results[totalMoves] == self.killerMoves[ply*2 + 2] then
					moveScores[totalMoves] += 8000
				end
			end
			
		end
	end
	
	
	if noSort then
		return results, totalMoves, incheck
	end
	
	for pass = 1, totalMoves - 1 do
		for j = 1, totalMoves - pass do
			if moveScores[j] < moveScores[j + 1] then
				-- Swap elements in score array
				moveScores[j], moveScores[j + 1] = moveScores[j + 1], moveScores[j]

				-- Swap corresponding elements in arr array
				results[j], results[j + 1] = results[j + 1], results[j]
			end
		end
	end
	-- TODO: make a faster sorting algorithm (maybe selection sort?)
	-- even though selection sort is O(n^2), it doesnt have to be completed all at once. when the moves
	-- are searched, the best moves can be sorted out first, and if theres a beta cutoff,
	-- the sort does not even have to finish, making selection sort faster.
	
	
	return results, totalMoves, incheck
end

@native
function engine:makeMove(move)
	local piece = self.board[move.X]
	local i = self.totalMoves * 10
	self.moveLog[i  ] = move
	self.moveLog[i+1] = self.board[move.Y]
	self.moveLog[i+2] = self.castlingRights
	self.moveLog[i+3] = self.enPassantTarget
	self.moveLog[i+4] = self.halfTimeClock
	self.moveLog[i+5] = self.darkL
	self.moveLog[i+6] = self.darkU
	self.moveLog[i+7] = self.lightL
	self.moveLog[i+8] = self.lightU
	self.moveLog[i+9] = self.hash

	--self.moveLog[self.totalMoves] = {move, self.board[move.Y], self.castlingRights, self.enPassantTarget, self.halfTimeClock, self.darkL, self.darkU, self.lightL, self.lightU, self.hash}

	
	if self.board[move.Y] > 0 then
		self.hash = bit32.bxor(self.hash,self.pieceZobristKeys[move.Y][self.board[move.Y]], self.pieceZobristKeys[move.X][piece], self.pieceZobristKeys[move.Y][piece], self.sideToMoveZobristKey)
	else
		self.hash = bit32.bxor(self.hash,self.pieceZobristKeys[move.X][piece], self.pieceZobristKeys[move.Y][piece], self.sideToMoveZobristKey)
	end

	self.board[move.Y] = piece
	self.board[move.X] = 0
	

	local toL, toU, fromL, fromU = bit32.lshift(1, move.Y-1), bit32.lshift(1, move.Y-33), bit32.lshift(1, move.X-1), bit32.lshift(1, move.X-33)
	
	if self.sideToMove == 0 then
		self.darkL = bit32.bor(bit32.band(self.darkL, bit32.bnot(fromL)), toL)
		self.darkU = bit32.bor(bit32.band(self.darkU, bit32.bnot(fromU)), toU)
		self.lightL = bit32.band(self.lightL, bit32.bnot(toL))
		self.lightU = bit32.band(self.lightU, bit32.bnot(toU))
	else
		self.lightL = bit32.bor(bit32.band(self.lightL, bit32.bnot(fromL)), toL)
		self.lightU = bit32.bor(bit32.band(self.lightU, bit32.bnot(fromU)), toU)
		self.darkL = bit32.band(self.darkL, bit32.bnot(toL))
		self.darkU = bit32.band(self.darkU, bit32.bnot(toU))
	end
	
	if self.enPassantTarget > 0 then
		self.hash = bit32.bxor(self.hash, self.enPassantZobristKeys[65], self.enPassantZobristKeys[self.enPassantTarget])
	end
	
	self.halfTimeClock += 1
	self.enPassantTarget = 0
	

	if move.Z == 0 then			-- normal move
		if piece == 3 then
			if move.X - move.Y == 16 then
				self.enPassantTarget = move.X - 8
				self.hash = bit32.bxor(self.hash, self.enPassantZobristKeys[65], self.enPassantZobristKeys[self.enPassantTarget])
			end
			self.halfTimeClock = 0
		elseif piece == 11 then
			if move.Y - move.X == 16 then
				self.enPassantTarget = move.X + 8
				self.hash = bit32.bxor(self.hash, self.enPassantZobristKeys[65], self.enPassantZobristKeys[self.enPassantTarget])
			end
			self.halfTimeClock = 0
		elseif piece == 1 then
			self.darkKing = move.Y
			self.halfTimeClock = 0
		elseif piece == 9 then
			self.lightKing = move.Y
			self.halfTimeClock = 0
		end
	elseif move.Z == 1 then		-- en passant
		if piece == 3 then
			self.lightL = bit32.band(self.lightL, bit32.bnot(bit32.lshift(toL,8)))	-- native: bitshifting is slightly faster than multiplying by 256
			self.board[move.Y + 8] = 0
			self.hash = bit32.bxor(self.hash, self.pieceZobristKeys[move.Y + 8][11])
		else
			self.darkU = bit32.band(self.darkU, bit32.bnot(bit32.rshift(toU,8)))	-- native: bitshifting is slightly faster than multiplying by 256
			self.board[move.Y - 8] = 0
			self.hash = bit32.bxor(self.hash, self.pieceZobristKeys[move.Y - 8][3])
		end
		self.halfTimeClock = 0
	elseif move.Z == 11 then	-- castling queen side
		if piece == 1 then
			--self.board[61] = 0
			--self.board[59] = 1
			
			self.board[57] = 0
			self.board[60] = 5
			self.darkU = bit32.band(self.darkU, 3774873599) + 201326592
			self.darkKing = 59
			self.hash = bit32.bxor(self.hash, self.pieceZobristKeys[57][5], self.pieceZobristKeys[60][5])
		else
			--self.board[5] = 0
			--self.board[3] = 9
			
			self.board[1] = 0
			self.board[4] = 13
			self.lightL = bit32.band(self.lightL, 4294967264) + 12
			self.lightKing = 3
			self.hash = bit32.bxor(self.hash, self.pieceZobristKeys[1][13], self.pieceZobristKeys[4][13])
		end
		self.halfTimeClock = 0
	elseif move.Z == 12 then	-- castling king side
		if piece == 1 then
			--self.board[61] = 0
			--self.board[63] = 1

			self.board[64] = 0
			self.board[62] = 5
			self.darkU = bit32.band(self.darkU, 268435455) + 1610612736
			self.darkKing = 63
			self.hash = bit32.bxor(self.hash, self.pieceZobristKeys[62][5], self.pieceZobristKeys[64][5])
		else
			--self.board[5] = 0
			--self.board[7] = 9

			self.board[8] = 0
			self.board[6] = 13
			self.lightL = bit32.band(self.lightL, 4294967055) + 96
			self.lightKing = 7
			self.hash = bit32.bxor(self.hash, self.pieceZobristKeys[6][13], self.pieceZobristKeys[8][13])
		end
		self.halfTimeClock = 0
	else -- promotion
		self.board[move.Y] = move.Z + self.sideToMove
		self.halfTimeClock = 0
		self.hash = bit32.bxor(self.hash, self.pieceZobristKeys[move.Y][piece], self.pieceZobristKeys[move.Y][move.Z + self.sideToMove])
	end

	local oldRights = self.castlingRights
	
	self.castlingRights = bit32.band(self.castlingRights, moves.castlingRightsUpdater[move.X], moves.castlingRightsUpdater[move.Y])
	
	
	if self.castlingRights ~= oldRights then
		self.hash = bit32.bxor(self.hash, self.castlingRightsZobristKeys[oldRights+1], self.castlingRightsZobristKeys[self.castlingRights+1])
		self.halfTimeClock = 0
	end
	self.sideToMove = 8 - self.sideToMove
	self.totalMoves += 1
	
	self.positionHistory[self.hash] = (self.positionHistory[self.hash] or 0) + 1
end

@native
function engine:unmakeMove()
	self.positionHistory[self.hash] -= 1
	
	self.totalMoves -= 1
	self.sideToMove = 8 - self.sideToMove
	local i = self.totalMoves * 10
	--local move = self.moveLog[self.totalMoves]
	
	
	self.darkL = self.moveLog[i+5] --move[6]
	self.darkU = self.moveLog[i+6] --move[7]
	self.lightL = self.moveLog[i+7] --move[8]
	self.lightU = self.moveLog[i+8] --move[9]
	
	self.castlingRights = self.moveLog[i+2] --move[3]
	self.enPassantTarget = self.moveLog[i+3] --move[4]
	self.halfTimeClock = self.moveLog[i+4] --move[5]
	
	self.hash = self.moveLog[i+9] --move[10]
	
	local piece = self.moveLog[i+1] --move[2]
	
	local move = self.moveLog[i]
	
	self.board[move.X] = self.board[move.Y]
	self.board[move.Y] = piece
	
	piece = self.board[move.X]
	if move.Z == 0 then
		if piece == 1 then
			self.darkKing = move.X
		elseif piece == 9 then
			self.lightKing = move.X
		end
	elseif move.Z == 1 then
		if piece == 3 then
			self.board[move.Y + 8] = 11
		else
			self.board[move.Y - 8] = 3
		end
	elseif move.Z == 11 then
		if piece == 1 then
			--self.board[61] = 1
			--self.board[59] = 0

			self.board[57] = 5
			self.board[60] = 0
			
			self.darkKing = 61
		else
			--self.board[5] = 9
			--self.board[3] = 0

			self.board[1] = 13
			self.board[4] = 0
			
			self.lightKing = 5
		end
	elseif move.Z == 12 then
		if piece == 1 then
			--self.board[61] = 1
			--self.board[63] = 0

			self.board[64] = 5
			self.board[62] = 0

			self.darkKing = 61
		else
			--self.board[5] = 9
			--self.board[7] = 0

			self.board[8] = 13
			self.board[6] = 0

			self.lightKing = 5
		end
	else
		self.board[move.X] = 3 + self.sideToMove
	end
end

@native
function engine:perft(depth)
	if depth == 0 then return 1 end
	local legalMoves, numMoves, inCheck = self:_getLegalMoves(true)
	
	

	if #legalMoves == 0 and inCheck then
		self.checkmates += 1
		return 1
	end
	
	if self.nextBreakTime > 0 and self.nextBreakTime <= os.clock() then
		task.wait(0.1)
		self.nextBreakTime = os.clock()+2
	end

	local totalSum = 0

	for i,v in legalMoves do
		if i > numMoves then break end

		self:makeMove(v)
		totalSum += self:perft(depth-1)
		self:unmakeMove()
	end
	
	return totalSum
end

function engine:move2str(move)
	local fromFile, fromRank = (move.X-1) % 8, (move.X-1) // 8
	local toFile, toRank = (move.Y-1) % 8, (move.Y-1) // 8
	
	local str = string.char(97 + fromFile) .. (fromRank+1) .. string.char(97 + toFile) .. (toRank+1)
	
	if move.Z > 1 and move.Z < 8 then
		str..= ({"","n","","","r","b","q"})[move.Z]
	end
	
	return str
end
function engine:str2move(str)
	local a,_,b = string.byte(str,1,3)
	
	local fromFile, fromRank = a-97, tonumber(str:sub(2,2))
	local toFile, toRank = b-97, tonumber(str:sub(4,4))
	
	if fromFile and fromRank and toFile and toRank then
		local move = Vector3.new((fromRank-1)*8 + fromFile + 1, (toRank-1)*8 + toFile + 1)
		
		local moves, numMoves, _ = self:_getLegalMoves(true)
		for i = 1, numMoves do
			if moves[i].X == move.X and moves[i].Y == move.Y then
				if moves[i].Z <= 1 or moves[i].Z > 8 then
					return moves[i]
				end
				
				if ({"","n","","","r","b","q"})[moves[i].Z] == str:sub(5,5) then
					return moves[i]
				end
			end
		end
		error("Move does not exist")
	else
		error("Invalid notation")
	end
end
function formatNumber(num)
	local formatted = tostring(num):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	local str, _ = formatted:gsub("^,", "")
	return str
end

function engine:initializeZobristKeys()
	self.pieceZobristKeys = {}	-- [pos][pieceType]
	self.castlingRightsZobristKeys = {} -- [rights + 1]
	self.enPassantZobristKeys = {} -- [en passant target]

	self.hash = 0

	local rng = Random.new()

	for i = 1,64 do
		self.pieceZobristKeys[i] = {}
		for j = 1,15 do
			self.pieceZobristKeys[i][j] = rng:NextInteger(0,2^32-1)
		end
	end

	for i = 1,16 do
		self.castlingRightsZobristKeys[i] = rng:NextInteger(0,2^32-1)
	end

	for i = 1,65 do
		self.enPassantZobristKeys[i] = rng:NextInteger(0,2^32-1)
	end

	self.sideToMoveZobristKey = rng:NextInteger(0,2^32-1)
end

function engine:exportZobristKeys(): string
	local res = {self.pieceZobristKeys, self.castlingRightsZobristKeys, self.enPassantZobristKeys, self.sideToMoveZobristKey}
	
	return game:GetService("HttpService"):JSONEncode(res)
end

function engine:importZobristKeys(keys: string)
	local res = game:GetService("HttpService"):JSONDecode(keys)
	
	self.pieceZobristKeys = res[1]
	self.castlingRightsZobristKeys = res[2]
	self.enPassantZobristKeys = res[3]
	self.sideToMoveZobristKey = res[4]
end

function engine:generateZobristHash()
	self.hash = bit32.bxor(self.castlingRightsZobristKeys[self.castlingRights+1],if self.enPassantTarget == 0 then self.enPassantZobristKeys[65] else self.enPassantZobristKeys[self.enPassantTarget])
	for pos,piece in self.board do
		if piece == 0 then continue end
		self.hash = bit32.bxor(self.hash,self.pieceZobristKeys[pos][piece])
	end
end

function engine:initializeTranspositionTable(size)
	self.TT = table.create(size, 0)
	self.TTSize = size
	
	warn("Creating transposition table of with ".. formatNumber(size).." entries!")
	
	for i = 1, size do
		self.TT[i] = table.create(6, 0)
		self.TT[i][4] = Vector3.zero
	end
end

local TT_LOWER_BOUND = -1
local TT_EXACT = 0
local TT_UPPER_BOUND = 1

local TT_LOOKUP_FAILED = math.huge

function engine:TTstoreEvaluation(key, eval, matePly, move, depth, nodeType)
	local entry = self.TT[key%self.TTSize + 1]
	entry[1] = key
	entry[2] = eval
	entry[3] = matePly
	entry[4] = move
	entry[5] = depth
	entry[6] = nodeType
end

function engine:TTget(key)
	return self.TT[key%self.TTSize + 1]
end

function engine:TTgetMove(key)
	return self.TT[key%self.TTSize + 1][4]
end

function engine:TTclear()
	for i,v in self.TT do
		v[1] = 0
		v[2] = 0
		v[3] = 0
		v[4] = Vector3.zero
		v[5] = 0
		v[6] = -5
	end
end

function engine:TTlookupEval(key, depth, ply, alpha, beta)
	local entry = self.TT[key%self.TTSize + 1]

	if entry[1] == key and entry[5] >= depth then
		if entry[6] == 0 then	-- exact
			return entry[2], entry[3], entry[4]
		end
		if entry[6] == 1 and entry[2] <= alpha then	-- exact
			return entry[2], entry[3], entry[4]
		end
		if entry[6] == -1 and entry[2] >= beta then	-- exact
			return entry[2], entry[3], entry[4]
		end
	end

	return TT_LOOKUP_FAILED
end


function engine:resetCounters()
	self.cnt_trans = 0
	self.cnt_eval = 0
	self.cnt_pruned = 0
	self.cnt_maxd = -1
end


-----------------------------
-- Evaluation Function
-----------------------------



--[[
function Board:eval()
	self.countEvaled += 1
	
	if self.halfMoveClock >= 50 then
		return 0
	end
	-- [TAG] eval
	local whiteEval = 0
	local blackEval = 0
	
	local endGameSumWhite = 0
	local endGameSumBlack = 0

	local whiteMaterial = 0
	local blackMaterial = 0
	
	local whiteMobility = 0
	local blackMobility = 0
	
	local whiteEndGameEval = 0
	local blackEndGameEval = 0
	local whiteMiddleGameEval = 0
	local blackMiddleGameEval = 0
	
	
	for _,v in self.pieces do
		local piece = self.board[v]
		local pieceType = bit32.band(piece,7)
		
		if piece > 8 then
			local value = pieceValues[piece]
			whiteMaterial += value
			
			if pieceType == 1 then
				whiteMiddleGameEval += kingSquareBonus[v]
				whiteEndGameEval += kingSquareEndgameBonus[v]
			elseif pieceType == 3 then
				whiteMiddleGameEval += pawnSquareBonus[v]
				whiteEndGameEval += pawnSquareEndgameBonus[v]
whiteEval += piecePositionBonuses[pieceType][v]
endGameSumWhite += endGamePieceValues[pieceType]
end

else
	local value = pieceValues[piece]
	blackMaterial += value

	v = 65 - v

	if pieceType == 1 then
		blackMiddleGameEval += kingSquareBonus[v]
		blackEndGameEval += kingSquareEndgameBonus[v]
	elseif pieceType == 3 then
		blackMiddleGameEval += pawnSquareBonus[v]
		blackEndGameEval += pawnSquareEndgameBonus[v]
	else
		--print(pieceType,v)
		blackEval += piecePositionBonuses[pieceType][v]
		endGameSumBlack += endGamePieceValues[pieceType]
	end
end
end

whiteEval += whiteMaterial
blackEval += blackMaterial

local endGameMultiWhite = endGameSumWhite*endGameStartWeight
local endGameMultiBlack = endGameSumBlack*endGameStartWeight

whiteEval += endGameMultiWhite * whiteMiddleGameEval
blackEval += endGameMultiBlack * blackMiddleGameEval

whiteEval += self:endgameEval(self.lightKingPos-1,self.darkKingPos-1, whiteMaterial,blackMaterial,1-endGameMultiBlack,whiteEndGameEval)
blackEval += self:endgameEval(self.darkKingPos-1,self.lightKingPos-1, blackMaterial,whiteMaterial,1-endGameMultiWhite,blackEndGameEval)

if self.sideToMove == 0 then
	return blackEval-whiteEval
end
return whiteEval-blackEval
end
]]

local preComputedFiles = {}

for i = 1,8 do
	preComputedFiles[i] = bit32.lshift(0x1010101, i-1)
end


function engine:evaluate()
	self.cnt_eval += 1
	
	if (self.positionHistory[self.hash] or 0) >= 3 or self.halfTimeClock >= 50 then
		return 0
	end
	
	local whiteEval = 0
	local blackEval = 0

	local endGameSumWhite = 0
	local endGameSumBlack = 0

	local whiteMaterial = 0
	local blackMaterial = 0

	local whiteMobility = 0
	local blackMobility = 0

	local whiteEndGameEval = 0
	local blackEndGameEval = 0
	local whiteMiddleGameEval = 0
	local blackMiddleGameEval = 0
	
	--for i = 1, 8 do
	--	self.eval_pawnsOnFilesTableWhite[i] = 0
	--	self.eval_pawnsOnFilesTableBlack[i] = 0
	--end
	
	
	-- material and square bonus
	
	for pos, piece in ipairs(self.board) do
		if piece == 0 then continue end
		
		if piece > 8 then
			whiteMaterial += PieceValues[piece]

			if piece == 9 then
				whiteMiddleGameEval += kingSquareBonus[pos]
				whiteEndGameEval += kingSquareEndgameBonus[pos]
			elseif piece == 11 then
				whiteMiddleGameEval += pawnSquareBonus[pos]
				whiteEndGameEval += pawnSquareEndgameBonus[pos]
			else
				whiteEval += piecePositionBonuses[piece-8][pos]
				endGameSumWhite += endGamePieceValues[piece-8]
			end

		else
			blackMaterial += PieceValues[piece]

			if piece == 1 then
				blackMiddleGameEval += kingSquareBonus[pos]
				blackEndGameEval += kingSquareEndgameBonus[pos]
			elseif piece == 3 then
				blackMiddleGameEval += pawnSquareBonus[pos]
				blackEndGameEval += pawnSquareEndgameBonus[pos]
			else
				blackEval += piecePositionBonuses[piece][pos]
				endGameSumBlack += endGamePieceValues[piece]
			end
		end
	end

	whiteEval += whiteMaterial
	blackEval += blackMaterial
	
	
	-------- pawn structure -------
	
	--for file = 0, 7 do
	--	local mask = 0

	--	if self.eval_pawnsOnFilesTableWhite[file+1] > 0 then
	--		if self.eval_pawnsOnFilesTableWhite[file+1] > 1 then
	--			blackEval += 25
	--		end
	--		if file ~= 0 then
	--			mask += bit32.lshift(0x1010101, file-1)
	--		end
	--		if file ~= 7 then
	--			mask += bit32.lshift(0x1010101, file+1)
	--		end

	--		if not (bit32.btest(mask, whitePawnSquaresLower) or bit32.btest(mask, whitePawnSquaresUpper)) then
	--			blackEval += 30
	--		end
	--	end

	--	if self.eval_pawnsOnFilesTableBlack[file+1] > 0 then
	--		if self.eval_pawnsOnFilesTableBlack[file+1] > 1 then
	--			whiteEval += 25
	--		end

	--		mask = 0
	--		if file ~= 0 then
	--			mask += bit32.lshift(0x1010101, file-1)
	--		end
	--		if file ~= 7 then
	--			mask += bit32.lshift(0x1010101, file+1)
	--		end

	--		if not (bit32.btest(mask, blackPawnSquaresLower) or bit32.btest(mask, blackPawnSquaresUpper)) then
	--			whiteEval += 30
	--		end
	--	end
	--end
	

	local endGameMultiWhite = endGameSumWhite*endGameStartWeight
	local endGameMultiBlack = endGameSumBlack*endGameStartWeight

	whiteEval += endGameMultiWhite * whiteMiddleGameEval
	blackEval += endGameMultiBlack * blackMiddleGameEval

	whiteEval += self:endgameEval(self.lightKing-1,self.darkKing-1, whiteMaterial,blackMaterial,1-endGameMultiBlack,whiteEndGameEval)
	blackEval += self:endgameEval(self.darkKing-1,self.lightKing-1, blackMaterial,whiteMaterial,1-endGameMultiWhite,blackEndGameEval)

	if self.sideToMove == 0 then
		return blackEval-whiteEval
	end
	return whiteEval-blackEval
end

function engine:endgameEval(friendlyKingPos,opponentKingPos, material, enemyMaterial, enemyMulti,eval)
	if material > enemyMaterial + 200 and enemyMulti > 0 then
		
		-- endGameKingEval evaluates how close the enemy king is to the edge of the board, and how close the friendly king is to the enemy king
		return (eval+moves.endGameKingEval[friendlyKingPos*64 + opponentKingPos + 1]) * enemyMulti * 3
	end
	return 0
end

function engine:resetKillerMovesTable()
	for i = 1, 30*2 do -- pre allocating 30 depth for killer moves, for now
		self.killerMoves[i] = nil
	end
end

-----------------------------
-- Negamax Search with Alpha-Beta Pruning
-----------------------------
-- Main search function (recursive negamax)
function engine:search(depth, alpha, beta, startTime, timeLimit, ply)
	local tick = os.clock()
	if ply > self.cnt_maxd then
		self.cnt_maxd = ply
	elseif self.nextBreakTime > 0 and self.nextBreakTime <= tick then
		task.wait(0.1)
		self.nextBreakTime = os.clock()+2
	end
	
	-- Check for time cutoff
	if tick - startTime >= timeLimit then
		self.stopSearch = true
		return 0, -1
	end
	
	--##############################################################################################################
	-- check for draws here TODO: 3 fold repetition optimization
	if (self.positionHistory[self.hash] or 0) >= 3 or self.halfTimeClock >= 50 then
		return 0, -1
	end

	--##############################################################################################################
	-- check transposition table first
	local ttLookupEval, ttLookupCheckmatePly, ttLookupMove = self:TTlookupEval(self.hash, depth, ply, alpha, beta)
	if ttLookupEval ~= TT_LOOKUP_FAILED then
		self.cnt_trans += 1
		return ttLookupEval, ttLookupCheckmatePly, ttLookupMove
	end

	--##############################################################################################################
	-- At depth 0, enter quiescence search
	if depth <= 0 then
		return self:quiescence(alpha, beta, startTime, timeLimit, ply)
	end

	--##############################################################################################################
	local legalMoves, numMoves, inCheck = self:_getLegalMoves(false, ply, false)
	-- If no legal moves, return evaluation (could be mate/stalemate handling)
	if numMoves == 0 then
		if inCheck then return -20000 + ply, ply else return 0, -1 end
		--return self:evaluate()
	end
	
	local matePly = -1
	local evalType = TT_UPPER_BOUND
	local bestMove = nil

	for i, move in ipairs(legalMoves) do
		if i > numMoves then break end
		self:makeMove(move)
		local score, mate = self:search(depth - 1, -beta, -alpha, startTime, timeLimit, ply+1)
		self:unmakeMove()
		
		score = -score
		
		if score >= beta then
			
			if self.board[move.Y] == 0 then -- if the move is a non capture (if target square has no piece on it)
				local km1 = self.killerMoves[2*ply + 1]
				local km2 = self.killerMoves[2*ply + 2]
				if move ~= km1 and move ~= km2 then	-- if the move isnt already in the killer moves list
					self.killerMoves[2*ply + 2] = km1
					self.killerMoves[2*ply + 1] = move
				end
			end
			
			self.cnt_pruned += 1
			self:TTstoreEvaluation(self.hash, beta, mate, move, depth, TT_LOWER_BOUND)
			return beta, matePly  -- Beta cutoff
		end
		
		if self.stopSearch then
			if ply == 0 then
				--warn("stopped early. current best move: ", bestMove)
				return alpha, matePly, bestMove end
			return alpha, matePly
		end
		
		if score > alpha then
			if self.lines then
				ply += 1
				-- Store this move at start of PV for this ply
				self.bestLine[ply][1] = move

				-- Copy PV from the next ply
				for next = 1, self.pvLength[ply + 1] do
					self.bestLine[ply][next + 1] = self.bestLine[ply + 1][next]
				end

				-- Update PV length for this ply
				self.pvLength[ply] = self.pvLength[ply + 1] + 1
				ply -= 1
			end
			
			
			alpha = score
			evalType = TT_EXACT
			matePly = mate
			bestMove = move
		end
	end
	
	if ply == 0 then
		--print("storing best move with hash\n"..self.hash.."\n: ", bestMove)
	end
	
	self:TTstoreEvaluation(self.hash,alpha,matePly, bestMove, depth, evalType)
	
	if ply == 0 then return alpha, matePly, bestMove end
	
	return alpha, matePly
end

-----------------------------
-- Quiescence Search
-----------------------------
function engine:quiescence(alpha, beta, startTime, timeLimit, ply)
	if ply > self.cnt_maxd then
		self.cnt_maxd = ply

		task.wait()
	end
	
	if os.clock() - startTime >= timeLimit then
		self.stopSearch = true
		return 0, -1
	end

	local standPat = self:evaluate()
	if standPat >= beta then
		return beta, -1
	end
	if alpha < standPat then
		alpha = standPat
	end
	
	local matePly = -1

	local captureMoves, numMoves, inCheck = self:_getLegalMoves(false, ply, true)
	for i, move in ipairs(captureMoves) do
		if i > numMoves then break end
		self:makeMove(move)
		local score, mate = self:quiescence(-beta, -alpha, startTime, timeLimit, ply+1)
		self:unmakeMove()
		
		score = -score
		
		if self.stopSearch then
			return alpha, matePly
		end
		if score >= beta then
			return beta, matePly
		end
		if score > alpha then
			alpha = score
			matePly = mate
			
			if self.lines then
				ply += 1
				-- Store this move at start of PV for this ply
				self.bestLine[ply][1] = move

				-- Copy PV from the next ply
				for next = 1, self.pvLength[ply + 1] do
					self.bestLine[ply][next + 1] = self.bestLine[ply + 1][next]
				end

				-- Update PV length for this ply
				self.pvLength[ply] = self.pvLength[ply + 1] + 1
				ply -= 1
			end
		end
	end

	return alpha, matePly
end

-----------------------------
-- Internal Root Search Function (with time control)
-----------------------------
function engine:_go_search(depth, startTime, timeLimit)
	return self:search(depth, -99999, 99999, startTime, timeLimit, 0)
	
	
	--local legalMoves, numMoves, inCheck = self:_getLegalMoves(asdf)
	--local bestScore = -99999
	--local bestMove = nil
	--local alpha = -99999
	--local beta = 99999

	--for i, move in ipairs(legalMoves) do
	--	if os.clock() - startTime >= timeLimit then
	--		self.stopSearch = true
	--		break
	--	end
	--	if i > numMoves then break end
		
	--	self:makeMove(move)
	--	local score = -self:search(depth - 1, -beta, -alpha, startTime, timeLimit, 2)
	--	self:unmakeMove()
	--	if self.stopSearch then
	--		break
	--	end
	--	if score > bestScore then
	--		bestScore = score
	--		bestMove = move
	--	end
	--	if score > alpha then
	--		alpha = score
	--	end
	--end
	--return bestMove, bestScore
end

-----------------------------
-- External Fixed-Depth Search
-----------------------------
function engine:go_search(depth)
	self.stopSearch = false
	local startTime = os.clock()
	local timeLimit = math.huge  -- no time limit for fixed-depth search
	self:resetCounters()
	return self:_go_search(depth, startTime, timeLimit)
end

-----------------------------
-- Iterative Deepening Search (time-based)
-----------------------------
function engine:iterativeDeepening(timeLimitMs)
	self:TTclear()
	self:resetCounters()
	self.stopSearch = false
	local startTime = os.clock()
	local timeLimit = timeLimitMs / 1000  -- convert ms to seconds
	local depth = 1
	local bestMove = nil
	local bestScore = nil
	
	self:resetKillerMovesTable()
	
	self.nextBreakTime = os.clock()+1

	while os.clock() - startTime < timeLimit do
		local score, matePly, move = self:_go_search(depth, startTime, timeLimit)
		depth = depth + 1
		
		
		if self.stopSearch then
			if not bestMove or (score > bestScore) then
				--warn("new best move found from partial search")
				bestMove = move
				bestScore = score
			end
			
			
			--warn("Search stopped")
			break
		end
		bestMove = move
		bestScore = score
		warn(("Search to depth %d completed | Eval: %2.1f | Best Move: %s | Transpositions: %d | Evaluations: %d | Prunes: %d"):format(depth-1, bestScore, engine:move2str(bestMove or Vector3.zero), self.cnt_trans, self.cnt_eval, self.cnt_pruned))
		task.wait()
	end

	return bestMove, bestScore, depth - 1  -- return the best move, score, and completed depth
end

function engine:stop_search()
	self.stopSearch = true
	repeat task.wait() until not self.running
end

function engine:log()
	print("{")
	for i,v in self do
		if i ~= "TT" then
			print(`	[{i}] =`,v)
		else
			print("	[\"TT\"]] = [NOT SHOWN]")
		end
	end
	print("}")
end

function engine:getLegalMoves()
	local moves, num = self:_getLegalMoves(true, 0, false)
	moves = table.move(moves,1,num,1,{})
	return moves
end

function engine:resetPV()
	for ply = 1, 100 do
		self.bestLine[ply] = {}    -- create a table for each ply
		self.pvLength[ply] = 0        -- reset PV length for each ply
	end
end

function engine:go_infiniteSearch(updateCallback: ()->({
	depth: number,
	max_depth: number,
	transpositions: number,
	evaluations: number,
	num_pruned: number,
	best_move: bestMove,
	evaluation: number,
	mate_ply: number,
	compute_time: number
	}), maxDepth, bestLine)
	
	if self.running then warn("Engine is already running") return end
	self.running = true
	

	self:TTclear()
	self:resetCounters()
	self.stopSearch = false
	local startTime = os.clock()
	local timeLimit = math.huge
	local depth = 1
	local bestMove = nil
	local bestScore = nil
	
	self.lines = bestLine
	if bestLine then
		self:resetPV()
	end
	

	self:resetKillerMovesTable()

	self.nextBreakTime = os.clock()+1
	
	
	while not self.stopSearch and depth <= (maxDepth or 100) do
		local score, matePly, move = self:_go_search(depth, startTime, timeLimit)
		
		depth = depth + 1

		if self.stopSearch then
			if not move then
				warn(`--------------\nERROR WHILE SEARCHING TO DEPTH {depth-1}\n score: {score}, matePly: {matePly}\n[INFINITE TIME LIMIT] START TIME: {startTime}\n`)
				self:log()
				error("stop")
			end
			if not bestMove or (score > bestScore) then
				bestMove = move
				bestScore = score
			end

			break
		end
		bestMove = move
		bestScore = score
		
		local results = {
			depth = depth-1,
			max_depth = self.cnt_maxd,
			transpositions = self.cnt_trans,
			evaluations = self.cnt_eval,
			num_pruned = self.cnt_pruned,
			best_move = bestMove,
			evaluation = bestScore,
			mate_ply = matePly,
			compute_time = os.clock() - startTime,
			principal_variation = nil
		}
		
		if bestLine then
			results.principal_variation = self.bestLine[1]
		end
		
		updateCallback(results)
		
		--warn(("Search to depth %d completed | Eval: %2.1f | Best Move: %s | Transpositions: %d | Evaluations: %d | Prunes: %d"):format(depth-1, bestScore, engine:move2str(bestMove or Vector3.zero), self.cnt_trans, self.cnt_eval, self.cnt_pruned))
		task.wait()
	end
	
	self.lines = false
	
	self.running = false
end


function engine:go_perft(depth, expectedDebug)
	assert(depth > 0)
	
	self.checkmates = 0
	
	local start = os.clock()
	
	local legalMoves, numMoves, inCheck = self:_getLegalMoves(true)
	local totalSum = 0
	

	self.nextBreakTime = os.clock()+1
	
	
	if numMoves == 0 then
		if inCheck then
			self.checkmates += 1
		end
	else
		
		for i,v in legalMoves do
			if i > numMoves then break end
			
			self:makeMove(v)
			local num = self:perft(depth-1)
			totalSum += num
			self:unmakeMove()
			
			local movestr = self:move2str(v)
			local str = (" %3d : %-5s : %s"):format(i, movestr, formatNumber(num))
			if expectedDebug and expectedDebug[movestr] and expectedDebug[movestr] ~= num then
				str ..= " : [SHOULD BE "..expectedDebug[movestr].."]"
			end
			print(str)
		end
	end
	
	
	local elapsedTime = os.clock() - start
	
	print(("Depth: %d  |  Leaf Nodes: %s  |  Checkmates: %d  |  Total Time: %.2fs"):format(depth, formatNumber(totalSum), self.checkmates, elapsedTime))
end


function engine:go_move(move: string)
	local cvtMove = self:str2move(move)
	
	self:makeMove(cvtMove)
end

return engine
