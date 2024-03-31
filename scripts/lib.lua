local lib = {}
local game = MolochMod.Game

-- AB+ compatible (and mod-safe) item checks
function lib.HasItem(player, collectibleType, ignoreModifiers)
	if not collectibleType or collectibleType <= 0 then return false end
	return player:HasCollectible(collectibleType, ignoreModifiers) or false
end

function lib.HasItemEffect(player, collectibleType)
	if not collectibleType or collectibleType <= 0 then return false end
	return player:GetEffects():HasCollectibleEffect(collectibleType)
end

-- AB+ compatible TearFlag operations
function lib.HasTearFlag(player, tearflag)
	if not tearflag then return false end
	if REPENTANCE then
		return player.TearFlags & tearflag == tearflag
	else
		return player.TearFlags & tearflag ~= 0
	end
end

function lib.AddTearFlag(entity, tearflag)
	if not tearflag then return false end
	if REPENTANCE then
		entity:AddTearFlags(tearflag)
	elseif not lib.HasTearFlag(entity, tearflag) then
		entity.TearFlags = entity.TearFlags | tearflag
	end
end

function lib.RemoveTearFlag(entity, tearflag)
	if not tearflag then return false end
	if REPENTANCE then
		entity:ClearTearFlags(tearflag)
	elseif lib.HasTearFlag(entity, tearflag) then
		entity.TearFlags = entity.TearFlags - tearflag
	end
end

-- AB+ compatible color constructor
-- Thanks, oatmealine
function lib.NewColor(r, g, b, a, ro, go, bo)
	if not REPENTANCE then
		a = a or 1
		ro = ro or 0
		go = go or 0
		bo = bo or 0

		ro = math.floor(ro * 255)
		go = math.floor(go * 255)
		bo = math.floor(bo * 255)
	end
	return Color(r, g, b, a, ro, go, bo)
end

lib.InvisibleColor = lib.NewColor(1, 1, 1, 0)
lib.NullColor = lib.NewColor(1, 1, 1, 1)

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

function lib.Lerp(first, second, percent)
	return (first + (second - first) * percent)
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

function lib.MakeLookupTable(tab)
	local newTab = {}
	for _, key in pairs(tab) do
		newTab[key] = true
	end
	return newTab
end

lib.VanillaChestVariants = lib.MakeLookupTable({
	PickupVariant.PICKUP_CHEST,
	PickupVariant.PICKUP_SPIKEDCHEST,
	PickupVariant.PICKUP_MIMICCHEST,
	PickupVariant.PICKUP_OLDCHEST,
	PickupVariant.PICKUP_WOODENCHEST,
	PickupVariant.PICKUP_HAUNTEDCHEST,
	PickupVariant.PICKUP_REDCHEST,
	PickupVariant.PICKUP_MOMSCHEST,
	PickupVariant.PICKUP_MEGACHEST
})

lib.UnlockableChestVariants = lib.MakeLookupTable({
	PickupVariant.PICKUP_ETERNALCHEST,
	PickupVariant.PICKUP_LOCKEDCHEST,
})

function lib.IsVanillaChest(entity)
	return entity.Type == EntityType.ENTITY_PICKUP and lib.VanillaChestVariants[entity.Variant] ~= nil
end

function lib.IsUnlockableChest(entity)
	return entity.Type == EntityType.ENTITY_PICKUP and lib.UnlockableChestVariants[entity.Variant] and
		lib.UnlockableChestVariants[entity.Variant] ~= nil
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
