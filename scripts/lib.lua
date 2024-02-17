local lib = {}
local game = MolochMod.Game

-- Width of a grid square.
local GRID_WIDTH = 40
-- Diagonal width of a grid square.
local GRID_DIAGONAL = GRID_WIDTH * math.sqrt(2)

function lib:Init(modRef)
	MolochMod = modRef
	return lib
end

--inspired by internet
function lib.QuadraticInterp(p1, p2, x)
	return ((-3 / 2) * p1 + (3 / 2) * p2) * (x ^ 2) + ((-1 / 2) * p1 + (1 / 2) * p2) * x + p1
end

function lib.FindGridEntitiesInRadius(pos, radius)
	local foundGrids = {}

	local room = game:GetRoom()
	local roomWidth = room:GetGridWidth()

	local startGrid = room:GetClampedGridIndex(pos + Vector(-radius, -radius))
	local endGrid = room:GetClampedGridIndex(pos + Vector(radius, radius))

	local w = (endGrid % roomWidth) - (startGrid % roomWidth)
	local h = math.floor(endGrid / roomWidth) - math.floor(startGrid / roomWidth)

	for x = 0, w do
		for y = 0, h do
			local gridIndex = startGrid + x + roomWidth * y
			local gridEntity = room:GetGridEntity(gridIndex)
			if gridEntity then
				local gridPos = room:GetGridPosition(gridIndex)
				local dist = gridPos:Distance(pos)
				if dist <= radius or (dist <= radius + GRID_DIAGONAL * 0.5 and gridIndex == room:GetGridIndex(pos + (gridPos - pos):Resized(radius))) then
					table.insert(foundGrids, gridEntity)
				end
			end
		end
	end

	return foundGrids
end

function lib.ShortAngleDis(from, to)
	local maxAngle = 360
	local disAngle = (to - from) % maxAngle

	return ((2 * disAngle) % maxAngle) - disAngle
end

function lib.LerpAngle(from, to, fraction)
	return from + lib.ShortAngleDis(from, to) * fraction
end

function lib.Len(table)
	local lengthNum = 0
	for k, v in pairs(table) do
		lengthNum = lengthNum + 1
	end
	return lengthNum
end

function lib.PrintTable(table)
	for k, v in pairs(table) do
		print(table[k])
	end
end

return lib
