local scytheMod = RegisterMod("Repentogon Null Capsule Example", 1)
local sfx = SFXManager()


-- Setup some constants.
local SCYTHE_EFFECT_ID = Isaac.GetEntityVariantByName("Scythe Swing")
local DAMAGE_MULTIPLIER = 2.5
local clubOffset = Vector(-5,0)
local scythe_cache = nil
local maxAnimTimer = 0.4
local animTimer = 0

function scytheMod:SwingClub()
    if  Input.GetActionValue(ButtonAction.ACTION_SHOOTLEFT, 0) > 0.5 or
        Input.GetActionValue(ButtonAction.ACTION_SHOOTRIGHT, 0) > 0.5 or
        Input.GetActionValue(ButtonAction.ACTION_SHOOTUP, 0) > 0.5 or
        Input.GetActionValue(ButtonAction.ACTION_SHOOTDOWN, 0) > 0.5
     then
        local sprite = scythe_cache:GetSprite()
        animTimer = animTimer - 1/60
        if sprite:IsPlaying("Swing") == false and animTimer <= 0 then
            sprite:Play("Swing", true)
            animTimer = maxAnimTimer
            sfx:Play(SoundEffect.SOUND_SWORD_SPIN)
        end
        sprite:Update()
    end
end

scytheMod:AddCallback(ModCallbacks.MC_POST_RENDER, scytheMod.SwingClub)

--Dont allow the player to shoot tears
function SetBlindfold(player, enabled, modifyCostume)
    local game = Game()
    local character = player:GetPlayerType()
    local challenge = Isaac.GetChallenge()
  
    if enabled then
      game.Challenge = Challenge.CHALLENGE_SOLAR_SYSTEM -- This challenge has a blindfold
      player:ChangePlayerType(character)
      game.Challenge = challenge
  
      -- The costume is applied automatically
      if not modifyCostume then
        player:TryRemoveNullCostume(NullItemID.ID_BLINDFOLD)
      end
    else
      game.Challenge = Challenge.CHALLENGE_NULL
      player:ChangePlayerType(character)
      game.Challenge = challenge
  
      if modifyCostume then
        player:TryRemoveNullCostume(NullItemID.ID_BLINDFOLD)
      end
    end
  end

function scytheMod:InitializeScythe(player)
    
end

local function onStart(_,bool)
    local player = Isaac.GetPlayer()
    SetBlindfold(player,true,false)
    local effect = Isaac.Spawn(EntityType.ENTITY_EFFECT, SCYTHE_EFFECT_ID, 0, player.Position, Vector.Zero, player):ToEffect()
    effect:FollowParent(player)
    effect:AddEntityFlags(EntityFlag.FLAG_PERSISTENT)
    scythe_cache = effect
end

scytheMod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, onStart)

-- Now, let's handle capsules.
-- Capsules are our hitboxes.
---@param scythe EntityEffect
function scytheMod:ScytheEffectUpdate(scythe)
    scythe_cache = scythe
    local sprite = scythe_cache:GetSprite()
    local player = scythe.Parent:ToPlayer()
    local data = scythe:GetData()
    
    --Rotate the pipe based on player direction
    local direction = player:GetMovementDirection()
    print(player:GetAimDirection())
    local rot = (direction-3) * 90
    sprite.Rotation = rot + 70
    --apply club offset
    --sprite.Offset = clubOffset
    --find the minimal angle distance between target rotation and sprite rotation
    --rotate the sprite according to the player movement direction
    
            
    -- We are going to use this table as a way to make sure enemies are only hurt once in a swing.
    -- This line will either set the hit blacklist to itself, or create one if it doesn't exist.
    data.HitBlacklist = data.HitBlacklist or {}

    -- We're doing a for loop before because the effect is based off of Spirit Sword's anm2.
    -- Spirit Sword's anm2 has two hitboxes with the same name with a different number at the ending, so we use a for loop to avoid repeating code.
    for i = 1, 2 do
        -- Get the "null capsule", which is the hitbox defined by the null layer in the anm2.
        local capsule = scythe:GetNullCapsule("Hit" .. i)
        if(sprite:IsPlaying("Swing")) then
            -- Search for all enemies within the capsule.
        for _, enemy in ipairs(Isaac.FindInCapsule(capsule, EntityPartition.ENEMY)) do
            -- Make sure it can be hurt.
            if enemy:IsVulnerableEnemy()
            and enemy:IsActiveEnemy()
            and not data.HitBlacklist[GetPtrHash(enemy)] then
                -- Now hurt it.
                enemy:TakeDamage(player.Damage * DAMAGE_MULTIPLIER, 0, EntityRef(player), 0)

                -- Add it to the blacklist, so it can't be hurt again.
                --data.HitBlacklist[GetPtrHash(enemy)] = true
                -- Do some fancy effects, while we're at it.
                enemy:BloodExplode()
                enemy:MakeBloodPoof(enemy.Position, nil, 0.5)
                sfx:Play(SoundEffect.SOUND_DEATH_BURST_LARGE)
            end
            end
        end
    end
end
-- Connect the callback, only for our effect.
scytheMod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, scytheMod.ScytheEffectUpdate, SCYTHE_EFFECT_ID)