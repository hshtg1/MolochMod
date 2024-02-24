MolochMod.Lib = include("scripts/lib"):Init(MolochMod)
local lib = MolochMod.Lib
local molochType = Isaac.GetPlayerTypeByName("Moloch", false)
--set up some variables
--sizing
local playerMaxTearRange = 1000
local playerMinTearRange = 200
local playerBaseTearRange = 260
local scythesMaxSize = 2.0
local scythesMinSize = 0.75
--attack delay
local playerMaxTears = 1000.0
local playerMinTears = 200.0
local playerBaseTears = 10.0
local scythesMaxTears = 1.0
local scythesMinTears = 0.01

function MolochMod:EvaluateCache(player, cacheFlags)
    if player:GetPlayerType() ~= molochType then
        return -- End the function early. The below code doesn't run, as long as the player isn't Moloch.
    end
    --scalling the scythes accordingly to player size and range
    local scythes = MolochMod:GetScythes(player)
    local playerData = player:GetData()
    playerData.scythesScale = 1.0
    playerData.scythesDelay = 0.4
    if cacheFlags & CacheFlag.CACHE_SIZE == CacheFlag.CACHE_SIZE then
        if scythes ~= nil then
            if (scythes.SpriteScale.X > player.SpriteScale.X) then
                scythes.SpriteScale = scythes.SpriteScale * 0.8
                playerData.scythesScale = playerData.scythesScale * 0.8
            elseif (player.SpriteScale.X > scythes.SpriteScale.X) then
                scythes.SpriteScale = scythes.SpriteScale * 1.25
                playerData.scythesScale = playerData.scythesScale * 1.25
            end
        end
    end
    if cacheFlags & CacheFlag.CACHE_RANGE == CacheFlag.CACHE_RANGE then
        if scythes ~= nil then
            local range = player.TearRange
            local playerData = player:GetData()
            if (range > playerBaseTearRange) then
                playerData.scythesScale = math.min(
                    lib.Lerp(1.0, scythesMaxSize,
                        (range - playerBaseTearRange) / (playerMaxTearRange - playerBaseTearRange)),
                    scythesMaxSize)
            else
                playerData.scythesScale = math.max(
                    lib.Lerp(scythesMinSize, 1.0,
                        (range - playerMinTearRange) / (playerBaseTearRange - playerMinTearRange)),
                    scythesMinSize)
            end

            scythes.SpriteScale = Vector(playerData.scythesScale, playerData.scythesScale)
        end
    end
    if cacheFlags & CacheFlag.CACHE_FIREDELAY == CacheFlag.CACHE_FIREDELAY then
        if scythes ~= nil then
            local tears = player.MaxFireDelay
            local playerData = player:GetData()
            if (tears > playerBaseTears) then
                playerData.scythesDelay = math.min(
                    lib.Lerp(0.4, scythesMaxTears,
                        (tears - playerBaseTears) / (playerMaxTears - playerBaseTears)),
                    scythesMaxTears)
            else
                playerData.scythesDelay = math.max(
                    lib.Lerp(scythesMinTears, 0.4,
                        (tears - playerMinTears) / (playerBaseTears - playerMinTears)),
                    scythesMinTears)
            end
        end
        if (playerData.scythesDelay ~= nil) then
            MolochMod:SetSwingTimer(playerData.scythesDelay)
        end
    end
end

MolochMod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, MolochMod.EvaluateCache)

function MolochMod:UsePillEvaluate(pillEffectID, player, useFlags)
    player:AddCacheFlags(CacheFlag.CACHE_SIZE)
    player:AddCacheFlags(CacheFlag.CACHE_RANGE)
    player:EvaluateItems()
end

MolochMod:AddCallback(ModCallbacks.MC_USE_PILL, MolochMod.UsePillEvaluate)
