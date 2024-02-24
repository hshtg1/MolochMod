local sfx = SFXManager()
local game = Game()
MolochMod.Lib = include("scripts/lib"):Init(MolochMod)
local lib = MolochMod.Lib
local DANSE_MACABRE_ITEM_ID = Isaac.GetItemIdByName("Danse Macabre")
local DANCE_EFFECT_ID = Isaac.GetEntityVariantByName("Danse Macabre")
local molochType = Isaac.GetPlayerTypeByName("Moloch", false)
local DANCE_DAMAGE_MULTIPLIER = 0.5
local DANSE_SPIN = Isaac.GetSoundIdByName("Danse Macabre")

function MolochMod:InitializeDanseMacabre(player)
    if player:GetPlayerType() ~= molochType then
        return -- End the function early. The below code doesn't run, as long as the player isn't Moloch.
    end
    player:SetPocketActiveItem(DANSE_MACABRE_ITEM_ID, ActiveSlot.SLOT_POCKET, true)
end

MolochMod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, MolochMod.InitializeDanseMacabre)

function MolochMod:UseDanseMacabre(collectibleType, rng, player, useFlags, activeSlot, _)
    if game:IsPauseMenuOpen() then
        return
    end
    local effect = Isaac.Spawn(EntityType.ENTITY_EFFECT, DANCE_EFFECT_ID, 0, player.Position, Vector(0, 0), player)
        :ToEffect()
    effect:FollowParent(player)
    local sprite = effect:GetSprite()
    --hide the scythes for the duration of the spin/dance animation
    MolochMod:HideScythe(false)
    MolochMod:SetAppearTimer(sprite:GetCurrentAnimationData():GetLength() / 60)
    sfx:Play(DANSE_SPIN)
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
    --local data = dance:GetData()

    -- Handle removing the animation when the spin is done.
    if sprite:IsFinished("Dance") then
        dance:Remove()
        MolochMod:HideScythe(true)
        return
    end
    for i = 1, 2 do
        -- Get the "null capsule", which is the hitbox defined by the null layer in the anm2.
        local capsule = dance:GetNullCapsule("Hit" .. i)

        -- Search for all enemies within the capsule.
        for _, entity in ipairs(Isaac.FindInCapsule(capsule, EntityPartition.ENEMY)) do
            -- Make sure it can be hurt.
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
                    entity:TakeDamage(player.Damage * DANCE_DAMAGE_MULTIPLIER, 0, EntityRef(player), 0)
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
