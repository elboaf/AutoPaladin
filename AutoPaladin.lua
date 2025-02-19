-- Addon Name
local addonName, addon = "AutoPaladin", {}

-- Variables
local blessingOfMight = "Blessing of Might"
local blessingOfWisdom = "Blessing of Wisdom"
local devotionAura = "Devotion Aura"
local righteousFury = "Righteous Fury"
local sealOfRighteousness = "Seal of Righteousness"
local judgement = "Judgement"
local crusaderStrike = "Crusader Strike"
local consecration = "Consecration"
local holyStrike = "Holy Strike"
local handOfProtection = "Hand of Protection"
local layOnHands = "Lay on Hands"
local dispel = "Purify"

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

-- Function to check if a unit has a specific debuff
local function HasDebuff(unit, debuffName)
    for i = 1, 16 do
        local name = UnitDebuff(unit, i)
        if name and strfind(name, debuffName) then
            return true
        end
    end
    return false
end

-- Function to apply buffs to the player
local function ApplyPlayerBuffs()
    -- Check and apply Seal of Righteousness (always, even in combat)
    if not buffed(sealOfRighteousness, "player") then
        CastSpellByName(sealOfRighteousness)
        SpellTargetUnit("player")
    end

    -- Only apply other buffs if out of combat
    if not UnitAffectingCombat("player") then
        -- Check and apply Blessing of Might
        if not buffed(blessingOfMight, "player") then
            CastSpellByName(blessingOfMight)
            SpellTargetUnit("player")
        end

        -- Check and apply Devotion Aura
        if not buffed(devotionAura, "player") then
            CastSpellByName(devotionAura)
            SpellTargetUnit("player")
        end

        -- Check and apply Righteous Fury
        if not buffed(righteousFury, "player") then
            CastSpellByName(righteousFury)
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
                    if not buffed(blessingOfWisdom, partyMember) then
                        CastSpellByName(blessingOfWisdom)
                        SpellTargetUnit(partyMember)
                    end
                else
                    -- Apply Blessing of Might to non-mana users
                    if not buffed(blessingOfMight, partyMember) then
                        CastSpellByName(blessingOfMight)
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
    if IsSpellReady(judgement) then
        CastSpellByName(judgement)
    end

    -- Cast Crusader Strike if mana is above 50%
    if manaPercentage > 50 and IsSpellReady(crusaderStrike) then
        CastSpellByName(crusaderStrike)
    end

    -- Cast Holy Strike if mana is below 50%
    if manaPercentage <= 50 and IsSpellReady(holyStrike) then
        CastSpellByName(holyStrike)
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
        CastSpellByName(layOnHands)
        SpellTargetUnit("player")
        return
    end

    -- Check for debuffs and cast Purify if needed
    if HasDebuff("player", "Nature_Regenerate") and manaPercentage > 5 then
        CastSpellByName(dispel)
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
                CastSpellByName(layOnHands)
                SpellTargetUnit(partyMember)
                return
            end

            -- Cast Consecration if health is below 90% and in combat
            if health <= 90 and UnitAffectingCombat("player") and manaPercentage > 20 and IsSpellReady(consecration) then
                CastSpellByName(consecration)
            end

            -- Check for debuffs and cast Purify if needed
            if HasDebuff(partyMember, "Nature_Regenerate") and manaPercentage > 5 then
                CastSpellByName(dispel)
                SpellTargetUnit(partyMember)
                return
            end

            -- Cast Hand of Protection if health is below 20% (excluding self)
            if health <= 20 and not UnitIsUnit(partyMember, "player") then
                CastSpellByName(handOfProtection)
                SpellTargetUnit(partyMember)
                return
            end
        end
    end
end

-- Register slash command
SLASH_AUTOPALADIN1 = "/autopaladin"
SlashCmdList["AUTOPALADIN"] = function()
    -- Apply buffs to the player
    ApplyPlayerBuffs()

    -- Apply buffs to party members
    ApplyPartyBuffs()

    -- Cast abilities
    CastAbilities()

    -- Check party health and cast emergency spells
    CheckPartyHealth()
end