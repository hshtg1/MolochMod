--register mod and includes of lib and scripts
MolochMod = RegisterMod("Moloch Mod", 1)
local game = Game()
MolochMod.Game = game
MolochMod.Lib = include("scripts/lib"):Init(MolochMod)
include("scripts/dansemacabre")
include("scripts/statsscale")
require("scripts/chargeatk")
local json = require("json")
local lib = MolochMod.Lib

local sfx = SFXManager()
local molochType = Isaac.GetPlayerTypeByName("Moloch", false)
--persistentData
MolochMod.PERSISTENT_DATA = MolochMod.PERSISTENT_DATA or {}

-- Setup some constants.
local SCYTHE_EFFECT_ID = Isaac.GetEntityVariantByName("Scythe Swing")
local SCYTHES_SWING = Isaac.GetSoundIdByName("Scythes Swing")
DAMAGE_MULTIPLIER = 2.5
local scytheOffset = Vector(-5, 0)
local maxSwingTimer = 0.5
local swingTimer = 0
local appearTimer = 0
local keepInvisible = false

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
  --initialize persistent data
  if MolochMod:HasData() then
    MolochMod.PERSISTENT_DATA = json.decode(MolochMod:LoadData())
  end
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

function MolochMod:HideScythe(isVisible, keep)
  local keep = keep or false
  keepInvisible = keep
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
  appearTimer = 1
end

MolochMod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, MolochMod.ScythesAppearAfterNewLevel)

function MolochMod:OnPlayerDeath(player)
  if (player:ToPlayer()) then
    MolochMod:HideScythe(false)
    keepInvisible = true
  end
end

MolochMod:AddCallback(ModCallbacks.MC_POST_ENTITY_KILL, MolochMod.OnPlayerDeath)

local delayTime = 0

function MolochMod:EvaluateHideTimers()
  local player = Isaac.GetPlayer()
  if player:GetPlayerType() ~= molochType then
    return -- End the function early. The below code doesn't run, as long as the player isn't Moloch.
  end
  local playerData = player:GetData()
  local effect = playerData.scytheCache
  if (appearTimer > 0) then appearTimer = appearTimer - 1 end
  if (appearTimer <= 0 and effect.Visible == false and keepInvisible == false) then
    MolochMod:HideScythe(true)
  end
  delayTime = delayTime - 1
end

MolochMod:AddCallback(ModCallbacks.MC_POST_UPDATE, MolochMod.EvaluateHideTimers)

--hides scythes whenever a player jumps or teleports
function MolochMod:CheckForPlayerHidingScythes(player)
  local sprite = player:GetSprite()
  local anim = sprite:GetAnimation()
  if anim == "TeleportDown" or
      anim == "TeleportUp" or
      anim == "TeleportLeft" or
      anim == "TeleportRight" or
      anim == "Jump" or
      anim == "Trapdoor" or
      anim == "Pickup" or
      anim == "LiftItem" or
      anim == "PickupWalkDown" or
      anim == "PickupWalkUp" or
      anim == "PickupWalkLeft" or
      anim == "PickupWalkRight" or
      anim == "UseItem" or
      anim == "Sad" or
      anim == "Happy"
  then
    MolochMod:HideScythe(false)
    appearTimer = sprite:GetCurrentAnimationData():GetLength() - 0.2
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
  if player:HasCollectible(CollectibleType.COLLECTIBLE_PONY) or player:HasCollectible(CollectibleType.COLLECTIBLE_WHITE_PONY) then
    depth = -5
  end
  if (headDir == 1)
  then
    rot = 180
    offset = Vector(0, -15)
    depth = -5
    playerData.molochScythesLastCardinalDirection = Direction.UP
  elseif (headDir == 0)
  then
    rot = 90
    offset = Vector(-10, -15)
    depth = -5
    playerData.molochScythesLastCardinalDirection = Direction.LEFT
  elseif (headDir == 2)
  then
    rot = -90
    offset = Vector(10, -15)
    depth = -5
    playerData.molochScythesLastCardinalDirection = Direction.RIGHT
  end
  if playerData.playerHurt then
    sprite.Rotation = rot
    sprite.Offset = offset
    scythes.DepthOffset = depth
    return
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
  if player.CanFly then
    offset = offset + Vector(0, -5)
  end

  sprite.Rotation = sprite.Rotation % 360
  if math.abs((sprite.Rotation - 360) - rot) < math.abs(sprite.Rotation - rot) then
    sprite.Rotation = sprite.Rotation - 360
  elseif math.abs((sprite.Rotation + 360) - rot) < math.abs(sprite.Rotation - rot) then
    sprite.Rotation = sprite.Rotation + 360
  end
  if playerData.molochScythesState == 1 or playerData.molochScythesState == 3 then
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

local CHARGE_WHEEL_GFX = "gfx/ui/meleeLib_chargewheel.anm2"
local CHARGE_METER_ANIMATIONS = {
  NONE = "",
  CHARGING = "Charging",
  START_CHARGED = "StartCharged",
  CHARGED = "Charged",
  DISAPPEAR = "Disappear"
}

function MolochMod:NewChargeBarSprite()
  local sprite = Sprite()
  sprite:Load(CHARGE_WHEEL_GFX, true)
  return sprite
end

function MolochMod:GetAnimationLengthTo(sprite, num)
  num = num or 4
  if (num > 4) then return end
  local animData = sprite:GetAllAnimationData()
  local totalLen = 0
  for i = 1, num do
    totalLen = totalLen + animData[i]:GetLength()
  end
  return totalLen
end

local holdTimer = 0
local CHARGE_METER_RENDER_OFFSET = Vector(40, -50)
local pressedLastFrame
local chargeWheel = MolochMod:NewChargeBarSprite()
local maxCharge = MolochMod:GetAnimationLengthTo(chargeWheel, 2)
local chargeSpeed = 10
local threshold = 30
local frameCount = 0

--handling swinging the scythe
function MolochMod:SwingScythe()
  local player = Isaac.GetPlayer()
  if player:GetPlayerType() ~= molochType or game:IsPauseMenuOpen() then
    return -- End the function early. The below code doesn't run, as long as the player isn't Moloch.
  end
  local playerData = player:GetData()
  local sprite = playerData.scytheCache:GetSprite()
  swingTimer = swingTimer - 1 / 60
  if player:GetDamageCooldown() > 85 then
    playerData.playerHurt = true
    return
  else
    playerData.playerHurt = false
  end
  if sprite:IsPlaying("Swing") == false and swingTimer <= 0
      and playerData.scytheCache.Visible == true then
    MolochMod:ApplyScythePositioning(sprite, playerData.scytheCache, player)
  end
  --make sure the charging animation doesnt play over and over
  local pressedThisFrame = Input.IsActionPressed(ButtonAction.ACTION_SHOOTLEFT, player.ControllerIndex) or
      Input.IsActionPressed(ButtonAction.ACTION_SHOOTRIGHT, player.ControllerIndex) or
      Input.IsActionPressed(ButtonAction.ACTION_SHOOTUP, player.ControllerIndex) or
      Input.IsActionPressed(ButtonAction.ACTION_SHOOTDOWN, player.ControllerIndex)
  if pressedThisFrame
  then
    playerData.lastAimDirection = player:GetShootingInput()
    if (maxCharge + threshold > holdTimer) then
      local chargeIncrement = chargeSpeed /
          player.MaxFireDelay -- higher number for chargeSpeed means faster charge
      holdTimer = holdTimer + chargeIncrement
    end
    --the ranged attack
    if holdTimer > threshold and player:HasInvincibility() == false
        and playerData.scytheCache.Visible == true then
      if sprite:IsPlaying("Charging") == false then
        sprite:Play("Charging", true)
        if playerData.isCharging then
          sprite:SetFrame(8)
        end
        playerData.isCharging = true
        if (player:GetHeadDirection() ~= -1) then
          player:GetData().molochScythesState = 3
          MolochMod:ApplyScythePositioning(sprite, playerData.scytheCache, player)
        end
      end
      --setting accurate charge bar animations
      if holdTimer - threshold >= maxCharge - 2 then
        chargeWheel:Play(CHARGE_METER_ANIMATIONS.CHARGED)
      elseif holdTimer - threshold >= MolochMod:GetAnimationLengthTo(chargeWheel, 1) - 2 and holdTimer - threshold < maxCharge - 2 then
        chargeWheel:Play(CHARGE_METER_ANIMATIONS.START_CHARGED)
      else
        chargeWheel:SetFrame(CHARGE_METER_ANIMATIONS.CHARGING, math.ceil(holdTimer) - threshold)
      end
    elseif holdTimer <= threshold then
      --add a delay between swings
      --the melee attack
      if sprite:IsPlaying("Swing") == false and swingTimer <= 0 and player:HasInvincibility() == false
          and playerData.scytheCache.Visible == true and not pressedLastFrame then
        if (player:GetHeadDirection() ~= -1) then
          player:GetData().molochScythesState = 2
          MolochMod:ApplyScythePositioning(sprite, playerData.scytheCache, player)
        end
        sprite.PlaybackSpeed = 1
        sprite:Play("Swing", true)
        swingTimer = maxSwingTimer
        sfx:Play(SCYTHES_SWING, 1.3)
      end
    end
  end
  if pressedLastFrame and not pressedThisFrame then
    chargeWheel:Play(CHARGE_METER_ANIMATIONS.DISAPPEAR)
    if sprite:IsPlaying("Charging") then
      sprite:SetLastFrame()
    end
    playerData.isCharging = false
    if holdTimer - threshold + 5 >= maxCharge then
      MolochMod:UseHook(player)
    end
    holdTimer = 0
  end
  --render the chargeWheel correctly in big rooms
  chargeWheel:Render(Isaac.WorldToScreen(player.Position + CHARGE_METER_RENDER_OFFSET), Vector(0, 0),
    Vector(0, 0))
  if frameCount % 2 == 0 then
    sprite:Update()
  end
  chargeWheel:Update()
  pressedLastFrame = pressedThisFrame
  frameCount = frameCount + 1
end

MolochMod:AddCallback(ModCallbacks.MC_POST_RENDER, MolochMod.SwingScythe)

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
  sprite:Stop()
end

MolochMod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, MolochMod.ResetScythesAnimation)

local InputDirections = {}
InputDirections[ButtonAction.ACTION_SHOOTLEFT] = Direction.LEFT
InputDirections[ButtonAction.ACTION_SHOOTUP] = Direction.UP
InputDirections[ButtonAction.ACTION_SHOOTRIGHT] = Direction.RIGHT
InputDirections[ButtonAction.ACTION_SHOOTDOWN] = Direction.DOWN

--force the player to look in the direction of swing
function MolochMod:ForceScytheHeadDirection(player, inputHook, buttonAction)
  if not player or not player:ToPlayer() then return end
  player = player:ToPlayer()
  if player:GetPlayerType() ~= molochType or player == nil then
    return -- End the function early. The below code doesn't run, as long as the player isn't Moloch.
  end
  if not InputDirections[buttonAction] or not player or not player:ToPlayer() then return end
  local player = player:ToPlayer()
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
      or (pickup:GetData().pickupCooldown or 0) < 0
  then
    return
  end
  if (lib.IsVanillaChest(pickup) or lib.IsUnlockableChest(pickup)) and pickup.SubType == ChestSubType.CHEST_OPENED then
    ScythePickupPush(player, pickup)
    return
  end
  local isUnpickableRedHeart = not player:CanPickRedHearts() and pickup.Variant == PickupVariant.PICKUP_HEART and
      (pickup.SubType < 3 or pickup.SubType == 5)
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
    local data = pickup:GetData()
    local sprite = pickup:GetSprite()
    sprite:Play("Collect")
    data.pickupCountdown = 2
  end
end

function MolochMod:ScythesPickup(pickup)
  local player = Isaac.GetPlayer()
  local data = pickup:GetData()
  if (data.pickupCooldown or 0) > 0 then
    data.pickupCooldown = data.pickupCooldown - 1
  end
  if (data.pickupCountdown or 0) > 0 then
    data.pickupCountdown = data.pickupCountdown - 1
    if not (lib.IsVanillaChest(pickup) or lib.IsUnlockableChest(pickup)) then
      if data.pickupCountdown <= 0 then
        pickup.Position = player.Position
        ScythesPickupSetHidden(pickup, true)
        data.pickupCooldown = 10
      end
    end
  end
end

MolochMod:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, MolochMod.ScythesPickup)

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
  if sprite:IsFinished("Charging") and not playerData.isCharging then
    sprite:Play("Idle", true)
    playerData.molochScythesState = 1
  end
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
            --affect pickups within the capsule
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

function MolochMod:GetEntitySegments(ent)
  local segments = {}
  local lastParent = ent:GetLastParent()
  local index = 1
  segments[index] = lastParent
  while segments[index].Child ~= nil do
    index = index + 1
    segments[index] = segments[index - 1].Child
  end
  return segments
end

local nilvector = Vector.Zero

function MolochMod:UseHook(player)
  local aim = player:GetData().lastAimDirection
  local hook = Isaac.Spawn(1000, 1962, 50,
    player.Position - player.Velocity,
    aim * 15 * player.ShotSpeed * holdTimer / 100,
    player)
  hook.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NOPITS
  hook.CollisionDamage = 8
  hook:GetSprite().Rotation = hook.Velocity:GetAngleDegrees()
  hook:GetSprite():Play("Idle", true)
  hook.Parent = player
  hook.SpawnerEntity = player
  hook.DepthOffset = 10
  hook:GetData().LaunchVel = hook.Velocity
  hook:GetData().HasHitGrid = false
  hook:Update()
end

function MolochMod:UpdateRope(e)
  local player = e.Parent:ToPlayer()
  local sprite = e:GetSprite()
  local data = e:GetData()

  --e.SpriteOffset = Vector(0, -15)
  e.RenderZOffset = -300

  e.SpriteOffset = Vector(0, -15)

  if not e.Child then
    local handler = Isaac.Spawn(1000, 1749, 151, e.Position, nilvector, e):ToEffect()
    handler.Parent = e
    handler.Visible = false
    handler:Update()

    local rope = Isaac.Spawn(EntityType.ENTITY_EVIS, 10, 150, e.Parent.Position, nilvector, e)
    e.Child = rope

    if not data.init then
      data.state = "flying"
      data.init = true
    end

    rope.Parent = handler
    rope.Target = player

    rope:AddEntityFlags(EntityFlag.FLAG_NO_STATUS_EFFECTS | EntityFlag.FLAG_NO_TARGET | EntityFlag.FLAG_NO_KNOCKBACK |
      EntityFlag.FLAG_NO_PHYSICS_KNOCKBACK)
    rope:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
    rope.DepthOffset = -50
    rope:GetSprite():Play("Idle", true)
    rope:GetSprite():SetFrame(100)
    rope:Update()

    rope.SplatColor = Color(1, 1, 1, 0, 0, 0, 0)

    --check enemy collision
  end
  e.Child:Update()
  e.Child:Update()

  data.HitBlacklist = data.HitBlacklist or {}
  data.checkEntity = data.checkEntity or nil

  local room = Game():GetRoom()
  local checkGrid = room:GetGridCollisionAtPos(e.Position + e.Velocity) >= 2 and 1 or
      room:GetGridCollisionAtPos(e.Position) >= 2 and 2
  local gridEntity = room:GetGridEntityFromPos(e.Position + e.Velocity)
  if checkGrid and gridEntity then
    if not gridEntity:ToPoop() then
      data.state = "return"
      data.HasHitGrid = true
    end
  end

  if data.state == "flying" then
    if data.LaunchVel then
      e.Velocity = data.LaunchVel
    end
    e:GetSprite():Play("Idle", true)
    e.SpriteRotation = (e.Position - player.Position):GetAngleDegrees() + 180
    if not e:GetData().checkEntity and not checkGrid then
      for i = 1, 2 do
        -- Get the "null capsule", which is the hitbox defined by the null layer in the anm2.
        local capsule = e:GetNullCapsule("Hit" .. i)

        -- Search for all enemies within the capsule.
        for _, entity in ipairs(Isaac.FindInCapsule(capsule, EntityPartition.ENEMY)) do
          -- Make sure it can be hurt.
          local isValidEnemy = entity:IsVulnerableEnemy() and entity:IsActiveEnemy() and not data.checkEntity
          local isMovableTNT = (entity:GetType() == EntityType.ENTITY_MOVABLE_TNT)
          if (isValidEnemy or isMovableTNT) and not data.HitBlacklist[GetPtrHash(entity)] then
            data.checkEntity = entity
            data.state = "hooked"
            if entity:IsBoss() then
              data.checkEntity:GetData().isBoss = true
              data.state = "lunge"
            end

            if isValidEnemy then
              entity:TakeDamage(player.Damage / 2, 0, EntityRef(player), 0)
            elseif isMovableTNT then
              entity:TakeDamage(5, 0, EntityRef(player), 0)
            end

            data.HitBlacklist[GetPtrHash(entity)] = true
          end
        end
        --also damage grid entities
        local room = game:GetRoom()
        for _, gridEntity in pairs(lib.FindGridEntitiesInRadius(capsule:GetPosition(), capsule:GetF1())) do
          local gridIndex = gridEntity:GetGridIndex()
          local damaged = room:DamageGrid(gridIndex, 100)
          if damaged then
            data.state = "return"
            data.HasHitGrid = true
            data.launchVel = Vector.Zero
          end
        end
      end
    end

    if data.checkEntity and not data.checkEntity:IsDead() then
      e:GetSprite():Play("Pinned", true)
    elseif data.checkEntity and data.checkEntity:IsDead() then
      if e.Child then
        e.Child:Remove()
      end
      e:Remove()
      data.checkEntity = nil
    end
  elseif data.state == "hooked" then
    if data.checkEntity then
      sfx:Play(SoundEffect.SOUND_DEATH_BURST_LARGE)
      data.state = "return"
      if e:GetData().checkEntity and e:GetData().checkEntity:Exists() then
        local enemy = e:GetData().checkEntity
        local targetVec = ((player.Position + player.Velocity) - enemy.Position)
        if targetVec:Length() > 30 then
          targetVec = targetVec:Resized(30)
        end
        e.Velocity = lib.Lerp(enemy.Velocity, targetVec, 0.4)
      end
      if not sprite:IsPlaying("Pinned") then
        sprite:Play("PinnedIdle", true)
      end
    end
  elseif data.state == "lunge" then
    player.CanFly = true
    if e:GetData().checkEntity and e:GetData().checkEntity:Exists() then
      local enemy = e:GetData().checkEntity
      local segments = MolochMod:GetEntitySegments(enemy)
      if segments ~= nil then
        for i, segment in pairs(segments) do
          local segmentToFreeze = segments[i]:ToNPC()
          if segmentToFreeze ~= nil then
            segmentToFreeze:AddEntityFlags(EntityFlag.FLAG_FREEZE)
          end
        end
      else
        enemy:AddEntityFlags(EntityFlag.FLAG_FREEZE)
      end
      e.Velocity = Vector.Zero
      local targetVec = ((e.Position + e.Velocity) - player.Position)
      if targetVec:Length() > 30 then
        targetVec = targetVec:Resized(30)
      end
      player.Velocity = lib.Lerp(player.Velocity, targetVec, 0.5)
      if e:GetData().checkEntity then
        local enemy = e:GetData().checkEntity
        player:SetMinDamageCooldown(30)
        enemy.Position = e.Position
        MolochMod:ClearFreezeAfterDelay(enemy, 60)
        if e.Position:Distance(player.Position) < enemy.Size then
          if e.Child then
            e.Child:Remove()
          end
          e:Remove()
          player.CanFly = false
        end
      end
    end
  elseif data.state == "return" then
    if data.HasHitGrid then
      local targetVec = ((player.Position + player.Velocity) - e.Position)
      if targetVec:Length() > 10 then
        targetVec = targetVec:Resized(10)
      end
      e.Velocity = lib.Lerp(e.Velocity, targetVec, 0.1)
    else
      local targetVec = ((player.Position + player.Velocity) - e.Position)
      if targetVec:Length() > 30 then
        targetVec = targetVec:Resized(30)
      end
      e.Velocity = lib.Lerp(e.Velocity, targetVec, 0.5)
      if e:GetData().checkEntity then
        local enemy = e:GetData().checkEntity
        enemy:AddEntityFlags(EntityFlag.FLAG_FREEZE)
        player:SetMinDamageCooldown(30)
        enemy.Position = e.Position
        MolochMod:ClearFreezeAfterDelay(enemy, 60)
      end
    end
    if e.Position:Distance(player.Position) < 10 then
      if e.Child then
        e.Child:Remove()
      end
      e:Remove()
    end
  end
end

MolochMod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, MolochMod.UpdateRope, 1962)

MolochMod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, function(_, handler)
  if handler.SubType == 151 then
    if not handler.Parent or not handler.Parent:Exists() then
      handler:Remove()
    else
      handler.Position = handler.Parent.Position + handler.Parent.SpriteOffset + Vector(0, 11)
      handler.Velocity = handler.Parent.Velocity
    end
  end
end, 1749)

MolochMod:AddCallback(ModCallbacks.MC_PRE_NPC_UPDATE, function(_, npc)
  if npc.Variant == 10 and npc.SubType == 162 then
    return false
  end
end, EntityType.ENTITY_EVIS)

-- function MolochMod:IgnorePoops(entity, collider, low)
--   if entity.Variant == 1962 then
--     return true
--   end
-- end

-- MolochMod:AddCallback(ModCallbacks.MC_PRE_NPC_COLLISION, MolochMod.IgnorePoops, 1000)

function MolochMod:ClearFreezeAfterDelay(enemy, delay)
  delayTime = delay
  if delayTime < 0 then
    enemy.ClearEntityFlags(EntityFlag.FLAG_FREEZE)
  end
end

function MolochMod:preGameExit()
  local jsonString = json.encode(MolochMod.PERSISTENT_DATA)
  MolochMod:SaveData(jsonString)
end

MolochMod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, MolochMod.preGameExit)
