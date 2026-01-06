-- engine / preComputedMoves.luau

local module = {}

function convertToBitBoard(i) -- 0 <= i < 64: lower, upper
	if i > 31 then
		return 0, bit32.lshift(1,i-32)
	end
	return bit32.lshift(1,i), 0
end

function convertNumbersToBitboard(...)
	local l,u = 0,0
	for _,i in {...} do
		if i > 32 then
			u = bit32.bor(u,bit32.lshift(1,i-33))
		else
			l = bit32.bor(l,bit32.lshift(1,i-1))
		end
	end
	return l,u
end

function genMove(lower,upper,i,j,count)
	if i > 0 and i <= 8 and j > 0 and j <= 8 then
		local moveLower, moveUpper = convertToBitBoard((i-1)*8+j-1)
		return bit32.bor(lower,moveLower), bit32.bor(upper,moveUpper), count+1
	end
	return lower, upper, count
end

function spreadBits(value,maskLower,maskUpper)
	local resultLower = 0
	local resultUpper = 0
	local index = 0
	for i = 0,31 do
		if bit32.btest(maskLower,bit32.lshift(1,i)) then
			resultLower = bit32.bor(resultLower,bit32.lshift(bit32.band(value,bit32.lshift(1,index)),i-index))
			index += 1
		end
	end
	for i = 0,31 do
		if bit32.btest(maskUpper,bit32.lshift(1,i)) then
			resultUpper = bit32.bor(resultUpper,bit32.lshift(bit32.band(value,bit32.lshift(1,index)),i-index))
			index += 1
		end
	end
	return resultLower,resultUpper
end

function extractBits(mask,value)
	local result = 0
	local i = 0
	while mask>0 do
		local count = bit32.countrz(mask)
		mask = bit32.rshift(mask,count+1)
		value = bit32.rshift(value,count)
		result = bit32.bor(result,bit32.lshift(bit32.band(value,1),i))
		value = bit32.rshift(value,1)
		i += 1
	end
	return result
end

function computeMoves(allMovesLower,allMovesUpper, blockersLower,blockersUpper,px,py,directionFile,directionRank,count)
	local x = px
	local y = py
	for i = 1,8 do
		py += directionRank
		px += directionFile

		if px > 8 or px < 1 or py > 8 or py < 1 then
			break
		end

		local moveLower, moveUpper = convertToBitBoard(py*8+px-9)

		allMovesLower = bit32.bor(allMovesLower,moveLower)
		allMovesUpper = bit32.bor(allMovesUpper,moveUpper)
		
		count += 1


		if bit32.btest(blockersLower,moveLower) or bit32.btest(blockersUpper,moveUpper) then
			break
		end
	end

	return allMovesLower,allMovesUpper, count
end

function getDirectionalMoves(movebitBoardLower,movebitBoardUpper,count,x,y,dx,dy)
	local px = x
	local py = y

	for i = 1,8 do
		px += dx
		py += dy

		if px > 8 or px < 1 or py > 8 or py < 1 or (px == 8 and x ~= 8) or (px == 1 and x ~= 1) or (py == 8 and y ~= 8) or (py == 1 and y ~= 1) then
			break
		end

		movebitBoardLower, movebitBoardUpper,count = genMove(movebitBoardLower,movebitBoardUpper, py,px,count)
	end
	return movebitBoardLower,movebitBoardUpper,count
end

function bishopIndexFormula(blockerLower,blockerUpper)
	return bit32.bor(blockerLower,bit32.rrotate(blockerUpper,1))
end

function rookIndexFormula(blockerLower, blockerUpper, pos)
	local file = (pos-1)%8
	if pos <= 32 then
		if file == 0 then
			return bit32.bor(blockerLower, bit32.rrotate(blockerUpper, 1))
		else
			return bit32.bor(blockerLower, bit32.rrotate(blockerUpper, file))
		end
	else
		if file == 0 then
			return bit32.bor(blockerUpper, bit32.rrotate(blockerLower, 1))
		else
			return bit32.bor(blockerUpper, bit32.rrotate(blockerLower, file))
		end
	end
end

module.kingLower = {770, 1797, 3594, 7188, 14444, 28752, 57504, 49216, 197123, 460039, 920078, 1840156, 3680312, 7360624, 14721248, 12599488, 50463488, 117769984, 235539968, 471079936, 942159872, 1884319744, 3768639488, 3225468928, 33751040, 84344832, 168689664, 337379328, 674758656, 1349517312, 2699034624, 1086324736, 50331648, 117440512, 234881024, 469762048, 939524096, 1879048192, 3758096384, 3221225472, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
module.kingUpper = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 7, 14, 28, 56, 112, 224, 192, 770, 1797, 3594, 7188, 14376, 28752, 57504, 49216, 197123, 460039, 920078, 1840156, 3680312, 7360624, 14721248, 12599488, 50463488, 117769984, 235539968, 471079936, 942159872, 1884319744, 3768639488, 3225468928, 33751040, 84344832, 168689664, 337379328, 1815609344, 1349517312, 2699034624, 1086324736}

module.kingAttackLower = {770, 1797, 3594, 7188, 14376, 28752, 57504, 49216, 197123, 460039, 920078, 1840156, 3680312, 7360624, 14721248, 12599488, 50463488, 117769984, 235539968, 471079936, 942159872, 1884319744, 3768639488, 3225468928, 33751040, 84344832, 168689664, 337379328, 674758656, 1349517312, 2699034624, 1086324736, 50331648, 117440512, 234881024, 469762048, 939524096, 1879048192, 3758096384, 3221225472, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
module.kingAttackUpper = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 7, 14, 28, 56, 112, 224, 192, 770, 1797, 3594, 7188, 14376, 28752, 57504, 49216, 197123, 460039, 920078, 1840156, 3680312, 7360624, 14721248, 12599488, 50463488, 117769984, 235539968, 471079936, 942159872, 1884319744, 3768639488, 3225468928, 33751040, 84344832, 168689664, 337379328, 674758656, 1349517312, 2699034624, 1086324736}


module.knightLower = {132096, 329728, 659712, 1319424, 2638848, 5277696, 10489856, 4202496, 33816580, 84410376, 168886289, 337772578, 675545156, 1351090312, 2685403152, 1075839008, 67109890, 134219781, 285217034, 570434068, 1140868136, 2281736272, 268439712, 536879168, 262656, 525568, 1116672, 2233344, 4466688, 8933376, 1089536, 2113536, 67239936, 134545408, 285868032, 571736064, 1143472128, 2286944256, 278921216, 541065216, 33554432, 83886080, 167772160, 335544320, 671088640, 1342177280, 2684354560, 1073741824, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
module.knightUpper = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 5, 10, 20, 40, 80, 160, 64, 516, 1288, 2577, 5154, 10308, 20616, 40976, 16416, 132096, 329728, 659712, 1319424, 2638848, 5277696, 10489856, 4202496, 33816580, 84410376, 168886289, 337772578, 675545156, 1351090312, 2685403152, 1075839008, 67109890, 134219781, 285217034, 570434068, 1140868136, 2281736272, 268439712, 536879168, 262656, 525568, 1116672, 2233344, 4466688, 8933376, 1089536, 2113536}

module.kingOriginSquare = {61,5}

module.castleMaskBlack = {	-- upper (black)
	674758656,
	1748500480,
	741867520,
	1815609344
}

module.castleMaskWhite = { -- QKqk-- lower (white)
	14376,
	14440,
	14380,
	14444
}


module.castleChecksMaskWhite = 40
module.castleChecksMaskBlack = 671088640



function generateMoves(directions,formula, computeCount)
	local finalMovesUpper = {}
	local finalMovesLower = {}

	local blockerMaskLower = {}
	local blockerMaskUpper = {}
	
	local totalFinalMoves = {}

	for rank = 1,8 do
		task.wait()
		for file = 1,8 do
			local movebitBoardLower, movebitBoardUpper,count = 0,0,0
			for _,dir in directions do
				movebitBoardLower, movebitBoardUpper,count = getDirectionalMoves(movebitBoardLower,movebitBoardUpper,count,file,rank,dir.X,dir.Y)
			end

			--print("count: ",count)
			--print(movebitBoardLower,movebitBoardUpper)
			--print("\n")
			local movesLower = {}
			local movesUpper = {}
			local movesCount = {}
			for i = 1, 2^count do
				local blockerI = 1

				local blockerBoardLower, blockerBoardUpper = spreadBits(i-1,movebitBoardLower,movebitBoardUpper)

			--[[
			for j = 1,2 do
				local testLower,testUpper = convertToBitBoard(j-1)
				print(testLower,testUpper)
				print(i,bit32.btest(testLower,movebitBoardLower),bit32.btest(blockerI,i-1),"\n")
				if (bit32.btest(testLower,movebitBoardLower) or bit32.btest(testUpper,movebitBoardUpper)) and bit32.btest(blockerI,i-1) then
					blockerBoardLower = bit32.bor(blockerBoardLower,testLower)
					blockerBoardUpper = bit32.bor(blockerBoardUpper,testUpper)
					blockerI = bit32.lshift(blockerI,1)
				end
			end]]

				local moveLower, moveUpper,count = 0,0,0
				for _,dir in directions do
					moveLower, moveUpper,count = computeMoves(moveLower, moveUpper,blockerBoardLower,blockerBoardUpper,file,rank,dir.X,dir.Y,count)
				end
				local index = formula(blockerBoardLower,blockerBoardUpper, 8*(rank-1)+file)

				movesLower[index] = moveLower
				movesUpper[index] = moveUpper
				if computeCount then
					movesCount[index] = count
				end
			end



			finalMovesLower[(rank-1)*8+file] = movesLower
			finalMovesUpper[(rank-1)*8+file] = movesUpper

			blockerMaskLower[(rank-1)*8+file] = movebitBoardLower
			blockerMaskUpper[(rank-1)*8+file] = movebitBoardUpper
			
			if computeCount then
				totalFinalMoves[(rank-1)*8+file] = movesCount
			end
		end
	end
	
	return finalMovesLower,finalMovesUpper, blockerMaskLower, blockerMaskUpper, totalFinalMoves
end

do	-- generate bishop moves
	local finalMovesLower,finalMovesUpper,blockerMaskLower,blockerMaskUpper,movesCount = generateMoves({Vector2.new(1,1),Vector2.new(-1,-1),Vector2.new(1,-1),Vector2.new(-1,1)},bishopIndexFormula,true)
	
	module.bishopLower = finalMovesLower
	module.bishopUpper = finalMovesUpper
	module.bishopMaskLower = blockerMaskLower
	module.bishopMaskUpper = blockerMaskUpper
	module.bishopMovesCount = movesCount
end

do -- generate bishop pins
	module.bishopPinsMaskLower = {}
	module.bishopPinsMaskUpper = {}
	module.bishopPinsLower = {}
	module.bishopPinsUpper = {}
	
	
	local directions = {Vector2.new(1,1),Vector2.new(-1,-1),Vector2.new(1,-1),Vector2.new(-1,1)}
	for i,dir in directions do
		local pl, pu, ml, mu = generateMoves({dir},bishopIndexFormula)
		module.bishopPinsMaskLower[i] =  ml
		module.bishopPinsMaskUpper[i] =  mu
		module.bishopPinsLower[i] = pl
		module.bishopPinsUpper[i] = pu
	end
end

do -- generate rook moves
	local finalMovesLower,finalMovesUpper,blockerMaskLower,blockerMaskUpper,movesCount = generateMoves({Vector2.new(1,0),Vector2.new(-1,0),Vector2.new(0,1),Vector2.new(0,-1)},rookIndexFormula,true)
	
	module.rookLower = finalMovesLower
	module.rookUpper = finalMovesUpper
	module.rookMaskLower = blockerMaskLower
	module.rookMaskUpper = blockerMaskUpper
	module.rookMovesCount = movesCount
end

do -- generate rook pins
	module.rookPinsMaskLower = {}
	module.rookPinsMaskUpper = {}
	module.rookPinsLower = {}
	module.rookPinsUpper = {}


	local directions = {Vector2.new(1,0),Vector2.new(-1,0),Vector2.new(0,1),Vector2.new(0,-1)}
	for i,dir in directions do
		local pl, pu, ml, mu = generateMoves({dir},bishopIndexFormula)	-- dont need to use rook index formula
		module.rookPinsMaskLower[i] =  ml
		module.rookPinsMaskUpper[i] =  mu
		module.rookPinsLower[i] = pl
		module.rookPinsUpper[i] = pu
	end
end

do
	local directions = {{Vector2.new(1,0),Vector2.new(-1,0)},{Vector2.new(0,1),Vector2.new(0,-1)},{Vector2.new(1,1),Vector2.new(-1,-1)},{Vector2.new(-1,1),Vector2.new(1,-1)}}
	
	module.kingPinsMaskLower = {}
	module.kingPinsMaskUpper = {}
	module.kingPinsLower = {}
	module.kingPinsUpper = {}
	
	for i,dir in directions do
		local pl, pu, ml, mu = generateMoves(dir,bishopIndexFormula)	-- dont need to use rook index formula
		module.kingPinsMaskLower[i] =  ml
		module.kingPinsMaskUpper[i] =  mu
		module.kingPinsLower[i] = pl
		module.kingPinsUpper[i] = pu
	end
end


-- pawns moves

module.pawnStartingPosLower = 0x0000FF00
module.pawnStartingPosUpper = 0x00FF0000

-- there will be precomputed moves for positions with piece blocking the square above starting square and without (2 separate tables) and also another one only for captures (so that that can be ANDed with the peices bitboards). en passant can be made by ORing the en passant target square. pins for en passant can be made by removing the pawn that can be en passanted from the blocking pieces list when checking for pins (separately checking pins using those blocking pieces).


module.pawnMovesBlockingLower = {table.create(64,0),table.create(64,0)}
module.pawnMovesBlockingUpper = {table.create(64,0),table.create(64,0)}
module.pawnMovesLower = {table.create(64,0),table.create(64,0)}
module.pawnMovesUpper = {table.create(64,0),table.create(64,0)}

module.pawnAttacksLower = {table.create(64,0),table.create(64,0)}
module.pawnAttacksUpper = {table.create(64,0),table.create(64,0)}

for i = 9,56 do
	module.pawnMovesBlockingLower[1][i], module.pawnMovesBlockingUpper[1][i] = convertNumbersToBitboard(i-8)
	module.pawnMovesBlockingLower[2][i], module.pawnMovesBlockingUpper[2][i] = convertNumbersToBitboard(i+8)
	module.pawnMovesLower[1][i], module.pawnMovesUpper[1][i] = convertNumbersToBitboard(i-8)
	module.pawnMovesLower[2][i], module.pawnMovesUpper[2][i] = convertNumbersToBitboard(i+8)
	if i <= 16 then
		local newL,newU = convertNumbersToBitboard(i+16)
		module.pawnMovesLower[2][i] = bit32.bor(module.pawnMovesLower[2][i],newL)
		module.pawnMovesUpper[2][i] = bit32.bor(module.pawnMovesUpper[2][i],newU)
	end
	
	if i >= 49 then
		local newL,newU = convertNumbersToBitboard(i-16)
		module.pawnMovesLower[1][i] = bit32.bor(module.pawnMovesLower[1][i],newL)
		module.pawnMovesUpper[1][i] = bit32.bor(module.pawnMovesUpper[1][i],newU)
	end
	if i%8 == 1 then
		module.pawnAttacksLower[1][i], module.pawnAttacksUpper[1][i] = convertNumbersToBitboard(i-7)
		module.pawnAttacksLower[2][i], module.pawnAttacksUpper[2][i] = convertNumbersToBitboard(i+9)
	elseif i%8 == 0 then
		module.pawnAttacksLower[1][i], module.pawnAttacksUpper[1][i] = convertNumbersToBitboard(i-9)
		module.pawnAttacksLower[2][i], module.pawnAttacksUpper[2][i] = convertNumbersToBitboard(i+7)
	else
		module.pawnAttacksLower[1][i], module.pawnAttacksUpper[1][i] = convertNumbersToBitboard(i-7,i-9)
		module.pawnAttacksLower[2][i], module.pawnAttacksUpper[2][i] = convertNumbersToBitboard(i+7,i+9)
	end
	
end


-- endgame stuff

module.endGameKingEval = table.create(4096,0)

for i = 0,63 do
	local opponentFile = i%8
	local opponentRank = i//8
	for j = 0,63 do
		local kingFile = j%8
		local kingRank = j//8
		local distanceFile = math.abs(kingFile-opponentFile)
		local distanceRank = math.abs(kingRank-opponentRank)

		local distanceFromCenterFile = math.max(3-opponentFile,opponentFile-4)
		local distanceFromCenterRank = math.max(3-opponentRank,opponentRank-4)

		module.endGameKingEval[i + j*64 + 1] = 4* (14-(distanceFile+distanceRank)) + 10*(distanceFromCenterFile + distanceFromCenterRank)
	end
end

return module
