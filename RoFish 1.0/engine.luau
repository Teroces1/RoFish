--!native
-- "engine.luau"

local TranspositionTable = {}
TranspositionTable.__index = TranspositionTable

TranspositionTable.lookupFailed = math.huge
TranspositionTable.lowerBound = -1
TranspositionTable.exact = 0
TranspositionTable.upperBound = 1

function TranspositionTable.new(size)
	local self = setmetatable({},TranspositionTable)
	
	-- key, eval, matePly, depth, move
	--local defualtEntry = {0,0,0,Vector3.zero,0,0}
	
	self.size = size
	self.entries = table.create(size)
	for i = 1,size do
		self.entries[i] = {0,0,0,Vector3.zero,0,0}
	end
	return self
end

function TranspositionTable:storeEvaluation(key, eval, matePly, move, depth, nodeType)
	local entry = self.entries[key%self.size + 1]
	entry[1] = key
	entry[2] = eval
	entry[3] = matePly
	entry[4] = move
	entry[5] = depth
	entry[6] = nodeType
end

function TranspositionTable:get(key)
	return self.entries[key%self.size + 1]
end

function TranspositionTable:getMove(key)
	return self.entries[key%self.size + 1][4]
end

function TranspositionTable:clear()
	for i,_ in self.entries do
		self.entries[i][1] = 0
		self.entries[i][2] = 0
		self.entries[i][3] = 0
		self.entries[i][4] = Vector3.zero
		self.entries[i][5] = 0
		self.entries[i][6] = 0
	end
end

function TranspositionTable:lookupEval(key, depth, ply, alpha, beta)
	local entry = self.entries[key%self.size + 1]
	
	if entry[1] == key and entry[5] >= depth then
		if entry[6] == 0 then	-- exact
			return entry[2], entry[3]
		end
		if entry[6] == 1 and entry[2] <= alpha then	-- exact
			return entry[2], entry[3]
		end
		if entry[6] == -1 and entry[2] >= beta then	-- exact
			return entry[2], entry[3]
		end
	end
	
	return TranspositionTable.lookupFailed
end

local Board = {}
Board.__index = Board




local preComputedMoves = require(script.preComputedMoves)

local bitBoardPieces = {
	king = 1,
	knight = 2,
	pawn = 3,
	rook = 5,
	bishop = 6,
	queen = 7
}

local oldBoardConversions = {
	[1] = 1,
	[2] = 7,
	[3] = 6,
	[4] = 2,
	[5] = 5,
	[6] = 3
}


local colors = {
	white = 8,
	black = 0
}

local bitboards = {
	lower = 1,
	upper = 2,
}

table.freeze(bitBoardPieces)
table.freeze(oldBoardConversions)
table.freeze(colors)


function Board:convetFromOldBoard(board)
	-- TODO add castling moves and stuff
	table.clear(self.pieces)
	self.board = table.create(64,0)
	self.enPassantTarget = board.enPassantTarget or 0
	for i = 1,8 do
		for j = 1,8 do
			if board.board[i][j] ~= 0 then
				local index = (j-1)*8+i
				if board.board[i][j].type == 1 then
					if board.board[i][j].color == 1 then	-- light
						self.lightKingPos = index
					else
						self.darkKingPos = index
					end
				end

				table.insert(self.pieces,index)
				self.board[index] = bit32.bor(8*(2-board.board[i][j].color), oldBoardConversions[board.board[i][j].type])
			end
		end
	end
end



function Board.new()
	local self = setmetatable({}, Board)
	self.board = table.create(64,0)
	self.pieces = {}
	
	self.sideToMove = colors.white
	self.castlingRights = 15 -- 1111: QKqk
	
	self.halfMoveClock = 0
	self.fullMoveClock = 0
	
	self.moveLog = {}
	self.enPassantTarget = 0
	
	self.darkKingPos = 0
	self.lightKingPos = 0
	
	local repetitionTableSize = 256
	
	self.repetitionHistory = table.create(repetitionTableSize,0)
	self.repetitionIndicies = table.create(repetitionTableSize+1,1)
	self.repetitionCount = 1
	
	self.tt = TranspositionTable.new(4096*256) -- possible to do 4096*1024 while its still efficient enough (only 0.01-0.03 seconds slower on 10m reads (4096 is about .14-.16 sec)) (didnt test farthur, but might be possible)
	
	self:initializeZobristKeys()
	
	
	
	self.eval_pawnsOnFilesTableWhite = table.create(8,0)
	self.eval_pawnsOnFilesTableBlack = table.create(8,0)
	
	return self
end

function Board:pushPosition(reset)
	self.repetitionHistory[self.repetitionCount] = self.hash
	if reset then
		self.repetitionIndicies[self.repetitionCount+1] = self.repetitionCount
	else
		self.repetitionIndicies[self.repetitionCount+1] = self.repetitionIndicies[self.repetitionCount]
	end
	self.repetitionCount += 1
end

function Board:popPosition()
	self.repetitionCount -= 1
end

function Board:countRepetitions()
	local count = 0
	for i = self.repetitionIndicies[self.repetitionCount], self.repetitionCount-1 do
		if self.repetitionHistory[i] == self.hash then
			count += 1
		end
	end
	return count
end

local fenConversions = {
	k = bitBoardPieces.king,
	p = bitBoardPieces.pawn,
	n = bitBoardPieces.knight,
	r = bitBoardPieces.rook,
	b = bitBoardPieces.bishop,
	q = bitBoardPieces.queen,
	K = bitBoardPieces.king + 8,
	P = bitBoardPieces.pawn + 8,
	N = bitBoardPieces.knight + 8,
	R = bitBoardPieces.rook + 8,
	B = bitBoardPieces.bishop + 8,
	Q = bitBoardPieces.queen + 8,
}


--[[local pieceValues = {
	[1] = 0,
	[2] = -300,
	[3] = -100,
	[4] = 0,
	[5] = -500,
	[6] = -320,
	[7] = -900,
	[8] = 0,
	[9] = 0,
	[10] = 300,
	[11] = 100,
	[12] = 0,
	[13] = 500,
	[14] = 320,
	[15] = 900,
}]]
local pieceValues = {
	[1] = 0,
	[2] = 300,
	[3] = 100,
	[4] = 0,
	[5] = 500,
	[6] = 320,
	[7] = 900,
	[8] = 0,
	[9] = 0,
	[10] = 300,
	[11] = 100,
	[12] = 0,
	[13] = 500,
	[14] = 320,
	[15] = 900,
}

local fenCastlingRights = {
	["-"] = 0,
	q = 1,
	k = 2,
	kq = 3,
	Q = 4,
	Qq = 5,
	Qk = 6,
	Qkq = 7,
	K = 8,
	Kq = 9,
	Kk = 10,
	Kkq = 11,
	KQ = 12,
	KQq = 13,
	KQk = 14,
	KQkq = 15
}

function decodeSquare(str:string) -- ex: a1 -> 1
	return (str:sub(1,1):byte()-96) + (tonumber(str:sub(2,2))*8-8)
end



function Board:loadFEN(fenStr:string)
	local x = 1
	local y = 8
	local parts = fenStr:split(" ")
	
	self.pieces = {}
	self.board = table.create(64,0)
	
	self.sideToMove = if parts[2] == "b" then colors.black else colors.white
	self.castlingRights = fenCastlingRights[parts[3]]
	
	if parts[4] ~= "-" then
		self.enPassantTarget = decodeSquare(parts[4])
	else
		self.enPassantTarget = 0
	end
	
	self.halfMoveClock = tonumber(parts[5]) or 0
	self.fullMoveClock = (tonumber(parts[6]) or 1)-1
	
	self.darkKingPos = 0
	self.lightKingPos = 0
	
	for i = 1,#parts[1] do
		local char = fenStr:sub(i,i)
		if x > 8 then
			x = 1
			y -= 1
			if y < 1 then
				break
			end
			continue
		end
		
		
		if fenConversions[char] then
			local index = (y-1)*8+x
			table.insert(self.pieces,index)
			self.board[index] = fenConversions[char]
			if char == "K" then
				self.lightKingPos = index
			elseif char == "k" then
				self.darkKingPos = index
			end
		elseif char == "/" then
			x = 1
			y -= 1
			continue
		elseif tonumber(char) then
			x += tonumber(char)
			continue
		else
			error("Unsupported character: "..char,2)
		end
		x += 1
	end
	
	self:generateZobristHash()
end

function Board:getFEN()
	local x = 1
	local y = 8
	local numSpace = 0

	local boardStr = ""

	while y > 0 do

		if x > 8 then
			x = 1
			y -= 1
			if numSpace > 0 then
				boardStr ..= numSpace
				numSpace = 0
			end
			if y < 1 then
				break
			end
			boardStr ..= "/"
			continue
		end

		local piece = self.board[(y-1)*8 + x]

		if piece == 0 then
			numSpace += 1
		else
			if numSpace > 0 then
				boardStr ..= numSpace
				numSpace = 0
			end

			for i,v in fenConversions do
				if v == piece then
					boardStr ..= i
					break
				end
			end
		end

		x += 1
	end

	local castlingRights = "-"
	for i,v in fenCastlingRights do
		if v == self.castlingRights then
			castlingRights = i
			break
		end
	end


	local enPassantSquare = if self.enPassantTarget > 0 then self.enPassantTarget else "-"

	local sideToMove = if self.sideToMove == 0 then "b" else "w"

	return ("%s %s %s %s %d %d"):format(boardStr,sideToMove,castlingRights,enPassantSquare,self.halfMoveClock,self.fullMoveClock+1)
end

function Board:convertMovesFromBitboard(moves, pos, lower, upper, isApawn, test)
	if test and isApawn then print("yes it is a pawn") end
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


function Board:convertMovesFromBitboards(lower,upper)
	local moves = {}
	for _,pos in self.pieces do
		local lowerMoves = lower[pos]
		local upperPos = upper[pos]
		
		self:convertMovesFromBitboard(moves, pos, lowerMoves, upperPos)
	end
end

function Board:getLegalMoves(onlyCaptures)
	--		generate all legal moves in the form of bitboards
	
	local kingRaycastsLower = table.create(4,0)
	local kingRaycastsUpper = table.create(4,0)
	
	local kingRaycastsEnPassantLower = table.create(4,0)
	local kingRaycastsEnPassantUpper = table.create(4,0)
	
	local kingPos = 0
	
	local piecesLower = 0	-- all pieces
	local piecesUpper = 0
	
	local sidePiecesLower = 0	-- only pieces on same side
	local sidePiecesUpper = 0
	
	local sideToMove = self.sideToMove
	
	if sideToMove == 0 then -- black
		kingPos = self.darkKingPos
	else	-- white
		kingPos = self.lightKingPos
	end
	
	local kingPosBitboardLower = 0
	local kingPosBitboardUpper = 0
	
	for _,pos in self.pieces do
		local color = bit32.band(self.board[pos],8)
		if pos > 32 then
			pos -= 33
			piecesUpper = bit32.bor(piecesUpper, 2^pos)
			if color == sideToMove then
				sidePiecesUpper = bit32.bor(sidePiecesUpper, 2^pos)
			end
			if pos +33 == kingPos then
				kingPosBitboardUpper = 2^pos
			end
		else
			pos -= 1
			piecesLower = bit32.bor(piecesLower, 2^pos)
			if color == sideToMove then
				sidePiecesLower = bit32.bor(sidePiecesLower, 2^pos)
			end
			if pos +1 == kingPos then
				kingPosBitboardLower = 2^pos
			end
		end
	end
	
	local inversePiecesLower = bit32.bnot(piecesLower)
	local inversePiecesUpper = bit32.bnot(piecesUpper)
	local inverseSidePiecesLower = bit32.bnot(sidePiecesLower)
	local inverseSidePiecesUpper = bit32.bnot(sidePiecesUpper)
	local inverseKingLower = bit32.bnot(kingPosBitboardLower)
	local inverseKingUpper = bit32.bnot(kingPosBitboardUpper)
	
	
	local enPassantTargetLower = 0
	local enPassantTargetUpper = 0
	
	if self.enPassantTarget > 32 then
		enPassantTargetUpper = 2^(self.enPassantTarget-33)
	elseif self.enPassantTarget > 0 then
		enPassantTargetLower = 2^(self.enPassantTarget-1)
	end
	
	local enPassantPinInverseLower = 0
	local enPassantPinInverseUpper = 0
	
	if sideToMove == 0 then	--black
		enPassantPinInverseLower = bit32.lshift(enPassantTargetLower, 8)
	else
		enPassantPinInverseUpper = bit32.rshift(enPassantTargetUpper, 8)
	end
	
	local enPassantPinLower = bit32.bnot(enPassantPinInverseLower)
	local enPassantPinUpper = bit32.bnot(enPassantPinInverseUpper)
	
	local enPassantTargetInverseLower = bit32.bnot(enPassantTargetLower)
	local enPassantTargetInverseUpper = bit32.bnot(enPassantTargetUpper)
	
	
	if kingPos ~= 0 then
		for i = 1,4 do
			local blockersLower = bit32.band(piecesLower,preComputedMoves.kingPinsMaskLower[i][kingPos])
			local blockersUpper = bit32.band(piecesUpper,preComputedMoves.kingPinsMaskUpper[i][kingPos])
			local index = bit32.bor(blockersLower,bit32.rrotate(blockersUpper,1))
			
			kingRaycastsLower[i] = preComputedMoves.kingPinsLower[i][kingPos][index]
			kingRaycastsUpper[i] = preComputedMoves.kingPinsUpper[i][kingPos][index]
			
			blockersLower = bit32.band(blockersLower,enPassantPinLower)
			blockersUpper = bit32.band(blockersUpper,enPassantPinUpper)
			index = bit32.bor(blockersLower,bit32.rrotate(blockersUpper,1))

			kingRaycastsEnPassantLower[i] = preComputedMoves.kingPinsLower[i][kingPos][index]
			kingRaycastsEnPassantUpper[i] = preComputedMoves.kingPinsUpper[i][kingPos][index]
		end
	end
	
	local numPieces = #self.pieces
	
	--local limitMovesForPinsLower = table.create(numPieces,4294967295)	-- all 1s in binary
	--local limitMovesForPinsUpper = table.create(numPieces,4294967295)
	local pieceMovesLower
	local pieceMovesUpper
	
	if onlyCaptures then
		pieceMovesLower = table.create(64,bit32.band(bit32.bor(piecesLower,enPassantTargetLower), inverseSidePiecesLower))
		pieceMovesUpper = table.create(64,bit32.band(bit32.bor(piecesUpper,enPassantTargetUpper), inverseSidePiecesUpper))
	else
		pieceMovesLower = table.create(64,inverseSidePiecesLower)
		pieceMovesUpper = table.create(64,inverseSidePiecesUpper)
	end
	
	local opponentSemiAttackSquaresUpper = 0
	local opponentSemiAttackSquaresLower = 0	-- includes squares that pieces are on
	
	local moves = {}
	
	local limitMovesForChecksLower = 4294967295
	local limitMovesForChecksUpper = 4294967295
	local additionalPawnMovesLower = 0
	local additionalPawnMovesUpper = 0
	
	local inCheck = false
	
	local pawnAttacksLower = 0
	local pawnAttacksUpper = 0
	
	for _,pos in self.pieces do
		local piece = self.board[pos]
		local pieceType = bit32.band(piece,7)
		local color = bit32.band(piece,8)
		
		local posBitLower = 0	-- maybe move this for only enemy pieces
		local posBitUpper = 0
		if pos > 32 then
			posBitUpper = bit32.lshift(1,pos-33)
		else
			posBitLower = bit32.lshift(1,pos-1)
		end
		
		if color == sideToMove then		-- move generation
			if pieceType == 1 then
				if (sideToMove == 0 and kingPos == 61) or (sideToMove == 8 and kingPos == 5) then
					if onlyCaptures then
						pieceMovesLower[pos] = bit32.band(pieceMovesLower[pos],preComputedMoves.kingLower[pos])
						pieceMovesUpper[pos] = bit32.band(pieceMovesUpper[pos],preComputedMoves.kingUpper[pos])
					else
						pieceMovesLower[pos] = preComputedMoves.kingLower[pos]
						pieceMovesUpper[pos] = preComputedMoves.kingUpper[pos]
					end
				else
					if onlyCaptures then
						pieceMovesLower[pos] = bit32.band(pieceMovesLower[pos],preComputedMoves.kingAttackLower[pos])
						pieceMovesUpper[pos] = bit32.band(pieceMovesUpper[pos],preComputedMoves.kingAttackUpper[pos])
					else
						pieceMovesLower[pos] = preComputedMoves.kingAttackLower[pos]
						pieceMovesUpper[pos] = preComputedMoves.kingAttackUpper[pos]
					end
				end
			elseif pieceType == 2 then
				pieceMovesLower[pos] = bit32.band(pieceMovesLower[pos],preComputedMoves.knightLower[pos],inverseSidePiecesLower)
				pieceMovesUpper[pos] = bit32.band(pieceMovesUpper[pos],preComputedMoves.knightUpper[pos],inverseSidePiecesUpper)
			elseif pieceType == 3 then
				if color == 0 then -- black
					if bit32.btest(bit32.rshift(posBitUpper,8),piecesUpper) then
						-- use blocked moves bitboard
						local movesLower = bit32.bor(bit32.band(inversePiecesLower, preComputedMoves.pawnMovesBlockingLower[1][pos]), bit32.band(preComputedMoves.pawnAttacksLower[1][pos],bit32.bor(enPassantTargetLower,piecesLower)))
						local movesUpper = bit32.bor(bit32.band(inversePiecesUpper, preComputedMoves.pawnMovesBlockingUpper[1][pos]), bit32.band(preComputedMoves.pawnAttacksUpper[1][pos],bit32.bor(enPassantTargetUpper,piecesUpper)))
						
						pieceMovesLower[pos] = bit32.band(pieceMovesLower[pos],movesLower,inverseSidePiecesLower)
						pieceMovesUpper[pos] = bit32.band(pieceMovesUpper[pos],movesUpper,inverseSidePiecesUpper)
						
					else
						local movesLower = bit32.bor(bit32.band(inversePiecesLower, preComputedMoves.pawnMovesLower[1][pos]), bit32.band(preComputedMoves.pawnAttacksLower[1][pos],bit32.bor(enPassantTargetLower,piecesLower)))
						local movesUpper = bit32.bor(bit32.band(inversePiecesUpper, preComputedMoves.pawnMovesUpper[1][pos]), bit32.band(preComputedMoves.pawnAttacksUpper[1][pos],bit32.bor(enPassantTargetUpper,piecesUpper)))

						pieceMovesLower[pos] = bit32.band(pieceMovesLower[pos],movesLower,inverseSidePiecesLower)
						pieceMovesUpper[pos] = bit32.band(pieceMovesUpper[pos],movesUpper,inverseSidePiecesUpper)
						-- use un blocked moves bitboard
					end
				else
					if bit32.btest(bit32.lshift(posBitLower,8),piecesLower) then
						-- use blocked moves bitboard
						local movesLower = bit32.bor(bit32.band(inversePiecesLower, preComputedMoves.pawnMovesBlockingLower[2][pos]), bit32.band(preComputedMoves.pawnAttacksLower[2][pos],bit32.bor(enPassantTargetLower,piecesLower)))
						local movesUpper = bit32.bor(bit32.band(inversePiecesUpper, preComputedMoves.pawnMovesBlockingUpper[2][pos]), bit32.band(preComputedMoves.pawnAttacksUpper[2][pos],bit32.bor(enPassantTargetUpper,piecesUpper)))

						pieceMovesLower[pos] = bit32.band(pieceMovesLower[pos],movesLower,inverseSidePiecesLower)
						pieceMovesUpper[pos] = bit32.band(pieceMovesUpper[pos],movesUpper,inverseSidePiecesUpper)

					else
						local movesLower = bit32.bor(bit32.band(inversePiecesLower, preComputedMoves.pawnMovesLower[2][pos]), bit32.band(preComputedMoves.pawnAttacksLower[2][pos],bit32.bor(enPassantTargetLower,piecesLower)))
						local movesUpper = bit32.bor(bit32.band(inversePiecesUpper, preComputedMoves.pawnMovesUpper[2][pos]), bit32.band(preComputedMoves.pawnAttacksUpper[2][pos],bit32.bor(enPassantTargetUpper,piecesUpper)))

						pieceMovesLower[pos] = bit32.band(pieceMovesLower[pos],movesLower,inverseSidePiecesLower)
						pieceMovesUpper[pos] = bit32.band(pieceMovesUpper[pos],movesUpper,inverseSidePiecesUpper)
						-- use un blocked moves bitboard
					end
				end
			elseif pieceType == 5 then	-- rook
				local blockersLower = bit32.band(piecesLower,preComputedMoves.rookMaskLower[pos])
				local blockersUpper = bit32.band(piecesUpper,preComputedMoves.rookMaskUpper[pos])
				local index = 0
				local file = (pos-1)%8
				if file == 0 then
					if pos > 32 then
						index = bit32.bor(blockersUpper, bit32.rrotate(blockersLower,1))
					else
						index = bit32.bor(blockersLower, bit32.rrotate(blockersUpper,1))
					end
				else
					if pos > 32 then
						index = bit32.bor(blockersUpper, bit32.rrotate(blockersLower,file))
					else
						index = bit32.bor(blockersLower, bit32.rrotate(blockersUpper,file))
					end
				end
				
				local s,er = pcall(function()
					pieceMovesLower[pos] = bit32.band(pieceMovesLower[pos], preComputedMoves.rookLower[pos][index])
					pieceMovesUpper[pos] = bit32.band(pieceMovesUpper[pos], preComputedMoves.rookUpper[pos][index])
				end)
				if not s then
					warn(pos,piecesUpper,piecesLower, index)
					warn(preComputedMoves.rookMaskLower[pos],preComputedMoves.rookMaskUpper[pos])
					warn(preComputedMoves.rookLower[pos])
					warn(preComputedMoves.rookUpper[pos])
					error(er)
				end
			elseif pieceType == 6 then	-- bishop
				local blockersLower = bit32.band(piecesLower,preComputedMoves.bishopMaskLower[pos])
				local blockersUpper = bit32.band(piecesUpper,preComputedMoves.bishopMaskUpper[pos])
				local index = bit32.bor(blockersLower,bit32.rrotate(blockersUpper,1))
				
				pieceMovesLower[pos] = bit32.band(pieceMovesLower[pos], preComputedMoves.bishopLower[pos][index])
				pieceMovesUpper[pos] = bit32.band(pieceMovesUpper[pos], preComputedMoves.bishopUpper[pos][index])
			elseif pieceType == 7 then	-- queen
				local blockersLower = bit32.band(piecesLower,preComputedMoves.bishopMaskLower[pos])
				local blockersUpper = bit32.band(piecesUpper,preComputedMoves.bishopMaskUpper[pos])
				local index = bit32.bor(blockersLower,bit32.rrotate(blockersUpper,1))
				
				blockersLower = bit32.band(piecesLower,preComputedMoves.rookMaskLower[pos])
				blockersUpper = bit32.band(piecesUpper,preComputedMoves.rookMaskUpper[pos])
				
				local index2 = 0
				local file = (pos-1)%8
				if file == 0 then
					if pos > 32 then
						index2 = bit32.bor(blockersUpper, bit32.rrotate(blockersLower,1))
					else
						index2 = bit32.bor(blockersLower, bit32.rrotate(blockersUpper,1))
					end
				else
					if pos > 32 then
						index2 = bit32.bor(blockersUpper, bit32.rrotate(blockersLower,file))
					else
						index2 = bit32.bor(blockersLower, bit32.rrotate(blockersUpper,file))
					end
				end
				
				pieceMovesLower[pos] = bit32.band(pieceMovesLower[pos], bit32.bor(preComputedMoves.bishopLower[pos][index], preComputedMoves.rookLower[pos][index2]))
				pieceMovesUpper[pos] = bit32.band(pieceMovesUpper[pos], bit32.bor(preComputedMoves.bishopUpper[pos][index], preComputedMoves.rookUpper[pos][index2]))
			else
				pieceMovesLower[pos] = 0
				pieceMovesUpper[pos] = 0
			end
		else							-- pin generation and enemy attacks
			pieceMovesLower[pos] = 0
			pieceMovesUpper[pos] = 0
			if pieceType == 1 then
				opponentSemiAttackSquaresLower = bit32.bor(opponentSemiAttackSquaresLower, preComputedMoves.kingAttackLower[pos])
				opponentSemiAttackSquaresUpper = bit32.bor(opponentSemiAttackSquaresUpper, preComputedMoves.kingAttackUpper[pos])
			elseif pieceType == 2 then
				local movesLower = preComputedMoves.knightLower[pos]
				local movesUpper = preComputedMoves.knightUpper[pos]
				opponentSemiAttackSquaresLower = bit32.bor(opponentSemiAttackSquaresLower,movesLower)
				opponentSemiAttackSquaresUpper = bit32.bor(opponentSemiAttackSquaresUpper,movesUpper)
				
				if bit32.btest(movesLower, kingPosBitboardLower) or bit32.btest(movesUpper, kingPosBitboardUpper) then
					inCheck = true
					limitMovesForChecksLower = bit32.band(limitMovesForChecksLower, posBitLower)
					limitMovesForChecksUpper = bit32.band(limitMovesForChecksUpper, posBitUpper)
				end
			elseif pieceType == 3 then
				local movesLower = preComputedMoves.pawnAttacksLower[color//8+1][pos]
				local movesUpper = preComputedMoves.pawnAttacksUpper[color//8+1][pos]
				
				opponentSemiAttackSquaresLower = bit32.bor(opponentSemiAttackSquaresLower,movesLower)
				opponentSemiAttackSquaresUpper = bit32.bor(opponentSemiAttackSquaresUpper,movesUpper)
				
				pawnAttacksLower = bit32.bor(pawnAttacksLower,movesLower)
				pawnAttacksUpper = bit32.bor(pawnAttacksUpper,movesUpper)

				if bit32.btest(movesLower, kingPosBitboardLower) or bit32.btest(movesUpper, kingPosBitboardUpper) then
					inCheck = true
					if posBitLower == enPassantPinInverseLower and posBitUpper == enPassantPinInverseUpper then
						-- en passant possible to get out of check
						additionalPawnMovesLower = enPassantTargetLower
						additionalPawnMovesUpper = enPassantTargetUpper
					end
					limitMovesForChecksLower = bit32.band(limitMovesForChecksLower, posBitLower)
					limitMovesForChecksUpper = bit32.band(limitMovesForChecksUpper, posBitUpper)
				end	
			elseif pieceType == 5 then
				for i = 1,4 do
					local blockersLower = bit32.band(piecesLower,preComputedMoves.rookPinsMaskLower[i][pos])
					local blockersUpper = bit32.band(piecesUpper,preComputedMoves.rookPinsMaskUpper[i][pos])

					local index = bit32.bor(blockersLower,bit32.rrotate(blockersUpper,1))	-- can bishop index formula (since its only for 1 direction)
					local movesLower = preComputedMoves.rookPinsLower[i][pos][index]
					local movesUpper = preComputedMoves.rookPinsUpper[i][pos][index]

					local index2 = bit32.bor(bit32.band(blockersLower,inverseKingLower), bit32.rrotate(bit32.band(blockersUpper,inverseKingUpper),1))
					opponentSemiAttackSquaresLower = bit32.bor(opponentSemiAttackSquaresLower, preComputedMoves.rookPinsLower[i][pos][index2])
					opponentSemiAttackSquaresUpper = bit32.bor(opponentSemiAttackSquaresUpper, preComputedMoves.rookPinsUpper[i][pos][index2])

					if bit32.btest(movesLower,kingPosBitboardLower) or bit32.btest(movesUpper, kingPosBitboardUpper) then	-- friendly king in check: limit moves
						inCheck = true
						limitMovesForChecksLower = bit32.band(limitMovesForChecksLower, bit32.bor(movesLower,posBitLower))
						limitMovesForChecksUpper = bit32.band(limitMovesForChecksUpper, bit32.bor(movesUpper,posBitUpper))
					end
					
					local dirType = (i-1)//2+1
					
					-- en passant pins
					if self.enPassantTarget ~= 0 then
						local blockersLower2 = bit32.band(bit32.band(piecesLower,enPassantPinLower),preComputedMoves.rookPinsMaskLower[i][pos])
						local blockersUpper2 = bit32.band(bit32.band(piecesUpper,enPassantPinUpper),preComputedMoves.rookPinsMaskUpper[i][pos])
						
						local idx = bit32.bor(blockersLower2,bit32.rrotate(blockersUpper2,1))
						local movesLower2 = preComputedMoves.rookPinsLower[i][pos][idx]
						local movesUpper2 = preComputedMoves.rookPinsUpper[i][pos][idx]
						
						local pinLower = bit32.band(movesLower2,kingRaycastsEnPassantLower[dirType])
						local pinUpper = bit32.band(movesUpper2,kingRaycastsEnPassantUpper[dirType])

						local crLower = bit32.countrz(pinLower)
						local crUpper = bit32.countrz(pinUpper)
						
						
						if crLower + bit32.countlz(pinLower) == 31 and crUpper == 32 then
							crLower += 1
							if self.board[crLower] == 3 + sideToMove then	-- same side pawn
								pieceMovesLower[crLower] = bit32.band(pieceMovesLower[crLower], enPassantTargetInverseLower)
								pieceMovesUpper[crLower] = bit32.band(pieceMovesUpper[crLower], enPassantTargetInverseUpper)
							end
						end
						
						if crUpper + bit32.countlz(pinUpper) == 31 and crLower == 32 then
							crUpper += 33
							if self.board[crUpper] == 3 + sideToMove then	-- same side pawn
								pieceMovesLower[crUpper] = bit32.band(pieceMovesLower[crUpper], enPassantTargetInverseLower)
								pieceMovesUpper[crUpper] = bit32.band(pieceMovesUpper[crUpper], enPassantTargetInverseUpper)
							end
						end
					end
					
					
					local pinLower = bit32.band(movesLower,kingRaycastsLower[dirType])
					local pinUpper = bit32.band(movesUpper,kingRaycastsUpper[dirType])

					local crLower = bit32.countrz(pinLower)
					local crUpper = bit32.countrz(pinUpper)
					if crLower + bit32.countlz(pinLower) == 31 and crUpper == 32 then -- there is one 1 bit, so there has to be a pin
						crLower += 1
						pieceMovesLower[crLower] = bit32.band(pieceMovesLower[crLower], bit32.bor(preComputedMoves.rookPinsMaskLower[i][pos],posBitLower))	-- [DONE] add an AND operation after this with itself (x = x & new) - for multiple kings support
						pieceMovesUpper[crLower] = bit32.band(pieceMovesUpper[crLower], bit32.bor(preComputedMoves.rookPinsMaskUpper[i][pos],posBitUpper))
						continue
					end


					if crUpper + bit32.countlz(pinUpper) == 31 and crLower == 32 then
						crUpper += 33
						pieceMovesLower[crUpper] = bit32.band(pieceMovesLower[crUpper], bit32.bor(preComputedMoves.rookPinsMaskLower[i][pos],posBitLower))
						pieceMovesUpper[crUpper] = bit32.band(pieceMovesUpper[crUpper], bit32.bor(preComputedMoves.rookPinsMaskUpper[i][pos],posBitUpper))
					end
				end
			elseif pieceType == 6 then	-- bishop
				for i = 1,4 do
					local blockersLower = bit32.band(piecesLower,preComputedMoves.bishopPinsMaskLower[i][pos])
					local blockersUpper = bit32.band(piecesUpper,preComputedMoves.bishopPinsMaskUpper[i][pos])
					
					local index = bit32.bor(blockersLower,bit32.rrotate(blockersUpper,1))
					local movesLower = preComputedMoves.bishopPinsLower[i][pos][index]
					local movesUpper = preComputedMoves.bishopPinsUpper[i][pos][index]
					
					local index2 = bit32.bor(bit32.band(blockersLower,inverseKingLower), bit32.rrotate(bit32.band(blockersUpper,inverseKingUpper),1))
					opponentSemiAttackSquaresLower = bit32.bor(opponentSemiAttackSquaresLower, preComputedMoves.bishopPinsLower[i][pos][index2])
					opponentSemiAttackSquaresUpper = bit32.bor(opponentSemiAttackSquaresUpper, preComputedMoves.bishopPinsUpper[i][pos][index2])
					
					if bit32.btest(movesLower,kingPosBitboardLower) or bit32.btest(movesUpper, kingPosBitboardUpper) then	-- friendly king in check: limit moves
						inCheck = true
						limitMovesForChecksLower = bit32.band(limitMovesForChecksLower, bit32.bor(movesLower,posBitLower))
						limitMovesForChecksUpper = bit32.band(limitMovesForChecksUpper, bit32.bor(movesUpper,posBitUpper))
					end

					local dirType = (i-1)//2+3
					
					local pinLower = bit32.band(movesLower,kingRaycastsLower[dirType])
					local pinUpper = bit32.band(movesUpper,kingRaycastsUpper[dirType])
					
					local crLower = bit32.countrz(pinLower)
					local crUpper = bit32.countrz(pinUpper)
					if crLower + bit32.countlz(pinLower) == 31 and crUpper == 32 then -- there is one 1 bit, so there has to be a pin
						crLower += 1
						pieceMovesLower[crLower] = bit32.band(pieceMovesLower[crLower], bit32.bor(preComputedMoves.bishopPinsMaskLower[i][pos],posBitLower))	-- [DONE] add an AND operation after this with itself (x = x & new) - for multiple kings support
						pieceMovesUpper[crLower] = bit32.band(pieceMovesUpper[crLower], bit32.bor(preComputedMoves.bishopPinsMaskUpper[i][pos],posBitUpper))
						continue
						-- [DONE]: change to break if there is only 1 king on the board (cause if pin is found in 1 direction, there cant be a pin in other directions)
						-- im leaving it as continue for testing
					end
					
					
					if crUpper + bit32.countlz(pinUpper) == 31 and crLower == 32 then
						crUpper += 33
						pieceMovesLower[crUpper] = bit32.band(pieceMovesLower[crUpper], bit32.bor(preComputedMoves.bishopPinsMaskLower[i][pos],posBitLower))
						pieceMovesUpper[crUpper] = bit32.band(pieceMovesUpper[crUpper], bit32.bor(preComputedMoves.bishopPinsMaskUpper[i][pos],posBitUpper))
					end
				end
			elseif pieceType == 7 then
				for i = 1,4 do
					local blockersLower = bit32.band(piecesLower,preComputedMoves.rookPinsMaskLower[i][pos])
					local blockersUpper = bit32.band(piecesUpper,preComputedMoves.rookPinsMaskUpper[i][pos])

					local index = bit32.bor(blockersLower,bit32.rrotate(blockersUpper,1))	-- can bishop index formula (since its only for 1 direction)
					local movesLower = preComputedMoves.rookPinsLower[i][pos][index]
					local movesUpper = preComputedMoves.rookPinsUpper[i][pos][index]

					local index2 = bit32.bor(bit32.band(blockersLower,inverseKingLower), bit32.rrotate(bit32.band(blockersUpper,inverseKingUpper),1))
					opponentSemiAttackSquaresLower = bit32.bor(opponentSemiAttackSquaresLower, preComputedMoves.rookPinsLower[i][pos][index2])
					opponentSemiAttackSquaresUpper = bit32.bor(opponentSemiAttackSquaresUpper, preComputedMoves.rookPinsUpper[i][pos][index2])

					if bit32.btest(movesLower,kingPosBitboardLower) or bit32.btest(movesUpper, kingPosBitboardUpper) then	-- friendly king in check: limit moves
						inCheck = true
						limitMovesForChecksLower = bit32.band(limitMovesForChecksLower, bit32.bor(movesLower,posBitLower))
						limitMovesForChecksUpper = bit32.band(limitMovesForChecksUpper, bit32.bor(movesUpper,posBitUpper))
					end
					

					local dirType = (i-1)//2+1
					
					-- en passant pins
					if self.enPassantTarget ~= 0 then
						local blockersLower2 = bit32.band(bit32.band(piecesLower,enPassantPinLower),preComputedMoves.rookPinsMaskLower[i][pos])
						local blockersUpper2 = bit32.band(bit32.band(piecesUpper,enPassantPinUpper),preComputedMoves.rookPinsMaskUpper[i][pos])
						
						local idx = bit32.bor(blockersLower2,bit32.rrotate(blockersUpper2,1))
						local movesLower2 = preComputedMoves.rookPinsLower[i][pos][idx]
						local movesUpper2 = preComputedMoves.rookPinsUpper[i][pos][idx]
						
						local pinLower = bit32.band(movesLower2,kingRaycastsEnPassantLower[dirType])
						local pinUpper = bit32.band(movesUpper2,kingRaycastsEnPassantUpper[dirType])

						local crLower = bit32.countrz(pinLower)
						local crUpper = bit32.countrz(pinUpper)
						
						
						if crLower + bit32.countlz(pinLower) == 31 and crUpper == 32 then
							crLower += 1
							if self.board[crLower] == 3 + sideToMove then	-- same side pawn
								pieceMovesLower[crLower] = bit32.band(pieceMovesLower[crLower], enPassantTargetInverseLower)
								pieceMovesUpper[crLower] = bit32.band(pieceMovesUpper[crLower], enPassantTargetInverseUpper)
							end
						end
						
						if crUpper + bit32.countlz(pinUpper) == 31 and crLower == 32 then
							crUpper += 33
							if self.board[crUpper] == 3 + sideToMove then	-- same side pawn
								pieceMovesLower[crUpper] = bit32.band(pieceMovesLower[crUpper], enPassantTargetInverseLower)
								pieceMovesUpper[crUpper] = bit32.band(pieceMovesUpper[crUpper], enPassantTargetInverseUpper)
							end
						end
					end
					
					local pinLower = bit32.band(movesLower,kingRaycastsLower[dirType])
					local pinUpper = bit32.band(movesUpper,kingRaycastsUpper[dirType])

					local crLower = bit32.countrz(pinLower)
					local crUpper = bit32.countrz(pinUpper)
					if crLower + bit32.countlz(pinLower) == 31 and crUpper == 32 then -- there is one 1 bit, so there has to be a pin
						crLower += 1
						pieceMovesLower[crLower] = bit32.band(pieceMovesLower[crLower], bit32.bor(preComputedMoves.rookPinsMaskLower[i][pos],posBitLower))	-- [DONE] add an AND operation after this with itself (x = x & new) - for multiple kings support
						pieceMovesUpper[crLower] = bit32.band(pieceMovesUpper[crLower], bit32.bor(preComputedMoves.rookPinsMaskUpper[i][pos],posBitUpper))
					elseif crUpper + bit32.countlz(pinUpper) == 31 and crLower == 32 then
						crUpper += 33
						pieceMovesLower[crUpper] = bit32.band(pieceMovesLower[crUpper], bit32.bor(preComputedMoves.rookPinsMaskLower[i][pos],posBitLower))
						pieceMovesUpper[crUpper] = bit32.band(pieceMovesUpper[crUpper], bit32.bor(preComputedMoves.rookPinsMaskUpper[i][pos],posBitUpper))
					end
					
					blockersLower = bit32.band(piecesLower,preComputedMoves.bishopPinsMaskLower[i][pos])
					blockersUpper = bit32.band(piecesUpper,preComputedMoves.bishopPinsMaskUpper[i][pos])

					index = bit32.bor(blockersLower,bit32.rrotate(blockersUpper,1))
					movesLower = preComputedMoves.bishopPinsLower[i][pos][index]
					movesUpper = preComputedMoves.bishopPinsUpper[i][pos][index]

					index2 = bit32.bor(bit32.band(blockersLower,inverseKingLower), bit32.rrotate(bit32.band(blockersUpper,inverseKingUpper),1))
					opponentSemiAttackSquaresLower = bit32.bor(opponentSemiAttackSquaresLower, preComputedMoves.bishopPinsLower[i][pos][index2])
					opponentSemiAttackSquaresUpper = bit32.bor(opponentSemiAttackSquaresUpper, preComputedMoves.bishopPinsUpper[i][pos][index2])

					if bit32.btest(movesLower,kingPosBitboardLower) or bit32.btest(movesUpper, kingPosBitboardUpper) then	-- friendly king in check: limit moves
						inCheck = true
						limitMovesForChecksLower = bit32.band(limitMovesForChecksLower, bit32.bor(movesLower,posBitLower))
						limitMovesForChecksUpper = bit32.band(limitMovesForChecksUpper, bit32.bor(movesUpper,posBitUpper))
					end
					

					dirType = (i-1)//2+3
					
					pinLower = bit32.band(movesLower,kingRaycastsLower[dirType])
					pinUpper = bit32.band(movesUpper,kingRaycastsUpper[dirType])

					crLower = bit32.countrz(pinLower)
					crUpper = bit32.countrz(pinUpper)
					if crLower + bit32.countlz(pinLower) == 31 and crUpper == 32 then -- there is one 1 bit, so there has to be a pin
						crLower += 1
						pieceMovesLower[crLower] = bit32.band(pieceMovesLower[crLower], bit32.bor(preComputedMoves.bishopPinsMaskLower[i][pos],posBitLower))	-- [DONE] add an AND operation after this with itself (x = x & new) - for multiple kings support
						pieceMovesUpper[crLower] = bit32.band(pieceMovesUpper[crLower], bit32.bor(preComputedMoves.bishopPinsMaskUpper[i][pos],posBitUpper))
						continue
					end


					if crUpper + bit32.countlz(pinUpper) == 31 and crLower == 32 then
						crUpper += 33
						pieceMovesLower[crUpper] = bit32.band(pieceMovesLower[crUpper], bit32.bor(preComputedMoves.bishopPinsMaskLower[i][pos],posBitLower))
						pieceMovesUpper[crUpper] = bit32.band(pieceMovesUpper[crUpper], bit32.bor(preComputedMoves.bishopPinsMaskUpper[i][pos],posBitUpper))
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
	
	pieceMovesLower[kingPos] = bit32.band(pieceMovesLower[kingPos],bit32.bnot(bit32.bor(sidePiecesLower,opponentSemiAttackSquaresLower)))
	pieceMovesUpper[kingPos] = bit32.band(pieceMovesUpper[kingPos],bit32.bnot(bit32.bor(sidePiecesUpper,opponentSemiAttackSquaresUpper)))
	if preComputedMoves.kingOriginSquare[sideToMove//8+1] == kingPos then
		if sideToMove == 0 then -- castling - QKqk
			if inCheck == false then
				pieceMovesUpper[kingPos] = bit32.band(pieceMovesUpper[kingPos], preComputedMoves.castleMaskBlack[1+bit32.band(self.castlingRights,3)])
				if bit32.band(pieceMovesUpper[kingPos], 201326592) == 201326592 and bit32.btest(kingPosBitboardUpper,preComputedMoves.kingPinsUpper[1][57][bit32.rrotate(bit32.band(piecesUpper,preComputedMoves.kingPinsMaskUpper[1][57]),1)]) then
					table.insert(moves,Vector3.new(61,59,11))
				end
				if bit32.band(pieceMovesUpper[kingPos], 1610612736) == 1610612736 and bit32.btest(kingPosBitboardUpper,preComputedMoves.kingPinsUpper[1][64][bit32.rrotate(bit32.band(piecesUpper,preComputedMoves.kingPinsMaskUpper[1][64]),1)]) then
					table.insert(moves,Vector3.new(61,63,12))
				end
			end
			pieceMovesUpper[kingPos] = bit32.band(pieceMovesUpper[kingPos], 674758656)
		else
			if inCheck == false then
				pieceMovesLower[kingPos] = bit32.band(pieceMovesLower[kingPos], preComputedMoves.castleMaskWhite[1+bit32.band(self.castlingRights,12)//4])
				if bit32.band(pieceMovesLower[kingPos], 12) == 12 and bit32.btest(kingPosBitboardLower,preComputedMoves.kingPinsLower[1][1][bit32.band(piecesLower,preComputedMoves.kingPinsMaskLower[1][1])]) then
					table.insert(moves,Vector3.new(5,3,11))
				end
				if bit32.band(pieceMovesLower[kingPos], 96) == 96 and bit32.btest(kingPosBitboardLower,preComputedMoves.kingPinsLower[1][8][bit32.band(piecesLower,preComputedMoves.kingPinsMaskLower[1][8])]) then
					table.insert(moves,Vector3.new(5,7,12))
				end
			end
			pieceMovesLower[kingPos] = bit32.band(pieceMovesLower[kingPos], 14376)
		end
	end
	for _, pos in self.pieces do
		local piece = self.board[pos]
		if bit32.band(piece,8) == sideToMove and (pieceMovesLower[pos] > 0 or pieceMovesUpper[pos] > 0) then
			if pos == kingPos then
				self:convertMovesFromBitboard(moves,pos,pieceMovesLower[pos],pieceMovesUpper[pos],false)
			elseif piece == sideToMove + 3 then
				self:convertMovesFromBitboard(moves,pos,bit32.band(pieceMovesLower[pos],bit32.bor(additionalPawnMovesLower, limitMovesForChecksLower)),bit32.band(pieceMovesUpper[pos], bit32.bor(additionalPawnMovesUpper, limitMovesForChecksUpper)),true)
			else
				self:convertMovesFromBitboard(moves,pos,bit32.band(pieceMovesLower[pos],limitMovesForChecksLower),bit32.band(pieceMovesUpper[pos], limitMovesForChecksUpper),false)
			end
		end
	end
	
	--[[for i,pos in self.pieces do
		local piece = self.board[pos]
		local pieceType = bit32.band(piece,7)
		local color = bit32.band(piece,8)
		
		if pieceType == 6 then -- bishop
			
		end
		
	end]]
	
	-- TODO: limit moves to get out of checks
	-- TODO: add castling moves
	-- TODO: add en passant moves
	-- TODO: add promotion moves
	--if onlyCaptures == false then
	local moveScores = {}--table.create(218,0)
	local numMoves = 0
	
	local hashedMove = self.tt:getMove(self.hash)
	
	for i,move in moves do
		local score = 0
		local piece = self.board[move.X]
		local capturedPiece = self.board[move.Y]
		local pieceType = bit32.band(piece,7)
		local value = pieceValues[8+pieceType]
		if capturedPiece ~= 0 then
			score += 10*pieceValues[8+bit32.band(capturedPiece,7)] - value
		end
		
		if move.Z > 1 and move.Z < 10 then
			score += pieceValues[8+move.Z]
		end
		if pieceType ~= 3 then
			if move.Y > 32 and bit32.btest(2^(move.Y-33),pawnAttacksUpper) then
				score -= value
			elseif move.Y < 33 and bit32.btest(2^(move.Y-1),pawnAttacksLower) then
				score -= value
			end
		end
		
		if hashedMove == move then
			score += 10000
		end
		
		numMoves += 1
		moveScores[i] = score
	end
	
	--print(moveScores,moves)
	
	for i = 1,numMoves-1 do
		for j = i+1, 2, -1 do
			local swapI = j-1
			if moveScores[swapI] < moveScores[j] then
				local swap = moves[j]
				moves[j] = moves[swapI]
				moves[swapI] = swap
				swap = moveScores[j]
				moveScores[j] = moveScores[swapI]
				moveScores[swapI] = swap
			end
		end
	end
	--end
	
	--print(moveScores)
	
	return moves, inCheck
end

Board.enPassants = 0
Board.castles = 0
Board.captures = 0
Board.promotions = 0

function Board:unMakeMove()
	self:popPosition()	-- for repetitions
	
	local moveData = self.moveLog[self.fullMoveClock]
	local move = moveData[1]
	local piece = self.board[move.Y]
	self.hash = bit32.bxor(self.hash,self.pieceZobristKeys[move.X][piece],self.pieceZobristKeys[move.Y][piece],self.sideToMoveZobristKey)

	self.board[move.X] = self.board[move.Y]
	self.board[move.Y] = moveData[2]
	
	for i,v in self.pieces do
		if v == move.Y then
			self.pieces[i] = move.X
			break
		end
	end
	
	if moveData[2] ~= 0 then
		self.captures += 1
		-- add piece that was captured back
		table.insert(self.pieces,move.Y)
		self.hash = bit32.bxor(self.hash,self.pieceZobristKeys[move.Y][moveData[2]])
	end

	self.sideToMove = 8 - self.sideToMove	-- switch sides to move
	
	if move.Z == 1 then
		self.enPassants += 1
		if self.sideToMove == 0 then
			table.insert(self.pieces,move.Y + 8)
			self.board[move.Y + 8] = 11 -- white pawn

			self.hash = bit32.bxor(self.hash, self.pieceZobristKeys[move.Y + 8][11])
		else
			table.insert(self.pieces,move.Y - 8)
			self.board[move.Y - 8] = 3	-- black pawn
			
			self.hash = bit32.bxor(self.hash, self.pieceZobristKeys[move.Y - 8][3])
		end
	elseif move.Z == 11 then
		self.castles += 1
		if self.sideToMove == 0 then
			for i,v in self.pieces do
				if v == 60 then
					self.pieces[i] = 57
					break
				end
			end
			self.board[57] = self.board[60]
			self.board[60] = 0
			

			self.hash = bit32.bxor(self.hash, self.pieceZobristKeys[57][5], self.pieceZobristKeys[60][5])
		else
			for i,v in self.pieces do
				if v == 4 then
					self.pieces[i] = 1
					break
				end
			end
			self.board[1] = self.board[4]
			self.board[4] = 0
			

			self.hash = bit32.bxor(self.hash, self.pieceZobristKeys[1][13], self.pieceZobristKeys[4][13])
		end
	elseif move.Z == 12 then
		self.castles += 1
		if self.sideToMove == 0 then
			for i,v in self.pieces do
				if v == 62 then
					self.pieces[i] = 64
					break
				end
			end
			self.board[64] = self.board[62]
			self.board[62] = 0
			

			self.hash = bit32.bxor(self.hash, self.pieceZobristKeys[64][5], self.pieceZobristKeys[62][5])
		else
			for i,v in self.pieces do
				if v == 6 then
					self.pieces[i] = 8
					break
				end
			end
			self.board[8] = self.board[6]
			self.board[6] = 0
			

			self.hash = bit32.bxor(self.hash, self.pieceZobristKeys[8][13], self.pieceZobristKeys[6][13])
		end
	elseif move.Z ~= 0 then
		self.promotions += 1
		self.board[move.X] = self.sideToMove + 3
	end
	
	if self.enPassantTarget ~= 0 then
		self.hash = bit32.bxor(self.hash, self.enPassantZobristKeys[self.enPassantTarget])
	end
	
	if self.castlingRights ~= moveData[4] then
		self.hash = bit32.bxor(self.hash, self.castlingRightsZobristKeys[moveData[4]+1], self.castlingRightsZobristKeys[self.castlingRights+1])
	end
	
	self.halfMoveClock = moveData[3]
	self.castlingRights = moveData[4]
	self.enPassantTarget = moveData[5]
	
	if self.enPassantTarget ~= 0 then
		self.hash = bit32.bxor(self.hash, self.enPassantZobristKeys[self.enPassantTarget])
	end
	
	if bit32.band(7,piece) == 1 then
		if piece > 8 then	-- white
			self.lightKingPos = move.X
		else
			self.darkKingPos = move.X
		end
	end
	table.remove(self.moveLog,self.fullMoveClock)
	
	self.fullMoveClock -= 1
end

local castleRightsUpdater = {--QKqk
	 7, 15, 15, 15,  3, 15, 15, 11,
	15, 15, 15, 15, 15, 15, 15, 15,
	15, 15, 15, 15, 15, 15, 15, 15,
	15, 15, 15, 15, 15, 15, 15, 15,
	15, 15, 15, 15, 15, 15, 15, 15,
	15, 15, 15, 15, 15, 15, 15, 15,
	15, 15, 15, 15, 15, 15, 15, 15,
	13, 15, 15, 15, 12, 15, 15, 14
}



function Board:makeMove(move)
	table.insert(self.moveLog,{move,self.board[move.Y],self.halfMoveClock,self.castlingRights,self.enPassantTarget})
	
	local resetRepetitions = 0
	
	local piece = self.board[move.X]

	if bit32.band(7,piece) == 1 then
		if piece > 8 then	-- white
			self.lightKingPos = move.Y
		else
			self.darkKingPos = move.Y
		end
	end
	
	if self.enPassantTarget ~= 0 then
		self.hash = bit32.bxor(self.hash, self.enPassantZobristKeys[self.enPassantTarget])
	end
	
	if bit32.band(self.board[move.X],7) == 3 then
		self.halfMoveClock = 0
		if move.X - move.Y == 16 then
			self.enPassantTarget = move.Y + 8

			self.hash = bit32.bxor(self.hash, self.enPassantZobristKeys[move.Y + 8])
		elseif move.Y - move.X == 16 then
			self.enPassantTarget = move.Y - 8
			
			self.hash = bit32.bxor(self.hash, self.enPassantZobristKeys[move.Y - 8])
		else
			self.enPassantTarget = 0
		end
		resetRepetitions = true
	elseif self.board[move.Y] ~= 0 then
		self.enPassantTarget = 0
		self.halfMoveClock = 0
		resetRepetitions = true
	else
		self.halfMoveClock += 1
		self.enPassantTarget = 0
	end
	
	
	local removeI = 0
	for i,p in self.pieces do
		if p == move.Y then
			removeI = i
		elseif p == move.X then
			self.pieces[i] = move.Y
		end
	end
	
	if removeI ~= 0 then
		table.remove(self.pieces,removeI)
		self.hash = bit32.bxor(self.hash, self.pieceZobristKeys[move.Y][self.board[move.Y]])
	end
	
	self.board[move.Y] = self.board[move.X]
	self.board[move.X] = 0
	local oldCastleRights = self.castlingRights
	
	self.castlingRights = bit32.band(self.castlingRights, castleRightsUpdater[move.X], castleRightsUpdater[move.Y])
	
	if self.castlingRights ~= oldCastleRights then
		self.hash = bit32.bxor(self.hash, self.castlingRightsZobristKeys[oldCastleRights+1], self.castlingRightsZobristKeys[self.castlingRights+1])
	end
	
	if move.Z == 1 then
		if self.sideToMove == 0 then
			local pos = move.Y + 8
			self.board[pos] = 0
			for i,p in self.pieces do
				if p == pos then
					table.remove(self.pieces,i)
					break
				end
			end
			
			self.hash = bit32.bxor(self.hash, self.pieceZobristKeys[pos][11])
		else
			local pos = move.Y - 8
			self.board[pos] = 0
			for i,p in self.pieces do
				if p == pos then
					table.remove(self.pieces,i)
					break
				end
			end

			self.hash = bit32.bxor(self.hash, self.pieceZobristKeys[pos][3])
		end
		resetRepetitions = true
	elseif move.Z == 11 then
		if self.sideToMove == 0 then
			for i,v in self.pieces do
				if v == 57 then
					self.pieces[i] = 60
					break
				end
			end
			self.board[60] = self.board[57]
			self.board[57] = 0
			

			self.hash = bit32.bxor(self.hash, self.pieceZobristKeys[60][5], self.pieceZobristKeys[57][5])
		else
			for i,v in self.pieces do
				if v == 1 then
					self.pieces[i] = 4
					break
				end
			end
			self.board[4] = self.board[1]
			self.board[1] = 0
			

			self.hash = bit32.bxor(self.hash, self.pieceZobristKeys[4][13], self.pieceZobristKeys[1][13])
		end
	elseif move.Z == 12 then
		if self.sideToMove == 0 then
			for i,v in self.pieces do
				if v == 64 then
					self.pieces[i] = 62
					break
				end
			end
			self.board[62] = self.board[64]
			self.board[64] = 0
			

			self.hash = bit32.bxor(self.hash, self.pieceZobristKeys[62][5], self.pieceZobristKeys[64][5])
		else
			for i,v in self.pieces do
				if v == 8 then
					self.pieces[i] = 6
					break
				end
			end
			self.board[6] = self.board[8]
			self.board[8] = 0
			

			self.hash = bit32.bxor(self.hash, self.pieceZobristKeys[6][13], self.pieceZobristKeys[8][13])
		end
	elseif move.Z ~= 0 then
		self.board[move.Y] = move.Z+self.sideToMove
	end
	self.hash = bit32.bxor(self.hash,self.pieceZobristKeys[move.X][piece],self.pieceZobristKeys[move.Y][piece],self.sideToMoveZobristKey)
	self.sideToMove = 8 - self.sideToMove
	self.fullMoveClock += 1
	
	self:pushPosition(resetRepetitions)
end

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

-- 0010
-- 0101
-- 0110
-- 0111
local endGameStartWeight = 1/125

function Board:eval2(test)
	if self.halfMoveClock == 50 then
		return 0
	end
	if self:countRepetitions() > 2 then
		return 0
	end
	self.countEvaled += 1
	local totalValue = 0
	local opponentPiecesLeft = 0
	local piecesLeft = 0
	local pawnsMiddleGame = 0
	local pawnsEndGame = 0
	for _,v in self.pieces do
		local p = self.board[v]
		local c = bit32.band(8,p)
		local pieceType = bit32.band(p,7)
		totalValue += pieceValues[p]
		if pieceType == 3 then
			if p > 8 then
				pawnsMiddleGame += pawnSquareBonus[v]
				pawnsEndGame += pawnSquareEndgameBonus[v]
			else
				pawnsMiddleGame -= pawnSquareBonus[65-v]
				pawnsEndGame -= pawnSquareEndgameBonus[65-v]
			end
		elseif pieceType ~= 1 then
			if p > 8 then
				totalValue += piecePositionBonuses[pieceType][v]
			else
				totalValue -= piecePositionBonuses[pieceType][65-v]
			end
		end
		
		if self.sideToMove == 0 and p > 8 then
			opponentPiecesLeft += 1
		elseif self.sideToMove > 0 and p < 8 then
			opponentPiecesLeft += 1
		end
		piecesLeft += 1
	end
	
	local friendlyPiecesLeft = piecesLeft - opponentPiecesLeft
	
	
	totalValue += (kingSquareBonus[self.lightKingPos]+pawnsMiddleGame)//(17-opponentPiecesLeft) + (kingSquareEndgameBonus[self.lightKingPos]+pawnsEndGame)//opponentPiecesLeft
	
	totalValue -= kingSquareBonus[65-self.darkKingPos]//(17-friendlyPiecesLeft) + kingSquareEndgameBonus[65-self.darkKingPos]//friendlyPiecesLeft
	
	local endGameEval = (self:endgameEval() * 40)//opponentPiecesLeft
	--[[if test then
		print("eval parts: ",totalValue,endGameEval)
	end]]
	
	if self.sideToMove == 0 then
		return -totalValue + endGameEval
	end
	
	return totalValue + endGameEval
end

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
	
	
	local whiteEndGameEval = 0
	local blackEndGameEval = 0
	local whiteMiddleGameEval = 0
	local blackMiddleGameEval = 0
	
	local whitePawnSquaresUpper = 0
	local whitePawnSquaresLower = 0
	local blackPawnSquaresUpper = 0
	local blackPawnSquaresLower = 0
	
	
	for i = 1, 8 do
		self.eval_pawnsOnFilesTableWhite[i] = 0
		self.eval_pawnsOnFilesTableBlack[i] = 0
	end
	
	
	for _,v in self.pieces do
		local piece = self.board[v]
		local pieceType = piece%8 --bit32.band(piece,7)
		
		if piece > 8 then
			local value = pieceValues[piece]
			whiteMaterial += value
			
			if pieceType == 1 then
				whiteMiddleGameEval += kingSquareBonus[v]
				whiteEndGameEval += kingSquareEndgameBonus[v]
			elseif pieceType == 3 then
				whiteMiddleGameEval += pawnSquareBonus[v]
				whiteEndGameEval += pawnSquareEndgameBonus[v]
				
				if v > 32 then
					whitePawnSquaresUpper += 2^(v-33)
				else
					whitePawnSquaresLower += 2^v
				end
				self.eval_pawnsOnFilesTableWhite[v%8+1] += 1
			else
				--[[if pieceType > 4 then
					if bit32.btest(pieceType,1) then
						whiteMobility += preComputedMoves.bishopMovesCount[v][]
					end
				end]]
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

				if v > 32 then
					blackPawnSquaresUpper += 2^(v-33)
				else
					blackPawnSquaresLower += 2^v
				end
				self.eval_pawnsOnFilesTableBlack[v%8+1] += 1
			else
				--print(pieceType,v)
				blackEval += piecePositionBonuses[pieceType][v]
				endGameSumBlack += endGamePieceValues[pieceType]
				
				if v > 32 then
					blackPawnSquaresUpper += bit32.lshift(1, v-33)
				else
					blackPawnSquaresLower += bit32.lshift(1, v-1)
				end
			end
		end
	end
	
	-- pawn structure
	
	-- TODO: passed pawns and pawn chains
	
	for file = 0, 7 do
		local mask = 0
		
		if self.eval_pawnsOnFilesTableWhite[file+1] > 0 then
			if self.eval_pawnsOnFilesTableWhite[file+1] > 1 then
				blackEval += 25
			end
			if file ~= 0 then
				mask += bit32.lshift(0x1010101, file-1)
			end
			if file ~= 7 then
				mask += bit32.lshift(0x1010101, file+1)
			end

			if not (bit32.btest(mask, whitePawnSquaresLower) or bit32.btest(mask, whitePawnSquaresUpper)) then
				blackEval += 30
			end
		end
		
		if self.eval_pawnsOnFilesTableBlack[file+1] > 0 then
			if self.eval_pawnsOnFilesTableBlack[file+1] > 1 then
				whiteEval += 25
			end
			
			mask = 0
			if file ~= 0 then
				mask += bit32.lshift(0x1010101, file-1)
			end
			if file ~= 7 then
				mask += bit32.lshift(0x1010101, file+1)
			end

			if not (bit32.btest(mask, blackPawnSquaresLower) or bit32.btest(mask, blackPawnSquaresUpper)) then
				whiteEval += 30
			end
		end
	end
	
	-- king safety
	if self.lightKingPos <= 56 and self.board[self.lightKingPos+8] == 11 then	-- test if theres a pawn infront of king
		whiteEval += 25
	end
	if self.darkKingPos >= 9 and self.board[self.darkKingPos-8] == 3 then	-- test if theres a pawn infront of king
		whiteEval += 25
	end
	-- TODO: open files
	
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


function Board:endgameEval(friendlyKingPos,opponentKingPos, material, enemyMaterial, enemyMulti,eval)
	--print(friendlyKingPos, opponentKingPos, material, enemyMaterial, enemyMulti)
	if material > enemyMaterial + 200 and enemyMulti > 0 then
		--print(preComputedMoves.endGameKingEval)
		--print(friendlyKingPos,opponentKingPos)
		--error("Asf")
		return (eval+preComputedMoves.endGameKingEval[friendlyKingPos*64 + opponentKingPos + 1]) * enemyMulti
	end
	return 0
end

function Board:tacticalEval(depth)
	return self:search(depth,-1000000,1000000,1,self.sideToMove,false)
end

function Board:isGameOver()
	local moves,inCheck = self:getLegalMoves()
	if #moves == 0 then
		if inCheck then
			return true, -1
		end
		return true, 0
	end
	
	if self.halfMoveClock == 50 then
		return true, 0
	end
	
	-- TODO: 3 fold repetition
end

function Board:searchOnlyCaptures(alpha,beta,ply,color,extended)
	local eval = self:eval()
	if ply >= self.maxDepthSearchedTo then
		self.maxDepthSearchedTo = ply
	end
	if eval >= beta then
		return beta
	end
	if ply >= self.maxTotalDepth then
		return eval
	end
	if eval > alpha then
		alpha = eval
	end

	local moves,inCheck = self:getLegalMoves(true)
	
	--[[if inCheck and not extended and ply < 6 then
		return self:search(1,alpha,beta,ply,color,true)
	end]]
	
	for _,move in moves do
		self:makeMove(move)
		eval = -self:searchOnlyCaptures(-beta,-alpha,ply + 1,color,extended)
		self:unMakeMove()
		if eval >= beta then
			return beta
		end
		if eval > alpha then
			alpha = eval
		end
	end
	return alpha
end

function Board:search(depth,alpha,beta,ply,color,extended)
	if self.abortSearch then
		return 0, -1
	elseif self.nextBreakTime > 0 and self.nextBreakTime <= tick() then
		task.wait(0.15)
		self.nextBreakTime = tick()+0.5
	elseif self.nextBreakTime < 0 and os.clock() > self.stopTime then
		return 0, -1
	end
	
	if self.halfMoveClock == 50 then
		return 0, -1
	end
	
	local ttLookupEval,ttLookupCheckmatePly = self.tt:lookupEval(self.hash, depth, ply, alpha, beta)
	if ttLookupEval ~= TranspositionTable.lookupFailed then
		self.countTranspositions += 1
		if ply == 0 then
			return ttLookupEval, ttLookupCheckmatePly, self.tt:getMove(self.hash)
		end
		return ttLookupEval, ttLookupCheckmatePly
	end
	
	if self:countRepetitions() > 2 then
		print("found repetition")
		return 0, -1
	end
	
	if depth == 0 then
		return self:searchOnlyCaptures(alpha,beta,ply,color,extended)
	end
	
	
	local moves,inCheck = self:getLegalMoves(false)
	
	
	if #moves == 0 then
		if inCheck then
			if extended then
				return -500000-depth, ply
			else
				return -500002-depth, ply
			end
		end
		return 0, -1
	end
	
	if inCheck and depth == 1 and not extended then
		depth += 2
		extended = true
	end
	
	local checkmatePly = -1
	local bestMove = Vector3.zero
	
	local evalType = TranspositionTable.upperBound
	
	local bestMovesTab
	if ply == 0 then
		bestMovesTab = {}
	end
	
	for _,move in moves do
		self:makeMove(move)
		local eval,checkmateMoves = self:search(depth-1,-beta,-alpha,ply + 1,color,extended)
		eval = -eval
		self:unMakeMove()
		
		if eval == 0 and self.nextBreakTime < 0 and os.clock() > self.stopTime then
			if ply == 0 then
				return alpha, checkmatePly, bestMove, bestMovesTab
			else
				return 0, -1
			end
		end
		
		if ply == 0 then
			table.insert(bestMovesTab,{move,eval})
		end
		
		if eval >= beta then
			self.countPruned += 1
			self.tt:storeEvaluation(self.hash, beta, checkmateMoves, move, depth, TranspositionTable.lowerBound)
			return beta, checkmatePly
		end
		if eval > alpha then
			evalType = TranspositionTable.exact
			
			alpha = eval
			checkmatePly = checkmateMoves
			bestMove = move
		end
	end
	
	if ply == 0 then
		table.sort(bestMovesTab,function(a,b)
			return a[2] > b[2]
		end)
	end
	
	self.tt:storeEvaluation(self.hash,alpha,checkmatePly, bestMove, depth, evalType)
	
	if ply == 0 then
		return alpha, checkmatePly, bestMove, bestMovesTab
	end
	
	return alpha, checkmatePly
end

function encodeSquare(sqr: number)
	return string.char((sqr-1)%8+97) .. tostring((sqr-1)//8+1)
end

local prom = {[2] = "n",[5]="r",[6]="b",[7]="q"}

function encodeMove(move)
	return encodeSquare(move.X)..encodeSquare(move.Y)..(if move.Z  > 1 and move.Z < 10 then prom[move.Z] or "" else "")
end


function Board:startSearch(depth) -- doesnt work anymore
	local alpha = -1000000
	
	local color = self.sideToMove

	local moves,inCheck = self:getLegalMoves(false)

	if #moves == 0 then
		if inCheck then
			warn("You win!")
			return nil
		end
		warn("Stalemate!")
		return nil
	end
	
	local bestMove = nil
	
	local checkmatePly = -1

	for _,move in moves do
		self:makeMove(move)
		local eval,checkmateMoves = self:search(depth-1, -1000000, -alpha,0,color,false)
		eval = -eval
		print(encodeMove(move).." : "..eval)
		if eval > alpha then
			alpha = eval
			bestMove = move
			checkmatePly = checkmateMoves
		end
		self:unMakeMove()
		task.wait()
	end
	return bestMove,alpha,checkmatePly
end

function Board:initializeZobristKeys()
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

function Board:generateZobristHash()
	self.hash = bit32.bxor(self.castlingRightsZobristKeys[self.castlingRights+1],self.enPassantZobristKeys[self.enPassantTarget+1])
	for _,pos in self.pieces do
		local piece = self.board[pos]
		self.hash = bit32.bxor(self.hash,self.pieceZobristKeys[pos][piece])
	end
end

function Board:startIterativeDeepening(searchTimeMs, maxDepth, maxTotalDepth, hideResults)
	self.bestMoveInIteration = Vector3.new()
	self.bestEvalInIteration = 0
	self.checkmatePlyInIteration = 0
	
	self.currentSearchDepth = 0
	
	self.abortSearch = false
	
	local color = self.sideToMove
	
	self.countTranspositions = 0
	self.tt:clear()

	self.countPruned = 0
	self.countEvaled = 0
	self.maxTotalDepth = maxTotalDepth
	
	
	local bestMovesTab
	
	self.nextBreakTime = -1
	self.stopTime = os.clock()+searchTimeMs/1000
	
	--delay(searchTimeMs/1000, function()
	--	self.abortSearch = true
	--	print("aborting search")
	--end)
	
	local bestEval, checkmatePly, bestMove = 0, -1, nil
	local start = os.clock()
	for i = 1,maxDepth do
		task.wait()
		self.maxDepthSearchedTo = 0
		local newbestEval, newcheckmatePly, newbestMove, bestMoves = self:search(i, -1000000, 1000000, 0, color, false)
		
		if not hideResults then warn("Searched (partially) to a depth of "..i.." : "..self.maxDepthSearchedTo.. " ; evals: "..self.countEvaled) end
		
		if os.clock() > self.stopTime then
			break
		end
		
		if bestMove ~= Vector3.zero then bestEval, checkmatePly, bestMove, bestMovesTab = newbestEval, newcheckmatePly, newbestMove, bestMoves end
		
		
		self.currentSearchDepth = i
		
		if (checkmatePly or -1) ~= -1 then
			break
		end
	end
	
	if not hideResults then
		print("\n\n\n")
		for i,v in bestMovesTab or {} do
			print(("%02d : % 5s : %d"):format(i,encodeMove(v[1]),v[2]))
		end
		warn(("\nTranspositions found: %d\nNodes Pruned: %d\nNodes Evaluated: %d\nDepth searched: %d\nCheckmate in: %s"):format(self.countTranspositions,self.countPruned,self.countEvaled,self.currentSearchDepth, if (checkmatePly or -1) >= 0 then tostring(checkmatePly//2) else "N/A"))
	end
	return bestMove, bestEval, checkmatePly
end

function Board:limitlessSearch(statsUpdateCallback: (gameStats: {eval: number, checkMatePly: number, searchDepth: number, maxDepth: number, bestMove: number, bestMovesList: {{}}}) -> ())
	self.bestMoveInIteration = Vector3.new()
	self.bestEvalInIteration = 0
	self.checkmatePlyInIteration = 0

	self.currentSearchDepth = 0

	self.abortSearch = false
	self.readyForNextSearch = false

	local color = self.sideToMove

	self.countTranspositions = 0
	self.countPruned = 0
	self.countEvaled = 0
	self.maxTotalDepth = 512
	
	self.nextBreakTime = tick()+0.5

	self.tt:clear()

	print("starting limitless search")
	
	local i = 1
	while self.abortSearch == false do
		task.wait()
		self.maxDepthSearchedTo = 0
		local newbestEval, newcheckmatePly, newbestMove, bestMoves = self:search(i, -1000000, 1000000, 0, color, false)
		
		if self.nextBreakTime >= tick() then
			task.wait(0.15)
			self.nextBreakTime = tick()+0.5
		end

		warn("Searched to a depth of "..i.." : "..self.maxDepthSearchedTo.. " ; evals: "..self.countEvaled)

		self.currentSearchDepth = i
		
		statsUpdateCallback({
			bestMove = newbestMove,
			checkmatePly = newcheckmatePly or -1,
			eval = if self.sideToMove == 0 then -newbestEval else newbestEval,
			maxDepth = self.maxDepthSearchedTo,
			searchDepth = i,
			bestMovesList = bestMoves
		})

		if (newcheckmatePly or -1) ~= -1 then
			self.abortSearch = true
		end
		i += 1
	end
	self.readyForNextSearch = true
end

return Board
