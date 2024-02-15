--register mod and includes of lib and scripts
MolochMod = RegisterMod("MolochMod", 1)
local game = Game()
MolochMod.Game = game
MolochMod.Lib = include("scripts/lib"):Init(MolochMod)
local lib = MolochMod.Lib

local sfx = SFXManager()
local molochType = Isaac.GetPlayerTypeByName("Moloch", false)

-- Setup some constants.
local SCYTHE_EFFECT_ID = Isaac.GetEntityVariantByName("Scythe Swing")
DAMAGE_MULTIPLIER = 2.5
local scytheOffset = Vector(-5,0)
local maxSwingTimer = 0.4
local swingTimer = 0
local actionQueue = {}

--null costumes
local headbandCostume = Isaac.GetCostumeIdByPath("gfx/characters/moloch_headband.anm2") -- Exact path, with the "resources" folder as the root
local tatooCostume = Isaac.GetCostumeIdByPath("gfx/characters/moloch_tatoo.anm2") -- Exact path, with the "resources" folder as the root

--starting setup, spawn scythe 
function MolochMod:SpawnScytheApplyCostumes(player)
  if player:GetPlayerType() ~= molochType then
    return -- End the function early. The below code doesn't run, as long as the player isn't Moloch.
end
player:AddNullCostume(tatooCostume)
player:AddNullCostume(headbandCostume)
  local effect = Isaac.Spawn(EntityType.ENTITY_EFFECT, SCYTHE_EFFECT_ID, 0, player.Position, Vector(0,0), player):ToEffect()
  effect:FollowParent(player)
  effect:AddEntityFlags(EntityFlag.FLAG_PERSISTENT)
  
  -- local scythes = Isaac.CreateWeapon(WeaponType.WEAPON_SPIRIT_SWORD, player)
  -- player:SetWeapon(scythes,1)
  -- local weapon = Isaac.GetPlayer():GetWeapon(1)
  MolochMod:InitializePlayerData(player, effect)
end

MolochMod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, MolochMod.SpawnScytheApplyCostumes)

function MolochMod:InitializePlayerData(player, scythe)
  local playerData = player:GetData()
  playerData.molochScythesState = 0
  playerData.molochScythesLastCardinalDirection = Direction.DOWN
  playerData.scytheCache = scythe
end

function MolochMod:ApplyScythePositioning(sprite, scythe, player)
 --Rotate the scythe based on player direction
 local headDir = player:GetHeadDirection()
 local rot = (headDir-3) * 90
 sprite.Rotation = rot
 --set offset according to fire direction and mov direction
local offset = Vector(0,0)
scythe.DepthOffset = 10
local playerData = player:GetData()
playerData.molochScythesLastCardinalDirection = Direction.DOWN
if(headDir == 1) 
 then
 offset = Vector(0,-15)
 scythe.DepthOffset = -10
 playerData.molochScythesLastCardinalDirection = Direction.UP
 elseif(headDir == 0) 
 then
 offset = Vector(-10,-15)
 scythe.DepthOffset = -10
 playerData.molochScythesLastCardinalDirection = Direction.LEFT
 elseif(headDir == 2) 
 then
 offset = Vector(10,-15)
 scythe.DepthOffset = -10
 playerData.molochScythesLastCardinalDirection = Direction.RIGHT
end
   sprite.Offset = offset

local moveDir = player:GetMovementDirection()
end

--handling swinging the scythe
function MolochMod:SwingScythe()
  local player = Isaac.GetPlayer()
  if player:GetPlayerType() ~= molochType then
    return -- End the function early. The below code doesn't run, as long as the player isn't Moloch.
end
    swingTimer = swingTimer - 1/60
    if  Input.IsActionTriggered(ButtonAction.ACTION_SHOOTLEFT, player.ControllerIndex) == true or
        Input.IsActionTriggered(ButtonAction.ACTION_SHOOTRIGHT, player.ControllerIndex) == true or
        Input.IsActionTriggered(ButtonAction.ACTION_SHOOTUP, player.ControllerIndex) == true or
        Input.IsActionTriggered(ButtonAction.ACTION_SHOOTDOWN, player.ControllerIndex) == true
     then
        local playerData = player:GetData()
        local sprite = playerData.scytheCache:GetSprite()
        --add a delay between swings
        if sprite:IsPlaying("Swing") == false and swingTimer <= 0 then
          if(player:GetHeadDirection() ~= -1 ) then
            player:GetData().molochScythesState = 2
            MolochMod:ApplyScythePositioning(sprite, playerData.scytheCache, player)
          end
            sprite.PlaybackSpeed = 0.7
            sprite:Play("Swing", true)
            swingTimer = maxSwingTimer
            sfx:Play(SoundEffect.SOUND_SWORD_SPIN)
        end
        sprite:Update()
      end
end

MolochMod:AddCallback(ModCallbacks.MC_POST_RENDER, MolochMod.SwingScythe)

function MolochMod:AffectPickups(pickup)
  --print(pickup)
end

MolochMod:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, MolochMod.AffectPickups)

--knockback after a hit on enemy that doesnt kill it
function MolochMod:AfterHitOnEnemy(enemy, amount, damageFlags, src, countdown)
  local isValidEnemy = (enemy:IsVulnerableEnemy() and enemy:IsActiveEnemy()) or enemy:IsBoss()
if isValidEnemy and damageFlags == damageFlags & DamageFlag.DAMAGE_NOKILL then
  local player = Isaac.GetPlayer()
  local knockbackDir = player.Position - enemy.Position
  player:AddKnockback(EntityRef(player), knockbackDir:Resized(3),4,false)
end
end

MolochMod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG,MolochMod.AfterHitOnEnemy)

  local InputDirections = {}
InputDirections[ButtonAction.ACTION_SHOOTLEFT] = Direction.LEFT
InputDirections[ButtonAction.ACTION_SHOOTUP] = Direction.UP
InputDirections[ButtonAction.ACTION_SHOOTRIGHT] = Direction.RIGHT
InputDirections[ButtonAction.ACTION_SHOOTDOWN] = Direction.DOWN

--force the player to look in the direction of swing
function MolochMod:ForceScytheHeadDirection(player, inputHook, buttonAction)
  local player = Isaac.GetPlayer()
  if player:GetPlayerType() ~= molochType then
    return -- End the function early. The below code doesn't run, as long as the player isn't Moloch.
  end
	if not InputDirections[buttonAction] or not player or not player:ToPlayer() then return end
	player = player:ToPlayer()
	local data = player:GetData()

	local currentValue = Input.GetActionValue(buttonAction, player.ControllerIndex)
	local sprite = data.scytheCache:GetSprite()
  if sprite:IsFinished("Swing") then
    return
  end
	if (data.molochScythesState == 1 or data.molochScythesState == 2) and currentValue <= 0.1 then
		local returnVal
		
		if InputDirections[buttonAction] == data.molochScythesLastCardinalDirection then
			returnVal = 0.01
		else
			returnVal = 0.0
		end
		
		if inputHook == InputHook.IS_ACTION_PRESSED then
			return returnVal > 0
		end
    --print(returnVal)
		return returnVal
	end
end
MolochMod:AddCallback(ModCallbacks.MC_INPUT_ACTION, MolochMod.ForceScytheHeadDirection, InputHook.IS_ACTION_PRESSED)
MolochMod:AddCallback(ModCallbacks.MC_INPUT_ACTION, MolochMod.ForceScytheHeadDirection, InputHook.GET_ACTION_VALUE)

--handle null capsule hitboxes and weapon rotation
---@param scythe EntityEffect
function MolochMod:ScytheEffectUpdate(scythe)

  local player = Isaac.GetPlayer()
  local playerData = player:GetData()
  local scytheCache = playerData.scytheCache
  local sprite = scytheCache:GetSprite()
  local data = scytheCache:GetData()
  if sprite:IsPlaying("Swing") == false and swingTimer <= 0 then
    MolochMod:ApplyScythePositioning(sprite, playerData.scytheCache, player)
  end

  if player:GetPlayerType() ~= molochType then
    return -- End the function early. The below code doesn't run, as long as the player isn't Moloch.
end
  
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
--if swing is finished than remove enemy from blacklist
if sprite:IsFinished("Swing") then
  local entities = Isaac.GetRoomEntities()
  for _, entity in ipairs(entities) do
    local isValidEnemy = entity:IsVulnerableEnemy() and entity:IsActiveEnemy()
    local isFireplace = (entity:GetType() == EntityType.ENTITY_FIREPLACE)
    local isEntityPoop = (entity:GetType() == EntityType.ENTITY_POOP)
    if isValidEnemy or isFireplace or isEntityPoop
    then
      local data = playerData.scytheCache:GetData()
      data.HitBlacklist = data.HitBlacklist or {}
      data.HitBlacklist[GetPtrHash(entity)] = false
    end
  end
end
  
for i = 1, 2 do
    -- Get the "null capsule", which is the hitbox defined by the null layer in the anm2.
    local capsule = scythe:GetNullCapsule("Hit" .. i)
    if(sprite:IsPlaying("Swing")) then
        -- Search for all enemies within the capsule.
    for _, entity in ipairs(Isaac.FindInCapsule(capsule, EntityPartition.ENEMY)) do
        -- Make sure it can be hurt.
        local isValidEnemy = entity:IsVulnerableEnemy() and entity:IsActiveEnemy()
        local isFireplace = (entity:GetType() == EntityType.ENTITY_FIREPLACE)
        local isEntityPoop = (entity:GetType() == EntityType.ENTITY_POOP)
        if (isValidEnemy or isFireplace or isEntityPoop)
        and not data.HitBlacklist[GetPtrHash(entity)] then
            -- Now hurt it.
            if(isFireplace or isEntityPoop) then
              entity:TakeDamage((player.Damage + 10) * DAMAGE_MULTIPLIER, 0, EntityRef(player), 0)
            else
              entity:TakeDamage(player.Damage * DAMAGE_MULTIPLIER, 0, EntityRef(player), 0)
            end
            
            data.HitBlacklist[GetPtrHash(entity)] = true
            if isValidEnemy then
              -- Do some fancy effects, while we're at it.
              sfx:Play(SoundEffect.SOUND_DEATH_BURST_LARGE)
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
end
-- Connect the callback, only for our effect.
MolochMod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, MolochMod.ScytheEffectUpdate, SCYTHE_EFFECT_ID)
