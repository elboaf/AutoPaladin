-- Addon Name
local addonName, addon = "AutoPaladin", {}

-- Spell Names
local BLESSING_OF_MIGHT = "Blessing of Might"
local BLESSING_OF_WISDOM = "Blessing of Wisdom"
local DEVOTION_AURA = "Devotion Aura"
local RIGHTEOUS_FURY = "Righteous Fury"
local SEAL_OF_RIGHTEOUSNESS = "Seal of Righteousness"
local SEAL_OF_WISDOM = "Seal of Wisdom"
local JUDGEMENT = "Judgement"
local CRUSADER_STRIKE = "Crusader Strike"
local CONSECRATION = "Consecration"
local HOLY_STRIKE = "Holy Strike"
local HAND_OF_PROTECTION = "Hand of Protection"
local LAY_ON_HANDS = "Lay on Hands"
local DISPEL = "Purify"
local FREEDOM = "Hand of Freedom"

-- Debuff Lists
local DEBUFFS_TO_DISPEL = {
    "Nature_Regenerate",
    "HarmUndead",
    "CallofBone",
    "CorrosiveBreath",
    -- Add more debuff names here as needed
}

local DEBUFFS_TO_FREEDOM = {
    "snare",
    -- Add more debuff names here as needed
}

-- Function to find a spell ID by name
local function FindSpellID(spellName)
    for i = 1, 180 do
        local name = GetSpellName(i, BOOKTYPE_SPELL)
        if name and strfind(name, spellName) then
            return i
        end
    end
    return nil
end

-- Function to check if a spell is ready
local function IsSpellReady(spellName)
    local spellID = FindSpellID(spellName)
    if spellID then
        local start, duration = GetSpellCooldown(spellID, BOOKTYPE_SPELL)
        return start == 0 and duration <= 1.5 -- Cooldown is ready
    end
    return false
end

-- Function to check if a unit is a mana user
local function IsManaUser(unit)
    local powerType = UnitPowerType(unit)
    return powerType == 0 -- 0 = Mana, 1 = Rage, 2 = Focus, 3 = Energy
end

-- Function to check if a unit has any of the debuffs in the list
local function HasDebuff(unit, debuffList)
    for i = 1, 16 do
        local name = UnitDebuff(unit, i)
        if name then
            for _, debuff in ipairs(debuffList) do
                if strfind(name, debuff) then
                    return true
                end
            end
        end
    end
    return false
end

-- Function to apply buffs to the player
local function ApplyPlayerBuffs()
    local currentMana = UnitMana("player")
    local maxMana = UnitManaMax("player")
    local manaPercentage = (currentMana / maxMana) * 100

    -- Check and apply Seal of Righteousness (always, even in combat)
    if not buffed(SEAL_OF_RIGHTEOUSNESS, "player") and manaPercentage > 70 then
        CastSpellByName(SEAL_OF_RIGHTEOUSNESS)
        SpellTargetUnit("player")
    end

    -- Check and apply Seal of Wisdom if mana is below 50%
    if not buffed(SEAL_OF_WISDOM, "player") and manaPercentage < 70 then
        CastSpellByName(SEAL_OF_WISDOM)
        SpellTargetUnit("player")
    end

    -- Only apply other buffs if out of combat
    if not UnitAffectingCombat("player") then
        -- Check and apply Blessing of Might
        if not buffed(BLESSING_OF_MIGHT, "player") then
            CastSpellByName(BLESSING_OF_MIGHT)
            SpellTargetUnit("player")
        end

        -- Check and apply Devotion Aura
        if not buffed(DEVOTION_AURA, "player") then
            CastSpellByName(DEVOTION_AURA)
            SpellTargetUnit("player")
        end

        -- Check and apply Righteous Fury
        if not buffed(RIGHTEOUS_FURY, "player") then
            CastSpellByName(RIGHTEOUS_FURY)
            SpellTargetUnit("player")
        end
    end
end

-- Function to apply buffs to party members
local function ApplyPartyBuffs()
    -- Only apply buffs if out of combat
    if not UnitAffectingCombat("player") then
        for i = 1, 4 do
            local partyMember = "party" .. i
            if UnitExists(partyMember) and not UnitIsUnit(partyMember, "player") then
                if IsManaUser(partyMember) then
                    -- Apply Blessing of Wisdom to mana users
                    if not buffed(BLESSING_OF_WISDOM, partyMember) then
                        CastSpellByName(BLESSING_OF_WISDOM)
                        SpellTargetUnit(partyMember)
                    end
                else
                    -- Apply Blessing of Might to non-mana users
                    if not buffed(BLESSING_OF_MIGHT, partyMember) then
                        CastSpellByName(BLESSING_OF_MIGHT)
                        SpellTargetUnit(partyMember)
                    end
                end
            end
        end
    end
end

-- Function to check and cast abilities
local function CastAbilities()
    local currentMana = UnitMana("player")
    local maxMana = UnitManaMax("player")
    local manaPercentage = (currentMana / maxMana) * 100

    -- Cast Judgement on cooldown
    if IsSpellReady(JUDGEMENT) then
        CastSpellByName(JUDGEMENT)
    end

    -- Cast Crusader Strike if mana is above 50%
    if manaPercentage > 50 and IsSpellReady(CRUSADER_STRIKE) then
        CastSpellByName(CRUSADER_STRIKE)
    end

    -- Cast Holy Strike if mana is below 50%
    if manaPercentage <= 50 and IsSpellReady(HOLY_STRIKE) then
        CastSpellByName(HOLY_STRIKE)
    end
end

-- Function to check party health and cast emergency spells
local function CheckPartyHealth()
    local currentMana = UnitMana("player")
    local maxMana = UnitManaMax("player")
    local manaPercentage = (currentMana / maxMana) * 100

    -- Check self first
    local selfHealth = UnitHealth("player") / UnitHealthMax("player") * 100
    if selfHealth <= 10 then
        CastSpellByName(LAY_ON_HANDS)
        SpellTargetUnit("player")
        return
    end

    -- Check for debuffs and cast Purify if needed
    if HasDebuff("player", DEBUFFS_TO_DISPEL) and manaPercentage > 5 then
        CastSpellByName(DISPEL)
        SpellTargetUnit("player")
        return
    end

    if HasDebuff("player", DEBUFFS_TO_FREEDOM) and manaPercentage > 5 then
        CastSpellByName(FREEDOM)
        SpellTargetUnit("player")
        return
    end

    -- Check party members
    for i = 1, 4 do
        local partyMember = "party" .. i
        if UnitExists(partyMember) then
            local health = UnitHealth(partyMember) / UnitHealthMax(partyMember) * 100

            -- Cast Lay on Hands if health is below 10%
            if health <= 10 then
                CastSpellByName(LAY_ON_HANDS)
                SpellTargetUnit(partyMember)
                return
            end

            -- Cast Consecration if health is below 90% and in combat
            if health <= 80 and UnitAffectingCombat("player") and manaPercentage > 20 and IsSpellReady(CONSECRATION) then
                CastSpellByName(CONSECRATION)
            end

            -- Check for debuffs and cast Purify if needed
            if HasDebuff(partyMember, DEBUFFS_TO_DISPEL) and manaPercentage > 5 then
                CastSpellByName(DISPEL)
                SpellTargetUnit(partyMember)
                return
            end

            if HasDebuff(partyMember, DEBUFFS_TO_FREEDOM) and manaPercentage > 5 then
                CastSpellByName(FREEDOM)
                SpellTargetUnit(partyMember)
                return
            end

            -- Cast Hand of Protection if health is below 20% (excluding self)
            if health <= 20 and not UnitIsUnit(partyMember, "player") then
                CastSpellByName(HAND_OF_PROTECTION)
                SpellTargetUnit(partyMember)
                return
            end
        end
    end
end

-- Register slash command
SLASH_AUTOPALADIN1 = "/autopaladin"
SlashCmdList["AUTOPALADIN"] = function()
    ApplyPlayerBuffs()
    ApplyPartyBuffs()
    CastAbilities()
    CheckPartyHealth()
end