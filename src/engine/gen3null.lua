-- =============================================================================
-- gen3null.lua — Generic GBA Expansion Reader (Factory Pattern)
-- Part of Vs. Link | src/engine/
-- =============================================================================
-- Reads Pokémon memory structures for pokeemerald-expansion ROM hacks
-- (such as Pokémon Null). Decoupled from hardcoded addresses: each game/patch
-- profile provides its own address table via createExpansionReader(profile).
-- =============================================================================

-- ── Substructure Permutation Table ───────────────────────────────────────────
-- personality % 24 selects the order of the 4 substructs (G=0, A=1, E=2, M=3)

local SUBSTRUCT_ORDER = {
    [0]  = {0, 1, 2, 3}, [1]  = {0, 1, 3, 2}, [2]  = {0, 2, 1, 3}, [3]  = {0, 3, 1, 2},
    [4]  = {0, 2, 3, 1}, [5]  = {0, 3, 2, 1}, [6]  = {1, 0, 2, 3}, [7]  = {1, 0, 3, 2},
    [8]  = {2, 0, 1, 3}, [9]  = {3, 0, 1, 2}, [10] = {2, 0, 3, 1}, [11] = {3, 0, 2, 1},
    [12] = {1, 2, 0, 3}, [13] = {1, 3, 0, 2}, [14] = {2, 1, 0, 3}, [15] = {3, 1, 0, 2},
    [16] = {2, 3, 0, 1}, [17] = {3, 2, 0, 1}, [18] = {1, 2, 3, 0}, [19] = {1, 3, 2, 0},
    [20] = {2, 1, 3, 0}, [21] = {3, 1, 2, 0}, [22] = {2, 3, 1, 0}, [23] = {3, 2, 1, 0},
}

-- ── Common Offsets inside BoxMon (relative to mon start) ─────────────────────
local OFF_PERSONALITY = 0x00
local OFF_OTID        = 0x04
local OFF_NICKNAME    = 0x08
local OFF_LANGUAGE    = 0x14
local OFF_FLAGS       = 0x15
local OFF_OTNAME      = 0x16
local OFF_MARKINGS    = 0x1D
local OFF_CHECKSUM    = 0x1E

-- ── Safe String Decoder ──────────────────────────────────────────────────────
local function decodeGbaString(rawstring)
    local result = ""
    for _, char in ipairs({rawstring:byte(1, #rawstring)}) do
        if char == 0xFF then
            break
        elseif char == 0x00 then
            result = result .. " "
        elseif charmap and charmap[char] then
            result = result .. charmap[char]
        end
    end
    result = result:gsub("[^\32-\126]", "")
    result = result:match("^%s*(.-)%s*$") or result
    return result
end

-- ── Dynamic Species ID Fallback Resolver ─────────────────────────────────────
local function resolveSpeciesId(pMon)
    if not pMon or not pMon.species or pMon.species == 0 then return 0 end
    local sp = pMon.species
    if NULL_MONS and NULL_MONS[sp] then return sp end
    if pMon.personality and pMon.otId then
        local key = (pMon.personality ~ pMon.otId) & 0xFFFF
        local decrypted = sp ~ key
        if NULL_MONS and NULL_MONS[decrypted] then return decrypted end
    end
    return sp
end

-- ── Experience Curves Calculation ───────────────────────────────────────────
local function expSlow(n)        return math.floor((5 * (n ^ 3)) / 4) end
local function expFast(n)        return math.floor((4 * (n ^ 3)) / 5) end
local function expMedFast(n)     return n ^ 3 end
local function expMedSlow(n)     return math.floor((6 * (n ^ 3)) / 5) - (15 * (n ^ 2)) + (100 * n) - 140 end

local function expErratic(n)
    if n <= 50 then      return math.floor(((100 - n) * (n ^ 3)) / 50)
    elseif n <= 68 then  return math.floor(((150 - n) * (n ^ 3)) / 100)
    elseif n <= 98 then  return math.floor(math.floor((1911 - 10 * n) / 3) * (n ^ 3) / 500)
    else                 return math.floor((160 - n) * (n ^ 3) / 100)
    end
end

local function expFluctuating(n)
    if n < 15 then       return math.floor((math.floor((n + 1) / 3) + 24) * (n ^ 3) / 50)
    elseif n <= 36 then  return math.floor((n + 14) * (n ^ 3) / 50)
    else                 return math.floor((math.floor(n / 2) + 32) * (n ^ 3) / 50)
    end
end

local function calcExpRequired(curve, level)
    if level <= 1 then return 0 end
    if curve == 0 then return expMedFast(level)
    elseif curve == 1 then return expErratic(level)
    elseif curve == 2 then return expFluctuating(level)
    elseif curve == 3 then return expMedSlow(level)
    elseif curve == 4 then return expFast(level)
    elseif curve == 5 then return expSlow(level)
    end
    return expMedFast(level)
end

-- =============================================================================
-- createExpansionReader(profile)
-- Factory function returning an engine reader table:
-- { getInfo, getParty, getBoxes, getBattle, readBoxMon, readPartyMon }
-- =============================================================================
function createExpansionReader(profile)
    local addr   = profile.addresses or {}
    local layout = profile.layout or {}

    -- Configuration & Layout parameters with sensible defaults
    local partyMonSize    = layout.partyMonSize or 104
    local boxMonSize      = layout.boxMonSize or 84
    local encryptedOffset = layout.encryptedOffset or 0x24  -- 32 + 4 for pokeemerald-expansion
    local boxCount        = layout.boxCount or 14
    local boxSlots        = layout.boxSlots or 30
    local deadBoxStart    = layout.deadBoxStart or 11
    local deadBoxEnd      = layout.deadBoxEnd or 13
    local hasEVs          = (layout.hasEVs == true)  -- Defaults to false for Null (no EVs)

    -- Level Curve reading from ROM (offset +21 in SpeciesInfo)
    local speciesInfoAddr = addr.speciesInfo or 0x083E0448
    local function getExpCurve(speciesId)
        if not speciesId or speciesId <= 0 then return 0 end
        return emu:read8(speciesInfoAddr + (36 * speciesId) + 21)
    end

    local function calcLevelFromExp(exp, speciesId)
        if type(calcLevel) == "function" then
            local ok, res = pcall(calcLevel, exp, speciesId)
            if ok and res and res > 0 then return res end
        end
        if not exp or exp <= 0 then return 1 end
        local curve = getExpCurve(speciesId)
        local level = 1
        while level < 100 and exp >= calcExpRequired(curve, level + 1) do
            level = level + 1
        end
        return level
    end

    -- ── Reader for a single BoxPokemon (84 bytes) ─────────────────────────────
    local function readBoxMon(address)
        local personality = emu:read32(address + OFF_PERSONALITY)
        local otId        = emu:read32(address + OFF_OTID)

        if personality == 0 then return nil end

        local mon = {}
        mon.personality = personality
        mon.otId        = otId

        mon.nickname = decodeGbaString(emu:readRange(address + OFF_NICKNAME, 12))
        mon.otName   = decodeGbaString(emu:readRange(address + OFF_OTNAME, 7))
        mon.language = emu:read8(address + OFF_LANGUAGE)

        local flagByte = emu:read8(address + OFF_FLAGS)
        mon.isBadEgg   = (flagByte & 1) ~= 0
        mon.hasSpecies = ((flagByte >> 1) & 1) ~= 0
        mon.isEgg      = ((flagByte >> 2) & 1) ~= 0
        mon.markings   = emu:read8(address + OFF_MARKINGS)
        mon.checksum   = emu:read16(address + OFF_CHECKSUM)

        -- Decrypt 4 substructs (12 bytes each)
        local key  = otId ~ personality
        local pSel = SUBSTRUCT_ORDER[personality % 24]
        local ss0, ss1, ss2, ss3 = {}, {}, {}, {}

        for i = 0, 2 do
            ss0[i] = emu:read32(address + encryptedOffset + pSel[1] * 12 + i * 4) ~ key
            ss1[i] = emu:read32(address + encryptedOffset + pSel[2] * 12 + i * 4) ~ key
            ss2[i] = emu:read32(address + encryptedOffset + pSel[3] * 12 + i * 4) ~ key
            ss3[i] = emu:read32(address + encryptedOffset + pSel[4] * 12 + i * 4) ~ key
        end

        -- Substruct G (Growth)
        local rawSpecies = ss0[0] & 0xFFFF
        mon.speciesId    = rawSpecies
        mon.species      = resolveSpeciesId({ species = rawSpecies, personality = personality, otId = otId })
        mon.speciesName  = (NULL_MONS and NULL_MONS[mon.species]) or nil
        mon.heldItemId   = ss0[0] >> 16
        mon.heldItemName = (NULL_ITEMS and NULL_ITEMS[mon.heldItemId]) or nil
        mon.experience   = ss0[1]
        mon.level        = calcLevelFromExp(mon.experience, mon.species)
        mon.ppBonuses    = ss0[2] & 0xFF
        mon.friendship   = (ss0[2] >> 8) & 0xFF

        mon.hiddenNature = (ss0[2] >> 21) & 0x1F
        local natureIdx  = mon.hiddenNature
        if natureIdx == 26 then natureIdx = personality % 25 end
        mon.nature       = (NULL_NATURES and NULL_NATURES[natureIdx + 1]) or ("nature_" .. natureIdx)

        -- Substruct A (Attacks)
        mon.moveIds = {
            ss1[0] & 0xFFFF,
            ss1[0] >> 16,
            ss1[1] & 0xFFFF,
            ss1[1] >> 16,
        }
        mon.moveNames = {}
        for i = 1, 4 do
            mon.moveNames[i] = (NULL_MOVES and NULL_MOVES[mon.moveIds[i] + 1]) or nil
        end
        mon.pp = {
            ss1[2] & 0xFF,
            (ss1[2] >> 8) & 0xFF,
            (ss1[2] >> 16) & 0xFF,
            ss1[2] >> 24,
        }

        -- Substruct E (EVs)
        -- In Pokémon Null, there are NO EVs (always 0). Raw memory bytes in ss2 are ignored.
        mon.hpEV        = hasEVs and (ss2[0] & 0xFF) or 0
        mon.attackEV    = hasEVs and ((ss2[0] >> 8) & 0xFF) or 0
        mon.defenseEV   = hasEVs and ((ss2[0] >> 16) & 0xFF) or 0
        mon.speedEV     = hasEVs and (ss2[0] >> 24) or 0
        mon.spAttackEV  = hasEVs and (ss2[1] & 0xFF) or 0
        mon.spDefenseEV = hasEVs and ((ss2[1] >> 8) & 0xFF) or 0

        mon.evs = {
            hp  = mon.hpEV,
            atk = mon.attackEV,
            def = mon.defenseEV,
            spa = mon.spAttackEV,
            spd = mon.spDefenseEV,
            spe = mon.speedEV,
        }

        -- Substruct M (Misc & IVs)
        mon.pokerus      = ss3[0] & 0xFF
        mon.metLocation  = (ss3[0] >> 8) & 0xFF
        local metFlags   = ss3[0] >> 16
        mon.metLevel     = metFlags & 0x7F
        mon.metGame      = (metFlags >> 7) & 0xF
        mon.pokeball     = (metFlags >> 11) & 0xF
        mon.otGender     = (metFlags >> 15) & 0x1

        local ivFlags    = ss3[1]
        mon.hpIV         = (ivFlags >> 0)  & 0x1F
        mon.attackIV     = (ivFlags >> 5)  & 0x1F
        mon.defenseIV    = (ivFlags >> 10) & 0x1F
        mon.speedIV      = (ivFlags >> 15) & 0x1F
        mon.spAttackIV   = (ivFlags >> 20) & 0x1F
        mon.spDefenseIV  = (ivFlags >> 25) & 0x1F
        mon.abilitySlot  = (ss3[2] >> 29) & 0x3

        mon.ivs = {
            hp  = mon.hpIV,
            atk = mon.attackIV,
            def = mon.defenseIV,
            spa = mon.spAttackIV,
            spd = mon.spDefenseEV,
            spe = mon.speedIV,
        }

        return mon
    end

    -- ── Reader for a PartyPokemon (104 bytes) ─────────────────────────────────
    local function readPartyMon(address)
        local mon = readBoxMon(address)
        if not mon then return nil end

        -- Null format has +4 shift on live stats:
        -- level=88, hp=90, maxHP=92, atk=94, def=96, spe=98, spa=100, spd=102
        local shift = (partyMonSize > 100) and 4 or 0

        mon.status    = emu:read32(address + 80)
        local pLvl    = emu:read8(address + 84 + shift)
        if pLvl and pLvl > 0 then
            mon.level = pLvl
        end
        mon.hp        = emu:read16(address + 86 + shift)
        mon.maxHP     = emu:read16(address + 88 + shift)
        mon.attack    = emu:read16(address + 90 + shift)
        mon.defense   = emu:read16(address + 92 + shift)
        mon.speed     = emu:read16(address + 94 + shift)
        mon.spAttack  = emu:read16(address + 96 + shift)
        mon.spDefense = emu:read16(address + 98 + shift)

        return mon
    end

    -- ── Public Reader Interface ───────────────────────────────────────────────
    local reader = {}

    reader.getInfo = function()
        return {
            name       = profile.name or "Pokemon Null",
            version    = profile.version or "null",
            like       = profile.like or "emerald-expansion",
            generation = profile.generation or 3,
            crc        = profile.crc and string.format("0x%08X", profile.crc) or nil,
        }
    end

    reader.getParty = function()
        local partyAddr  = addr.party or 0x02005370
        local countAddr  = addr.partyCount or 0x0200536D
        local count      = emu:read8(countAddr)

        if count < 0 or count > 6 then count = 0 end
        local party = {}
        for i = 1, count do
            local slotAddr = partyAddr + (i - 1) * partyMonSize
            local pkm = readPartyMon(slotAddr)
            if pkm then
                table.insert(party, pkm)
            end
        end
        return party
    end

    reader.getBoxes = function()
        local storageBase = addr.storage or 0x0200A154
        local boxBase = storageBase + 4
        local results = {}

        for box = 0, boxCount - 1 do
            for slot = 0, boxSlots - 1 do
                local slotAddr = boxBase + (box * boxSlots + slot) * boxMonSize
                if emu:read32(slotAddr + OFF_PERSONALITY) ~= 0 then
                    local pkm = readBoxMon(slotAddr)
                    if pkm and pkm.species ~= 0 then
                        pkm.box       = box
                        pkm.slot      = slot
                        pkm.isDeadBox = (box >= deadBoxStart and box <= deadBoxEnd)
                        table.insert(results, pkm)
                    end
                end
            end
        end
        return results
    end

    reader.getBattle = function()
        local bCount   = addr.battlersCount and emu:read8(addr.battlersCount) or 0
        local outcome  = addr.battleOutcome and emu:read8(addr.battleOutcome) or 0
        local trainerA = addr.trainerA and emu:read16(addr.trainerA) or 0
        local trainerB = addr.trainerB and emu:read16(addr.trainerB) or 0
        local flags    = addr.battleFlags and emu:read32(addr.battleFlags) or 0

        local isTrainerBattle = (math.floor(flags / 8) % 2 ~= 0)
        local inBattle = (bCount > 0 and outcome == 0 and trainerA ~= 0 and isTrainerBattle)

        return {
            inBattle        = inBattle,
            battlersCount   = bCount,
            outcome         = outcome,
            trainerIdA      = trainerA,
            trainerIdB      = trainerB,
            isTrainerBattle = isTrainerBattle,
            flags           = flags,
        }
    end

    reader.readBoxMon   = readBoxMon
    reader.readPartyMon = readPartyMon

    return reader
end

-- ── Default Fallback Globals ──────────────────────────────────────────────────
-- Fallback aliases for any legacy code calling nullGetParty() directly
local defaultReader = createExpansionReader({
    name = "Pokemon Null (Default)",
    addresses = {
        partyCount    = 0x0200536D,
        party         = 0x02005370,
        storage       = 0x0200A154,
        speciesInfo   = 0x083E0448,
        battlersCount = 0x02004D40,
        battleOutcome = 0x02005110,
        trainerA      = 0x0201962E,
        trainerB      = 0x02019630,
        battleFlags   = 0x02004CB4,
    }
})

function nullGetInfo()        return defaultReader.getInfo() end
function nullGetParty()       return defaultReader.getParty() end
function nullGetBoxes()       return defaultReader.getBoxes() end
function nullGetBattleState() return defaultReader.getBattle() end
function nullReadBoxMon(a)    return defaultReader.readBoxMon(a) end
function nullReadPartyMon(a)  return defaultReader.readPartyMon(a) end
function nullDecodeString(s)  return decodeGbaString(s) end
