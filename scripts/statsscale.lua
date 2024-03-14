MolochMod.Lib = include("scripts/lib"):Init(MolochMod)
local lib = MolochMod.Lib
local molochType = Isaac.GetPlayerTypeByName("Moloch", false)
local json = require("json")
--set up some variables
--sizing
local playerMaxTearRange = 1000
local playerMinTearRange = 200
local playerBaseTearRange = 260
local scythesMaxSize = 2.0
local scythesMinSize = 0.75
local danseMinSize = 0.5
local danseMaxSize = 1.5

local function onStart(_, isContinued)
    local player = Isaac.GetPlayer()
    if isContinued then
        player:AddCacheFlags(CacheFlag.CACHE_SIZE)
        player:AddCacheFlags(CacheFlag.CACHE_RANGE)
        player:EvaluateItems()
    else
        MolochMod:RemoveData()
        MolochMod.PERSISTENT_DATA.SCYTHES_SCALE = nil
        MolochMod.PERSISTENT_DATA.DANSE_SCALE = nil
        player:AddCacheFlags(CacheFlag.CACHE_SIZE)
        player:AddCacheFlags(CacheFlag.CACHE_RANGE)
        player:EvaluateItems()
    end
end
MolochMod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, onStart)

function MolochMod:EvaluateCache(player, cacheFlags)
    if player:GetPlayerType() ~= molochType then
        return -- End the function early. The below code doesn't run, as long as the player isn't Moloch.
    end

    --scalling the scythes accordingly to player size and range
    local scythes = MolochMod:GetScythes(player)
    local playerData = player:GetData()

    --set data if not set already
    MolochMod.PERSISTENT_DATA.SCYTHES_SCALE = MolochMod.PERSISTENT_DATA.SCYTHES_SCALE or 1.0
    MolochMod.PERSISTENT_DATA.DANSE_SCALE = MolochMod.PERSISTENT_DATA.DANSE_SCALE or 1.0
    playerData.scythesScale = MolochMod.PERSISTENT_DATA.SCYTHES_SCALE
    playerData.danseScale = MolochMod.PERSISTENT_DATA.DANSE_SCALE

    if cacheFlags & CacheFlag.CACHE_SIZE == CacheFlag.CACHE_SIZE then
        if scythes ~= nil then
            local size = player.SpriteScale
            local scale = playerData.scythesScale
            local playerData = player:GetData()
            --size scaling condition
            if size.X * size.Y > scale ^ 2 then
                playerData.scythesScale = playerData.scythesScale * 1.25
                playerData.danseScale = playerData.danseScale * 1.25
            elseif size.X * size.Y > scale ^ 2 then
                playerData.scythesScale = playerData.scythesScale * 0.8
                playerData.danseScale = playerData.danseScale * 0.8
            end
            if playerData.scythesScale ~= nil then
                --setting and saving needed data
                scythes.SpriteScale = Vector(playerData.scythesScale, playerData.scythesScale)
                MolochMod.PERSISTENT_DATA.SCYTHES_SCALE = playerData.scythesScale
                MolochMod.PERSISTENT_DATA.DANSE_SCALE = playerData.danseScale
            end
        end
    end
    if cacheFlags & CacheFlag.CACHE_RANGE == CacheFlag.CACHE_RANGE then
        if scythes ~= nil then
            local range = player.TearRange
            local playerData = player:GetData()
            --range scaling algorithm
            if (range > playerBaseTearRange) then
                playerData.scythesScale = math.min(
                    lib.Lerp(playerData.scythesScale, scythesMaxSize,
                        (range - playerBaseTearRange) / (playerMaxTearRange - playerBaseTearRange)),
                    scythesMaxSize)
                playerData.danseScale = math.min(
                    lib.Lerp(playerData.danseScale, danseMaxSize,
                        (range - playerBaseTearRange) / (playerMaxTearRange - playerBaseTearRange)),
                    danseMaxSize)
            else
                playerData.scythesScale = math.max(
                    lib.Lerp(scythesMinSize, playerData.scythesScale,
                        (range - playerMinTearRange) / (playerBaseTearRange - playerMinTearRange)),
                    scythesMinSize)
                playerData.danseScale = math.max(
                    lib.Lerp(danseMinSize, playerData.danseScale,
                        (range - playerMinTearRange) / (playerBaseTearRange - playerMinTearRange)),
                    danseMinSize)
            end
            if playerData.scythesScale ~= nil then
                --setting and saving needed data
                scythes.SpriteScale = Vector(playerData.scythesScale, playerData.scythesScale)
                MolochMod.PERSISTENT_DATA.SCYTHES_SCALE = playerData.scythesScale
                MolochMod.PERSISTENT_DATA.DANSE_SCALE = playerData.danseScale
            end
        end
    end
end

MolochMod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, MolochMod.EvaluateCache)
