local sfx = SFXManager()
local DANSE_MACABRE_ITEM_ID = Isaac.GetItemIdByName("Danse Macabre")
local molochType = Isaac.GetPlayerTypeByName("Moloch", false)

function MolochMod:InitializeDanseMacabre(player)
    if player:GetPlayerType() ~= molochType then
        return -- End the function early. The below code doesn't run, as long as the player isn't Moloch.
    end
    player:SetPocketActiveItem(DANSE_MACABRE_ITEM_ID, ActiveSlot.SLOT_POCKET, true)
end

MolochMod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, MolochMod.InitializeDanseMacabre)

function MolochMod:UseDanseMacabre(collectibleType, rng, player, useFlags, activeSlot, _)
    sfx:Play(SoundEffect.SOUND_SWORD_SPIN)
    return {
        Discharge = false,
        Remove = false,
        ShowAnim = false,
    }
end

MolochMod:AddCallback(ModCallbacks.MC_USE_ITEM, MolochMod.UseDanseMacabre, DANSE_MACABRE_ITEM_ID)
