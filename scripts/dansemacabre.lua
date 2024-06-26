local sfx = SFXManager()
local game = Game()
MolochMod.Lib = include("scripts/lib"):Init(MolochMod)
local lib = MolochMod.Lib
local DANSE_MACABRE_ITEM_ID = Isaac.GetItemIdByName("Danse Macabre")
local DANCE_EFFECT_ID = Isaac.GetEntityVariantByName("Danse Macabre")
local GLOW_EFFECT_ID = Isaac.GetEntityVariantByName("Glow")
local molochType = Isaac.GetPlayerTypeByName("Moloch", false)
local DANSE_SPIN = Isaac.GetSoundIdByName("Danse Macabre")

--constants
local MIN_DANCE_DAMAGE_MULTIPLIER = 0.1
local MAX_DANCE_DAMAGE_MULTIPLIER = 0.4
local DANCE_DAMAGE_MULTIPLIER = 0
local killCount = 0
local lerpSpeed = 0.5
local lerpR = 1
local lerpG = 1
local lerpB = 1
--cached glow
local glow
local glowStage = 1
--danse scaling
local extraKillDanseScale = 0
local maxDanseScale = 1.5
--temporary stages
local maxDanseTimer = 150
local addedStage = false

--setting resetting some values
local function onStart(_, continued)
    if continued then
        if MolochMod.PERSISTENT_DATA.GLOW_STAGE ~= nil then
            glowStage = MolochMod.PERSISTENT_DATA.GLOW_STAGE
        end
        return
    end
    DANCE_DAMAGE_MULTIPLIER = MIN_DANCE_DAMAGE_MULTIPLIER
    killCount = 0
    lerpR = 1
    lerpG = 1
    lerpB = 1
end
MolochMod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, onStart)

--setting pocket item
function MolochMod:InitializeDanseMacabre(player)
    if player:GetPlayerType() ~= molochType then
        return -- End the function early. The below code doesn't run, as long as the player isn't Moloch.
    end
    --read data
    player:SetPocketActiveItem(DANSE_MACABRE_ITEM_ID, ActiveSlot.SLOT_POCKET, true)
    local playerData = player:GetData()
    playerData.danseScale = playerData.danseScale or 1.0
    if MolochMod.PERSISTENT_DATA.KILLCOUNT ~= nil then
        killCount = MolochMod.PERSISTENT_DATA.KILL_COUNT
    end
    --timer which makes the danse stages temporary
    playerData.danseTimer = maxDanseTimer
    --spawn glow
    -- if glow == nil then
    --     glow = Isaac.Spawn(EntityType.ENTITY_EFFECT, GLOW_EFFECT_ID, 0, player.Position, Vector(0, 0), player)
    --         :ToEffect()
    --     glow:FollowParent(player)
    --     glow:AddEntityFlags(EntityFlag.FLAG_PERSISTENT)
    --     glow.DepthOffset = -10
    -- end
end

MolochMod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, MolochMod.InitializeDanseMacabre)

function MolochMod:EvaluateDanseTimer(player)
    local playerData = player:GetData()
    if killCount > 0 then
        playerData.danseTimer = playerData.danseTimer - 1
        if playerData.danseTimer <= 0 then
            killCount = killCount - 1
            playerData.danseTimer = maxDanseTimer
            if killCount % 5 == 4 then
                if glowStage > 1 then
                    glowStage = glowStage - 1
                    sfx:Play(SoundEffect.SOUND_DEATH_CARD, 0.5, 0, false, 0.8)
                    MolochMod:SetGlow(glowStage, player)
                end
            end
        end
        print("KillCount: " .. tostring(killCount))
    elseif playerData.danseTimer then
        if playerData.danseTimer < maxDanseTimer then
            playerData.danseTimer = maxDanseTimer
        end
    end
end

MolochMod:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, MolochMod.EvaluateDanseTimer)

--using danse and spawning the effect
function MolochMod:UseDanseMacabre(collectibleType, rng, player, useFlags, activeSlot, _)
    if game:IsPauseMenuOpen() then
        return
    end
    local effect = Isaac.Spawn(EntityType.ENTITY_EFFECT, DANCE_EFFECT_ID, 0, player.Position, Vector(0, 0), player)
        :ToEffect()
    effect:FollowParent(player)
    local effectSprite = effect:GetSprite()
    effectSprite:Play("Dance Stage " .. tostring(glowStage))
    --hide the scythes for the duration of the spin/dance animation
    MolochMod:HideScythe(false, true)
    sfx:Play(DANSE_SPIN, 1.3)
    return {
        Discharge = true,
        Remove = false,
        ShowAnim = false,
    }
end

MolochMod:AddCallback(ModCallbacks.MC_USE_ITEM, MolochMod.UseDanseMacabre, DANSE_MACABRE_ITEM_ID)

function MolochMod:DanceEffectUpdate(dance)
    local sprite = dance:GetSprite()
    local player = dance.Parent:ToPlayer()
    if player:GetPlayerType() ~= molochType then
        return -- End the function early. The below code doesn't run, as long as the player isn't Moloch.
    end
    --local data = dance:GetData()
    print("DamageMultiplier:" .. tostring(DANCE_DAMAGE_MULTIPLIER))

    -- Handle removing the animation when the spin is done.
    if sprite:IsFinished("Dance Stage " .. tostring(glowStage)) then
        dance:Remove()
        MolochMod:HideScythe(true, false)
        DANCE_DAMAGE_MULTIPLIER = MIN_DANCE_DAMAGE_MULTIPLIER
        lerpR = 1
        lerpG = 1
        lerpB = 1
        killCount = 0
        glowStage = 1
        extraKillDanseScale = 0
        addedStage = false
        MolochMod:SetGlow(glowStage, player)
        return
    end
    --scale danse macabre according to the statsscale values
    local danseScale = player:GetData().danseScale + extraKillDanseScale
    if (danseScale > maxDanseScale) then
        danseScale = maxDanseScale
    end
    print(danseScale)
    dance.SpriteScale = Vector(danseScale, danseScale)
    for i = 1, 2 do
        -- Get the "null capsule", which is the hitbox defined by the null layer in the anm2.
        local capsule = dance:GetNullCapsule("Hit" .. i)

        -- Search for all enemies within the capsule.
        for _, entity in ipairs(Isaac.FindInCapsule(capsule, EntityPartition.ENEMY)) do
            -- Make sure it can be hurt and its a valid entity
            local isValidEnemy = entity:IsVulnerableEnemy() and entity:IsActiveEnemy()
            local isFireplace = (entity:GetType() == EntityType.ENTITY_FIREPLACE)
            local isEntityPoop = (entity:GetType() == EntityType.ENTITY_POOP)
            local isBomb = (entity:GetType() == EntityType.ENTITY_BOMB)
            local isMovableTNT = (entity:GetType() == EntityType.ENTITY_MOVABLE_TNT)
            if (isValidEnemy or isFireplace or isEntityPoop or isBomb or isMovableTNT) then
                if (isFireplace or isEntityPoop or isMovableTNT) then
                    entity:TakeDamage((player.Damage + 10) * DAMAGE_MULTIPLIER, 0, EntityRef(player), 0)
                elseif isBomb then
                    --hitting bombs with the scythes knocks them back
                    local bomb = entity:ToBomb()
                    if (bomb == nil) then return end
                    if bomb.Variant ~= BombVariant.BOMB_ROCKET and bomb.Variant ~= BombVariant.BOMB_ROCKET_GIGA
                    then
                        bomb.Velocity = bomb.Position:__sub(player.Position):Resized(10)
                        sfx:Play(SoundEffect.SOUND_SCAMPER, 0.78, 0, false, 0.8)
                    end
                else
                    entity:TakeDamage(player.Damage * DANCE_DAMAGE_MULTIPLIER + 0.5, 0, EntityRef(player), 0)
                end
            end
        end
        --also damage grid entities
        local room = game:GetRoom()
        for _, gridEntity in pairs(lib.FindGridEntitiesInRadius(capsule:GetPosition(), capsule:GetF1())) do
            local gridIndex = gridEntity:GetGridIndex()
            room:DamageGrid(gridIndex, 100)
        end
    end
end

MolochMod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, MolochMod.DanceEffectUpdate, DANCE_EFFECT_ID)

--adds extra range to danse with gaining kills
function MolochMod:AddRangeDanse(num)
    extraKillDanseScale = extraKillDanseScale + 0.02 * num
end

--charging danse with kills and applying glow stages
function MolochMod:ChargeDanse(ent)
    local player
    for i = 0, Game():GetNumPlayers() - 1 do
        player = Isaac.GetPlayer(i)
    end
    local playerData = player:GetData()
    if player:GetPlayerType() ~= molochType then
        return -- End the function early. The below code doesn't run, as long as the player isn't Moloch.
    end
    local scythes = playerData.scytheCache
    local data = scythes:GetData()

    if ent:IsEnemy() == false then
        return
    end
    if data.HitBlacklist ~= nil and data.HitBlacklist[GetPtrHash(ent)] then
        if (ent:IsBoss()) then
            killCount = killCount + 5
            MolochMod:AddRangeDanse(5)
        else
            killCount = killCount + 1
            MolochMod:AddRangeDanse(1)
        end
        MolochMod:AddStage()
    end
end

MolochMod:AddCallback(ModCallbacks.MC_POST_ENTITY_KILL, MolochMod.ChargeDanse)

function MolochMod:AddStage()
    local player
    for i = 0, Game():GetNumPlayers() - 1 do
        player = Isaac.GetPlayer(i)
        if player:GetPlayerType() ~= molochType or not player then
            return -- End the function early. The below code doesn't run, as long as the player isn't Moloch.
        end
    end
    local playerData = player:GetData()
    if player:GetPlayerType() ~= molochType then
        return -- End the function early. The below code doesn't run, as long as the player isn't Moloch.
    end
    local scythes = playerData.scytheCache
    local data = scythes:GetData()

    playerData.danseTimer = maxDanseTimer
    print("KillCount:" .. tostring(killCount))
    if (killCount % 5 == 0) then
        DANCE_DAMAGE_MULTIPLIER = DANCE_DAMAGE_MULTIPLIER +
            (MAX_DANCE_DAMAGE_MULTIPLIER - MIN_DANCE_DAMAGE_MULTIPLIER) / 3
        --adding a glow to the player with kills
        if glowStage < 4 then
            glowStage = glowStage + 1
            MolochMod.PERSISTENT_DATA.GLOW_STAGE = glowStage
        end
        MolochMod:ColorScythes()

        if scythes then
            MolochMod:SetGlow(glowStage, player)
        end

        MolochMod.PERSISTENT_DATA.KILL_COUNT = killCount
    end
end

function MolochMod:ColorScythes()
    --color the scythes redder when higher damage multiplier
    lerpR = lib.Lerp(lerpR, 200, 0.001)
    lerpG = lib.Lerp(lerpG, 0, 0.1)
    lerpB = lib.Lerp(lerpB, 0, 0.1)
end

local danseSprite
--render danse macabre item stages
function MolochMod:RenderStages()
    local renderOffset = Vector(445, 247)
    local player = nil
    for i = 0, Game():GetNumPlayers() - 1 do
        player = Isaac.GetPlayer(i)
        if player:GetPlayerType() ~= molochType then
            return -- End the function early. The below code doesn't run, as long as the player isn't Moloch.
        end
    end
    if player ~= nil then
        local slot = 1
        local item = player:GetPocketItem(ActiveSlot.SLOT_PRIMARY)
        if item:GetType() ~= 2 then
            item = player:GetPocketItem(ActiveSlot.SLOT_SECONDARY)
            slot = 2
        end
        if item and item:GetType() == 2 then
            if danseSprite then
                danseSprite.Scale = Vector(1, 1)
                if slot == 2 then
                    renderOffset = renderOffset + Vector(9, -12)
                    danseSprite.Scale = Vector(0.5, 0.5)
                end
                danseSprite:Render(renderOffset, Vector(0, 0), Vector(0, 0))
                danseSprite:Play("Stage " .. tostring(glowStage))
                danseSprite:Update()
            else
                --sprite
                danseSprite = Sprite()
                danseSprite:Load("gfx/danse_stages.anm2", true)
            end
        end
    end
end

MolochMod:AddCallback(ModCallbacks.MC_POST_RENDER, MolochMod.RenderStages)

--fixes going through doors while danse is active
function MolochMod:ResetDanse()
    for i = 0, Game():GetNumPlayers() - 1 do
        local player = Isaac.GetPlayer(i)
        if player:GetPlayerType() ~= molochType then
            return -- End the function early. The below code doesn't run, as long as the player isn't Moloch.
        end
    end
    MolochMod:HideScythe(true)
end

MolochMod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, MolochMod.ResetDanse)

function MolochMod:ClearDanseCharge()
    glow = nil
end

MolochMod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, MolochMod.ClearDanseCharge)

function MolochMod:AddKillCount(num)
    killCount = killCount + num
end

function MolochMod:AddTemporaryDanseStage()
    if not addedStage then
        if killCount % 5 then
            killCount = killCount + 1
        end
        while killCount % 5 ~= 0 do
            killCount = killCount + 1
        end
    end
    addedStage = true
    MolochMod:AddStage()
end
