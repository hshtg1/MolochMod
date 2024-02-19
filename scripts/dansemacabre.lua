local sfx = SFXManager()
local DANSE_MACABRE_ITEM_ID = Isaac.GetItemIdByName("Danse Macabre")

function MolochMod:InitializeDanseMacabre(player)
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
