local scytheMod = RegisterMod("MolochMod", 1)
local sfx = SFXManager()


-- Setup some constants.
local SCYTHE_EFFECT_ID = Isaac.GetEntityVariantByName("Scythe Swing")
local DAMAGE_MULTIPLIER = 1.1
local scytheOffset = Vector(-5,0)
local scythe_cache = nil
local maxAnimTimer = 0.3
local animTimer = 0

--handling swinging the scythe
function scytheMod:SwingScythe()
  animTimer = animTimer - 1/60
  --input arrows for swinging
    if  Input.GetActionValue(ButtonAction.ACTION_SHOOTLEFT, 0) > 0.5 or
        Input.GetActionValue(ButtonAction.ACTION_SHOOTRIGHT, 0) > 0.5 or
        Input.GetActionValue(ButtonAction.ACTION_SHOOTUP, 0) > 0.5 or
        Input.GetActionValue(ButtonAction.ACTION_SHOOTDOWN, 0) > 0.5
     then
        local sprite = scythe_cache:GetSprite()
        --add a delay between swings
        if sprite:IsPlaying("Swing") == false and animTimer <= 0 then
            sprite:Play("Swing", true)
            animTimer = maxAnimTimer
            sfx:Play(SoundEffect.SOUND_SWORD_SPIN)
        end
        --if swing is finished than remove enemy from blacklist
        if sprite:IsFinished("Swing") then
          local enemies = Isaac.GetRoomEntities()

            for _, enemy in ipairs(enemies) do
              if enemy:IsVulnerableEnemy() and enemy:IsActiveEnemy()
              then
                local data = scythe_cache:GetData()
                data.HitBlacklist = data.HitBlacklist or {}
                data.HitBlacklist[GetPtrHash(enemy)] = false
              end
            end
          end
        sprite:Update()
    end
end

scytheMod:AddCallback(ModCallbacks.MC_POST_RENDER, scytheMod.SwingScythe)

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

--starting setup, spawn scythe 
local function onStart(_,bool)
    local player = Isaac.GetPlayer()
    SetBlindfold(player,true,false)
    local effect = Isaac.Spawn(EntityType.ENTITY_EFFECT, SCYTHE_EFFECT_ID, 0, player.Position, Vector.Zero, player):ToEffect()
    effect:FollowParent(player)
    effect:AddEntityFlags(EntityFlag.FLAG_PERSISTENT)
    scythe_cache = effect
end

scytheMod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, onStart)

--handle null capsule hitboxes and weapon rotation
---@param scythe EntityEffect
function scytheMod:ScytheEffectUpdate(scythe)

    scythe_cache = scythe
    local sprite = scythe_cache:GetSprite()
    local player = scythe.Parent:ToPlayer()
    local data = scythe:GetData()
    
    --Rotate the scythe based on player direction
    local headDir = player:GetHeadDirection()
    local rot = (headDir-3) * 90
    sprite.Rotation = rot
    --set offset according to fire direction and mov direction
    local offset = Vector(0,10)
    scythe.DepthOffset = 10
    if(headDir == 1) 
      then
      offset = Vector(0,-20)
      scythe.DepthOffset = -10
      elseif(headDir == 0) 
      then
      offset = Vector(-15,-15)
      scythe.DepthOffset = -10
      elseif(headDir == 2) 
      then
      offset = Vector(15,-15)
      scythe.DepthOffset = -10
    end
        sprite.Offset = offset

    local moveDir = player:GetMovementDirection()
    --SUPPOSED TO BE DYNAMIC ROTATION - UNFINISHED
    --if moveDir ~= -1 then
      --find the minimal angle distance between target rotation and sprite rotation
    -- local rawDiff = math.abs(sprite.Rotation-rot)
    -- local modDiff = math.fmod(rawDiff, 360)
    -- local dist = modDiff
    -- if(modDiff > 180) then
    --   dist = 360 - modDiff
    -- end
    -- local direction = 1
    -- --get sprite direction of rotation angle
    -- if(sprite.Rotation - rot < 0) then
    --   direction = -1
    -- end
    -- if(sprite.Rotation - rot > 0) then
    --   direction = 1
    -- end
    -- local rot = (MovDirection-3) * 90
    -- sprite.Rotation = rot + 70
    -- --apply offset based on movement direction
    -- if(MovDirection == 1 or MovDirection == 2) then
    --   offset = Vector(10,-10)
    -- end
    --     sprite.Offset = offset
    -- --interpolate the rotation of the sprite according to the player movement direction
    -- local diff = 10
    -- --find the minimal angle distance between target rotation and sprite rotation
    -- --rotate the sprite according to the player movement direction
    -- if(direction*dist > 0) then
    --   print("dir*dist>0")
    --     diff = 10
    --     dist = dist - diff
    --     sprite.Rotation = sprite.Rotation + diff
    --     return
    -- end
    -- if(direction*dist < 0) then
    --   print("dir*dist<0")
    --     diff = -10
    --     dist = dist - diff
    --     sprite.Rotation = sprite.Rotation + diff
    --     return
    -- end
  --end
            
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
            local isValidEnemy = enemy:IsVulnerableEnemy() and enemy:IsActiveEnemy()
            if isValidEnemy
            and not data.HitBlacklist[GetPtrHash(enemy)] then
                -- Now hurt it.
                enemy:TakeDamage(player.Damage * DAMAGE_MULTIPLIER, 0, EntityRef(player), 0)
                -- Do some fancy effects, while we're at it.
                enemy:BloodExplode()
                enemy:MakeBloodPoof(enemy.Position, nil, 0.5)
                sfx:Play(SoundEffect.SOUND_DEATH_BURST_LARGE)
            end
            end
            --also damage grid entities
            local room = Game():GetRoom()
            local gridEntity = nil
            if(scythe:CollidesWithGrid()) then
            gridEntity = room:GetGridEntityFromPos(scythe.Position)
            end
            if(gridEntity ~= nil and gridEntity:GetType() == GridEntityType.GRID_POOP) then
              gridEntity:Destroy(true)
            end
        end
    end
end
-- Connect the callback, only for our effect.
scytheMod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, scytheMod.ScytheEffectUpdate, SCYTHE_EFFECT_ID)