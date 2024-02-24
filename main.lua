--register mod and includes of lib and scripts
MolochMod = RegisterMod("MolochMod", 1)
local game = Game()
MolochMod.Game = game
MolochMod.Lib = include("scripts/lib"):Init(MolochMod)
include("scripts/dansemacabre")
include("scripts/statsscale")
local lib = MolochMod.Lib

local sfx = SFXManager()
local molochType = Isaac.GetPlayerTypeByName("Moloch", false)

-- Setup some constants.
local SCYTHE_EFFECT_ID = Isaac.GetEntityVariantByName("Scythe Swing")
local SCYTHES_SWING = Isaac.GetSoundIdByName("Scythes Swing")
DAMAGE_MULTIPLIER = 2.5
local scytheOffset = Vector(-5, 0)
local maxSwingTimer = 0.4
local swingTimer = 0
local appearTimer = 0
local keepInvisible = false
local actionQueue = {}

--null costumes
local headbandCostume = Isaac.GetCostumeIdByPath("gfx/characters/moloch_headband.anm2") -- Exact path, with the "resources" folder as the root
local tatooCostume = Isaac.GetCostumeIdByPath("gfx/characters/moloch_tatoo.anm2")       -- Exact path, with the "resources" folder as the root

--starting setup, spawn scythe
function MolochMod:SpawnScytheApplyCostumes(player)
  if player:GetPlayerType() ~= molochType then
    return -- End the function early. The below code doesn't run, as long as the player isn't Moloch.
  end
  player:AddNullCostume(tatooCostume)
  player:AddNullCostume(headbandCostume)
  local effect = Isaac.Spawn(EntityType.ENTITY_EFFECT, SCYTHE_EFFECT_ID, 0, player.Position, Vector(0, 0), player)
      :ToEffect()
  effect:FollowParent(player)
  effect:AddEntityFlags(EntityFlag.FLAG_PERSISTENT)

  -- local scythes = Isaac.CreateWeapon(WeaponType.WEAPON_SPIRIT_SWORD, player)
  -- player:SetWeapon(scythes,1)
  -- local weapon = Isaac.GetPlayer():GetWeapon(1)
  MolochMod:InitializePlayerData(player, effect)
  keepInvisible = false
  --MolochMod:HideScythe(effect, false)
end

MolochMod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, MolochMod.SpawnScytheApplyCostumes)

function MolochMod:InitializePlayerData(player, scythe)
  local playerData = player:GetData()
  playerData.molochScythesState = 1
  playerData.molochScythesLastCardinalDirection = Direction.DOWN
  playerData.scytheCache = scythe
  playerData.knockedBack = false
  playerData.playerHurt = false
end

function MolochMod:UpdateCostumes(collectibleType, _, _, _, _, player)

end

MolochMod:AddCallback(ModCallbacks.MC_POST_ADD_COLLECTIBLE, MolochMod.UpdateCostumes)

function MolochMod:GetScythes(player)
  local playerData = player:GetData()
  if playerData.scytheCache ~= nil then
    return playerData.scytheCache
  end
end

function MolochMod:SetSwingTimer(newMax)
  maxSwingTimer = newMax
end

function MolochMod:SetAppearTimer(appear)
  appearTimer = appear
end

function MolochMod:HideScythe(isVisible)
  local player = Isaac.GetPlayer()
  if player:GetPlayerType() ~= molochType then
    return -- End the function early. The below code doesn't run, as long as the player isn't Moloch.
  end
  local playerData = player:GetData()
  local effect = playerData.scytheCache
  if (isVisible) then
    playerData.molochScythesState = 1
  else
    playerData.molochScythesState = 0
  end

  effect.Visible = isVisible
end

function MolochMod:ScythesAppearAfterNewLevel()
  MolochMod:HideScythe(false)
  appearTimer = 0.01
end

MolochMod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, MolochMod.ScythesAppearAfterNewLevel)

function MolochMod:OnPlayerDeath(player)
  if (player:ToPlayer()) then
    MolochMod:HideScythe(false)
    keepInvisible = true
  end
end

MolochMod:AddCallback(ModCallbacks.MC_POST_ENTITY_KILL, MolochMod.OnPlayerDeath)

function MolochMod:EvaluateHideTimers()
  local player = Isaac.GetPlayer()
  if player:GetPlayerType() ~= molochType then
    return -- End the function early. The below code doesn't run, as long as the player isn't Moloch.
  end
  local playerData = player:GetData()
  local effect = playerData.scytheCache
  if (appearTimer > 0) then appearTimer = appearTimer - 1 / 60 end
  if (appearTimer <= 0 and effect.Visible == false and keepInvisible == false) then
    MolochMod:HideScythe(true)
  end
end

MolochMod:AddCallback(ModCallbacks.MC_POST_UPDATE, MolochMod.EvaluateHideTimers)

--hides scythes whenever a player jumps or teleports
function MolochMod:CheckForPlayerHidingScythes(player)
  local sprite = player:GetSprite()
  if sprite:GetAnimation() == "TeleportDown" or
      sprite:GetAnimation() == "TeleportUp" or
      sprite:GetAnimation() == "TeleportLeft" or
      sprite:GetAnimation() == "TeleportRight" or
      sprite:GetAnimation() == "Jump" or
      sprite:GetAnimation() == "Trapdoor" or
      sprite:GetAnimation() == "Pickup" or
      sprite:GetAnimation() == "LiftItem" or
      sprite:GetAnimation() == "PickupWalkDown" or
      sprite:GetAnimation() == "PickupWalkUp" or
      sprite:GetAnimation() == "PickupWalkLeft" or
      sprite:GetAnimation() == "PickupWalkRight"
  then
    MolochMod:HideScythe(false)
    appearTimer = sprite:GetCurrentAnimationData():GetLength() / 60 - 0.2
  end
end

MolochMod:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, MolochMod.CheckForPlayerHidingScythes)

function MolochMod:ApplyScythePositioning(sprite, scythes, player)
  --Rotate the scythe based on player movement direction
  --local moveDir = player:GetMovementDirection()
  local headDir = player:GetHeadDirection()
  local rot = 0
  --set offset according to fire direction and mov direction
  local offset = Vector(0, 0)
  local depth = 1
  local lerpSpeed = 0.3
  local playerData = player:GetData()
  playerData.molochScythesLastCardinalDirection = Direction.DOWN
  if (headDir == 1)
  then
    rot = 180
    offset = Vector(0, -15)
    depth = -10
    playerData.molochScythesLastCardinalDirection = Direction.UP
  elseif (headDir == 0)
  then
    rot = 90
    offset = Vector(-10, -15)
    depth = -10
    playerData.molochScythesLastCardinalDirection = Direction.LEFT
  elseif (headDir == 2)
  then
    rot = -90
    offset = Vector(10, -15)
    depth = -10
    playerData.molochScythesLastCardinalDirection = Direction.RIGHT
  end
  --handling switching direction on attack
  local aimDir = player:GetAimDirection()
  if (aimDir:Length() ~= 0) then
    if (aimDir == 1)
    then
      rot = 180
    elseif (aimDir == 0)
    then
      rot = 90
    elseif (aimDir == 2)
    then
      rot = -90
    end
  end

  sprite.Rotation = sprite.Rotation % 360
  if math.abs((sprite.Rotation - 360) - rot) < math.abs(sprite.Rotation - rot) then
    sprite.Rotation = sprite.Rotation - 360
  elseif math.abs((sprite.Rotation + 360) - rot) < math.abs(sprite.Rotation - rot) then
    sprite.Rotation = sprite.Rotation + 360
  end
  if (playerData.molochScythesState == 1) then
    MolochMod:QuadraticInterpDirections(sprite, scythes, rot, offset, depth, lerpSpeed)
  elseif (playerData.molochScythesState == 2) then
    sprite.Rotation = rot
    sprite.Offset = offset
    scythes.DepthOffset = depth
  end
end

function MolochMod:QuadraticInterpDirections(sprite, scythes, rot, offset, depth, lerpSpeed)
  sprite.Rotation = lib.QuadraticInterp(sprite.Rotation, rot, lerpSpeed)
  sprite.Offset = lib.QuadraticInterp(sprite.Offset, offset, lerpSpeed)
  scythes.DepthOffset = lib.QuadraticInterp(scythes.DepthOffset, depth, lerpSpeed)
end

--handling swinging the scythe
function MolochMod:SwingScythe()
  local player = Isaac.GetPlayer()
  if player:GetPlayerType() ~= molochType or game:IsPauseMenuOpen() then
    return -- End the function early. The below code doesn't run, as long as the player isn't Moloch.
  end
  local playerData = player:GetData()
  local sprite = playerData.scytheCache:GetSprite()
  swingTimer = swingTimer - 1 / 60
  if player:GetDamageCooldown() > 0 then
    playerData.playerHurt = true
  else
    playerData.playerHurt = false
  end
  if sprite:IsPlaying("Swing") == false and swingTimer <= 0 and player:GetDamageCooldown() <= 0
      and not playerData.playerHurt and playerData.scytheCache.Visible == true then
    MolochMod:ApplyScythePositioning(sprite, playerData.scytheCache, player)
  end
  --fix swinging when hurt
  if Input.IsActionTriggered(ButtonAction.ACTION_SHOOTLEFT, player.ControllerIndex) == true or
      Input.IsActionTriggered(ButtonAction.ACTION_SHOOTRIGHT, player.ControllerIndex) == true or
      Input.IsActionTriggered(ButtonAction.ACTION_SHOOTUP, player.ControllerIndex) == true or
      Input.IsActionTriggered(ButtonAction.ACTION_SHOOTDOWN, player.ControllerIndex) == true
  then
    --add a delay between swings
    if sprite:IsPlaying("Swing") == false and swingTimer <= 0 and player:HasInvincibility() == false
        and not playerData.playerHurt and playerData.scytheCache.Visible == true then
      if (player:GetHeadDirection() ~= -1) then
        player:GetData().molochScythesState = 2
        MolochMod:ApplyScythePositioning(sprite, playerData.scytheCache, player)
      end
      sprite.PlaybackSpeed = 1
      sprite:Play("Swing", true)
      swingTimer = maxSwingTimer
      sfx:Play(SCYTHES_SWING, 0.7)
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
  local player = Isaac.GetPlayer()
  if player:GetPlayerType() ~= molochType then
    return -- End the function early. The below code doesn't run, as long as the player isn't Moloch.
  end
  local isValidEnemy = (enemy:IsVulnerableEnemy() and enemy:IsActiveEnemy()) or enemy:IsBoss()
  if isValidEnemy and damageFlags == damageFlags & DamageFlag.DAMAGE_NOKILL then
    local knockbackDir = player.Position - enemy.Position
    local playerData = player:GetData()
    if (playerData.knockedBack == false) then
      --print("Knockback player")
      player:AddVelocity(knockbackDir:Resized(1.5))
      playerData.knockedBack = true
    end
  end
end

MolochMod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, MolochMod.AfterHitOnEnemy)

function MolochMod:ResetScythesAnimation()
  local player = Isaac.GetPlayer()
  if player:GetPlayerType() ~= molochType then
    return -- End the function early. The below code doesn't run, as long as the player isn't Moloch.
  end
  local playerData = player:GetData()
  local scythes = playerData.scytheCache
  local sprite = scythes:GetSprite()
  sprite:Play("Idle", true)
end

MolochMod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, MolochMod.ResetScythesAnimation)

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
  if sprite:IsPlaying("Swing") == false then
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
    return returnVal
  end
end

MolochMod:AddCallback(ModCallbacks.MC_INPUT_ACTION, MolochMod.ForceScytheHeadDirection, InputHook.IS_ACTION_PRESSED)
MolochMod:AddCallback(ModCallbacks.MC_INPUT_ACTION, MolochMod.ForceScytheHeadDirection, InputHook.GET_ACTION_VALUE)

--make the scythes get pickups
local ScythePickupCollisionBlacklist = {
  [PickupVariant.PICKUP_COLLECTIBLE] = true,
  [PickupVariant.PICKUP_SHOPITEM] = true,
  [PickupVariant.PICKUP_TROPHY] = true,
  [PickupVariant.PICKUP_BIGCHEST] = true,
  [PickupVariant.PICKUP_MEGACHEST] = true,
  [PickupVariant.PICKUP_BED] = true,
  [PickupVariant.PICKUP_THROWABLEBOMB] = true,
}
local function ScythePickupPush(player, pickup)
  if pickup:GetSprite():GetAnimation() ~= "Collect" then
    pickup.Velocity = (pickup.Position - player.Position):Resized(5)
  end
end

local function ScythesPickupSetHidden(pickup, hidden)
  if pickup.Variant == PickupVariant.PICKUP_TRINKET then
    pickup.Visible = not hidden
  else
    pickup:GetSprite().Color = hidden and lib.InvisibleColor or lib.NullColor
  end
end

function MolochMod:ScythesPickupCollision(player, entity)
  local pickup = entity:ToPickup()
  if not player or player.EntityCollisionClass == EntityCollisionClass.ENTCOLL_NONE
      or player.EntityCollisionClass == EntityCollisionClass.ENTCOLL_PLAYERONLY
      or not pickup or ScythePickupCollisionBlacklist[pickup.Variant] or pickup.Price ~= 0
  then
    return
  end
  if (lib.IsVanillaChest(pickup) or lib.IsUnlockableChest(pickup)) and pickup.SubType == ChestSubType.CHEST_OPENED then
    ScythePickupPush(player, pickup)
    return
  end
  local isUnpickableRedHeart = not player:CanPickRedHearts() and pickup.Variant == PickupVariant.PICKUP_HEART and
      pickup.SubType < 3
  local isUnpickableBattery = pickup.Variant == PickupVariant.PICKUP_LIL_BATTERY and
      not player:NeedsCharge(ActiveSlot.SLOT_PRIMARY)
  if isUnpickableRedHeart or isUnpickableBattery then
    ScythePickupPush(player, pickup)
  elseif lib.IsUnlockableChest(pickup) and player:GetNumKeys() > 0 and pickup.SubType ~= ChestSubType.CHEST_OPENED then
    player:AddKeys(-1)
    pickup:TryOpenChest(player)
  elseif lib.IsUnlockableChest(pickup) and player:GetNumKeys() == 0 then
    ScythePickupPush(player, pickup)
  elseif lib.IsVanillaChest(pickup) then
    pickup:TryOpenChest(player)
  elseif entity.Type == EntityType.ENTITY_PICKUP and entity.Variant == PickupVariant.PICKUP_BOMBCHEST then
    ScythePickupPush(player, pickup)
  else
    pickup:GetData().pickupActualPos = pickup.Position
    pickup:GetData().pickupCountDown = 2
    pickup:GetData().pickupPlayer = player
    pickup.Position = player.Position
    ScythesPickupSetHidden(pickup, true)
  end
end

function MolochMod:ScythePickup(pickup)
  local data = pickup:GetData()

  if (data.pickupCooldown or 0) > 0 then
    data.pickupCooldown = data.pickupCooldown - 1
  end

  if data.pickupActualPos and (data.pickupCountDown or 0) > 0 then
    data.pickupCountDown = data.pickupCountDown - 1
    if data.pickupFixedPos then
      data.pickupFixedPos = data.pickupActualPos
    end
    if data.pickupCountDown <= 0 then
      local pos = data.pickupActualPos
      pickup.Position = pos
      pickup.TargetPosition = pos
      pickup:GetData().Position = pos

      ScythesPickupSetHidden(pickup, false)

      ScythePickupPush(data.pickupPlayer or Isaac.GetPlayer(0), pickup)

      data.pickupActualPos = nil
      data.pickupCountDown = nil
    else
      ScythesPickupSetHidden(pickup, true)
    end
  end
end

MolochMod:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, MolochMod.ScythePickup)

function MolochMod:ScythePickupRender(pickup)
  local data = pickup:GetData()

  if data.samaelPickupActualPos and (data.samaelPickupCountDown or 0) > 0 then
    ScythesPickupSetHidden(pickup, false)
    pickup:GetSprite():Render(Isaac.WorldToScreen(data.samaelPickupActualPos), lib.ZeroVector, lib.ZeroVector)
    ScythesPickupSetHidden(pickup, true)
  end
end

MolochMod:AddCallback(ModCallbacks.MC_POST_PICKUP_RENDER, MolochMod.ScythePickupRender)

ScythePickups = {}

MolochMod:AddCallback(ModCallbacks.MC_POST_UPDATE, function()
  local toRemove = {}
  for hash, tab in pairs(ScythePickups) do
    tab.Countdown = tab.Countdown - 1
    if tab.Countdown <= 0 then
      table.insert(toRemove, hash)
    end
  end
  for _, hash in pairs(toRemove) do
    ScythePickups[hash] = nil
  end
end)

function MolochMod:ScythePickupInit(pickup)
  if pickup.Type == EntityType.ENTITY_EFFECT and pickup.Variant == 1748 then return end

  if ScythePickups[GetPtrHash(pickup)] then
    -- Likely morphed pickup.
    local pos = ScythePickups[GetPtrHash(pickup)].PickupPos
    pickup.Position = pos
    pickup.TargetPosition = pos
    lib.ScheduleForUpdate(function()
      pickup.Position = pos
      pickup.TargetPosition = pos
    end)
    return
  end

  if pickup.SpawnerType == EntityType.ENTITY_PICKUP and pickup.SpawnerEntity and pickup.SpawnerEntity:GetData().samaelPickupActualPos then
    pickup.Position = pickup.SpawnerEntity:GetData().samaelPickupActualPos
    return
  end

  local foundPickupPos
  local foundPickupDist

  for _, tab in pairs(ScythePickups) do
    local dist = pickup.Position:Distance(tab.PlayerPos)
    if (not foundPickupDist or dist < foundPickupDist) and dist <= 5 then
      foundPickupPos = tab.PickupPos
      foundPickupDist = dist
    end
  end

  if foundPickupPos then
    pickup.Position = foundPickupPos
  end
end

MolochMod:AddCallback(ModCallbacks.MC_POST_PICKUP_INIT, MolochMod.ScythePickupInit)

--handle null capsule hitboxes and weapon rotation
---@param scythe EntityEffect
function MolochMod:ScytheEffectUpdate(scythe)
  local player = Isaac.GetPlayer()
  local playerData = player:GetData()
  local scytheCache = playerData.scytheCache
  local sprite = scytheCache:GetSprite()
  local data = scytheCache:GetData()
  if player:GetPlayerType() ~= molochType or scytheCache.Visible == false then
    return -- End the function early. The below code doesn't run, as long as the player isn't Moloch.
  end

  data.HitBlacklist = data.HitBlacklist or {}

  if sprite:IsFinished("Swing") then
    --remove knockedBack and capsule from playerData
    playerData.knockedBack = false
    playerData.capsule = nil
    sprite:Play("Idle", true)
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
    playerData.molochScythesState = 1
  end

  for i = 1, 2 do
    -- Get the "null capsule", which is the hitbox defined by the null layer in the anm2.
    local capsule = scythe:GetNullCapsule("Hit" .. i)
    playerData.capsule = capsule
    if (sprite:IsPlaying("Swing")) then
      -- Search for all entities within the capsule.
      for _, entity in ipairs(Isaac.FindInCapsule(capsule, EntityPartition.ALL)) do
        -- Make sure its a valid entity
        local isValidEnemy = entity:IsVulnerableEnemy() and entity:IsActiveEnemy()
        local isFireplace = (entity:GetType() == EntityType.ENTITY_FIREPLACE)
        local isEntityPoop = (entity:GetType() == EntityType.ENTITY_POOP)
        local isPickup = (entity:GetType() == EntityType.ENTITY_PICKUP)
        local isBomb = (entity:GetType() == EntityType.ENTITY_BOMB)
        local isMovableTNT = (entity:GetType() == EntityType.ENTITY_MOVABLE_TNT)
        if (isValidEnemy or isFireplace or isEntityPoop or isPickup or isBomb or isMovableTNT)
            and not data.HitBlacklist[GetPtrHash(entity)] then
          if (isFireplace or isEntityPoop or isMovableTNT) then
            entity:TakeDamage((player.Damage + 10) * DAMAGE_MULTIPLIER, 0, EntityRef(player), 0)
          elseif isPickup then
            --affect pickups with the capsule
            MolochMod:ScythesPickupCollision(player, entity)
          elseif isBomb then
            --hitting bombs with the scythes knocks them back
            local bomb = entity:ToBomb()
            if (bomb == nil) then return end
            if bomb.Variant ~= BombVariant.BOMB_ROCKET and bomb.Variant ~= BombVariant.BOMB_ROCKET_GIGA
            then
              bomb.Velocity = bomb.Position:__sub(player.Position):Resized(10)
              sfx:Play(SoundEffect.SOUND_SCAMPER, 0.78, 0, false, 0.8)
            end
          elseif isValidEnemy then
            entity:TakeDamage(player.Damage * DAMAGE_MULTIPLIER, 0, EntityRef(player), 0)
            data.HitBlacklist[GetPtrHash(entity)] = true
          end
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
