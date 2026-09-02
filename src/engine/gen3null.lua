-- =============================================================================
-- gen3null.lua — Pokémon Null (pokeemerald-expansion) Memory Reader
-- Part of Vs. Link | Engine: src/engine/
-- =============================================================================
-- All addresses confirmed against pokeemerald-expansion .map symbols and
-- validated against Baat Tracking Script V1.2.x.
--
-- CRITICAL: Pokémon Null uses a +4 byte shift for encrypted substructures.
--   Vanilla Gen 3: address + 32 + (pSel[n] * 12) + (i * 4)
--   Pokémon Null:  address + 32 + 4 + (pSel[n] * 12) + (i * 4)
-- =============================================================================

-- ── Address Constants ─────────────────────────────────────────────────────────

local NULL_PARTY_COUNT    = 0x0200536D  -- gPlayerPartyCount  (u8)
local NULL_PARTY_BASE     = 0x02005370  -- gPlayerParty        (PartyMon[6], 104 bytes each)
local NULL_STORAGE_BASE   = 0x0200A154  -- gPokemonStorage     (BoxMon base = +4, 84 bytes each)
local NULL_BATTLERS_COUNT = 0x02004D40  -- gBattlersCount      (u8)
local NULL_BATTLE_OUTCOME = 0x02005110  -- gBattleOutcome      (u8)
local NULL_TRAINER_A      = 0x0201962E  -- gTrainerBattleOpponent_A (u16)
local NULL_TRAINER_B      = 0x02019630  -- gTrainerBattleOpponent_B (u16)
local NULL_BATTLE_FLAGS   = 0x02004CB4  -- gBattleTypeFlags    (u32)

local NULL_PARTY_MON_SIZE = 104         -- sizeof(struct Pokemon)
local NULL_BOX_MON_SIZE   = 84          -- sizeof(struct BoxPokemon)
local NULL_BOX_COUNT      = 14          -- 14 boxes (0–13)
local NULL_BOX_SLOTS      = 30          -- 30 slots per box

-- Dead box range (Nuzlocke graveyard convention in Pokémon Null)
local DEAD_BOX_START      = 11          -- boxes 11–13 are "dead" boxes
local DEAD_BOX_END        = 13

-- BoxMon field offsets (relative to slot base address)
local OFF_PERSONALITY     = 0x00        -- u32
local OFF_OTID            = 0x04        -- u32
local OFF_NICKNAME        = 0x08        -- 12 bytes, GBA charmap, 0xFF = end, 0x00 = space
local OFF_LANGUAGE        = 0x14        -- u8
local OFF_FLAGS           = 0x15        -- u8: bit0=badEgg, bit1=hasSpecies, bit2=isEgg
local OFF_OTNAME          = 0x16        -- 7 bytes
local OFF_MARKINGS        = 0x1D        -- u8
local OFF_CHECKSUM        = 0x1E        -- u16
-- Null encrypted data starts at 0x24 (= 32 + 4, not vanilla 32)
local OFF_ENCRYPTED       = 0x24        -- substructs start here

-- PartyMon extra fields (live stats appended after the 84-byte BoxMon section)
local OFF_STATUS          = 80          -- u32
local OFF_LEVEL           = 88          -- u8  (= 84 + 4, Null-specific)
local OFF_HP              = 90          -- u16 (= 86 + 4)
local OFF_MAX_HP          = 92          -- u16 (= 88 + 4)
local OFF_ATTACK          = 94          -- u16 (= 90 + 4)
local OFF_DEFENSE         = 96          -- u16 (= 92 + 4)
local OFF_SPEED           = 98          -- u16 (= 94 + 4)
local OFF_SP_ATTACK       = 100         -- u16 (= 96 + 4)
local OFF_SP_DEFENSE      = 102         -- u16 (= 98 + 4)

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

-- ── String Decoder ────────────────────────────────────────────────────────────
-- Uses the global `charmap` table (populated by the Baat tracking script or
-- ENGINE_TABLES.GBA_CHARMAP). Handles 0xFF terminator and 0x00 space safely.

local function nullDecodeString(rawstring)
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
    -- Strip non-printable characters and trim whitespace
    result = result:gsub("[^\32-\126]", "")
    result = result:match("^%s*(.-)%s*$") or result
    return result
end

-- ── Species ID Resolver ───────────────────────────────────────────────────────
-- During battle, the active Pokémon's species can be encrypted via XOR in RAM.
-- This fallback attempts to decrypt using (personality XOR otId) & 0xFFFF.

local function nullResolveSpeciesId(pMon)
    if not pMon or not pMon.species or pMon.species == 0 then return 0 end
    local sp = pMon.species
    -- Direct table lookup (normal case)
    if NULL_MONS and NULL_MONS[sp] then return sp end
    -- Fallback: XOR decrypt with personality ^ otId
    if pMon.personality and pMon.otId then
        local key = (pMon.personality ~ pMon.otId) & 0xFFFF
        local decrypted = sp ~ key
        if NULL_MONS and NULL_MONS[decrypted] then return decrypted end
    end
    return sp
end

-- ── BoxMon Reader ─────────────────────────────────────────────────────────────
-- Reads a 84-byte BoxPokemon structure at the given address.
-- Applies the Null-specific +4 offset for encrypted substructures.
-- Returns nil if the slot is empty (personality == 0 and species resolves to 0).

function nullReadBoxMon(address)
    local personality = emu:read32(address + OFF_PERSONALITY)
    local otId        = emu:read32(address + OFF_OTID)

    -- Fast empty-slot check: personality 0 means unoccupied
    if personality == 0 then return nil end

    local mon = {}
    mon.personality = personality
    mon.otId        = otId

    -- Decode nickname (12 GBA-encoded bytes starting at offset 0x08)
    local rawNick = emu:readRange(address + OFF_NICKNAME, 12)
    mon.nickname  = nullDecodeString(rawNick)

    -- Decode OT name (7 bytes at 0x16)
    local rawOT = emu:readRange(address + OFF_OTNAME, 7)
    mon.otName  = nullDecodeString(rawOT)

    mon.language  = emu:read8(address + OFF_LANGUAGE)
    local flagByte = emu:read8(address + OFF_FLAGS)
    mon.isBadEgg  = (flagByte & 1) ~= 0
    mon.hasSpecies = ((flagByte >> 1) & 1) ~= 0
    mon.isEgg     = ((flagByte >> 2) & 1) ~= 0
    mon.markings  = emu:read8(address + OFF_MARKINGS)
    mon.checksum  = emu:read16(address + OFF_CHECKSUM)

    -- ── Decrypt Substructures ─────────────────────────────────────────────────
    local key  = otId ~ personality
    local pSel = SUBSTRUCT_ORDER[personality % 24]

    -- Each substruct is 12 bytes (3 × u32). Read and XOR-decrypt.
    -- Null-specific: encrypted data starts at address + 0x24 (= 32 + 4)
    local ss0, ss1, ss2, ss3 = {}, {}, {}, {}
    for i = 0, 2 do
        ss0[i] = emu:read32(address + OFF_ENCRYPTED + pSel[1] * 12 + i * 4) ~ key
        ss1[i] = emu:read32(address + OFF_ENCRYPTED + pSel[2] * 12 + i * 4) ~ key
        ss2[i] = emu:read32(address + OFF_ENCRYPTED + pSel[3] * 12 + i * 4) ~ key
        ss3[i] = emu:read32(address + OFF_ENCRYPTED + pSel[4] * 12 + i * 4) ~ key
    end

    -- ── Substruct G (Growth) — ss0 ────────────────────────────────────────────
    local rawSpecies    = ss0[0] & 0xFFFF
    mon.speciesId       = rawSpecies
    mon.species         = nullResolveSpeciesId({ species = rawSpecies, personality = personality, otId = otId })
    mon.speciesName     = (NULL_MONS and NULL_MONS[mon.species]) or nil
    mon.heldItemId      = ss0[0] >> 16
    mon.heldItemName    = (NULL_ITEMS and NULL_ITEMS[mon.heldItemId]) or nil
    mon.experience      = ss0[1]
    mon.ppBonuses       = ss0[2] & 0xFF
    mon.friendship      = (ss0[2] >> 8) & 0xFF
    -- hiddenNature stored in bits 21–25 of ss0[2] (Null-specific, not personality % 25)
    mon.hiddenNature    = (ss0[2] >> 21) & 0x1F
    local natureIdx     = mon.hiddenNature
    -- If hiddenNature == 26 (sentinel for "use personality"), fall back to personality % 25
    if natureIdx == 26 then natureIdx = personality % 25 end
    mon.nature          = (NULL_NATURES and NULL_NATURES[natureIdx + 1]) or ("nature_" .. natureIdx)

    -- ── Substruct A (Attacks) — ss1 ───────────────────────────────────────────
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

    -- ── Substruct E (EVs & Condition) — ss2 ──────────────────────────────────
    mon.hpEV        = ss2[0] & 0xFF
    mon.attackEV    = (ss2[0] >> 8) & 0xFF
    mon.defenseEV   = (ss2[0] >> 16) & 0xFF
    mon.speedEV     = ss2[0] >> 24
    mon.spAttackEV  = ss2[1] & 0xFF
    mon.spDefenseEV = (ss2[1] >> 8) & 0xFF

    -- ── Substruct M (Miscellaneous) — ss3 ────────────────────────────────────
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
    -- Ability slot: bits 29–30 of ss3[2]
    mon.abilitySlot  = (ss3[2] >> 29) & 0x3

    return mon
end

-- ── PartyMon Reader ───────────────────────────────────────────────────────────
-- Reads a 104-byte Pokemon (party) structure. Calls nullReadBoxMon for the
-- first 84 bytes, then reads the live battle stats from the remaining 20 bytes.
-- All stat offsets use the Null-specific +4 shift from the slot base address.

function nullReadPartyMon(address)
    local mon = nullReadBoxMon(address)
    if not mon then return nil end

    mon.status    = emu:read32(address + OFF_STATUS)
    mon.level     = emu:read8( address + OFF_LEVEL)
    mon.hp        = emu:read16(address + OFF_HP)
    mon.maxHP     = emu:read16(address + OFF_MAX_HP)
    mon.attack    = emu:read16(address + OFF_ATTACK)
    mon.defense   = emu:read16(address + OFF_DEFENSE)
    mon.speed     = emu:read16(address + OFF_SPEED)
    mon.spAttack  = emu:read16(address + OFF_SP_ATTACK)
    mon.spDefense = emu:read16(address + OFF_SP_DEFENSE)

    return mon
end

-- ── Party Reader ──────────────────────────────────────────────────────────────
-- Reads up to 6 party slots from gPlayerParty using gPlayerPartyCount.

function nullGetParty()
    local count = emu:read8(NULL_PARTY_COUNT)
    if count < 0 or count > 6 then count = 0 end
    local party = {}
    for i = 1, count do
        local addr = NULL_PARTY_BASE + (i - 1) * NULL_PARTY_MON_SIZE
        local mon = nullReadPartyMon(addr)
        if mon then
            table.insert(party, mon)
        end
    end
    return party
end

-- ── PC Box Reader ─────────────────────────────────────────────────────────────
-- Reads all 14 boxes (420 slots) from gPokemonStorage + 4.
-- Returns a flat array of occupied slots, each with box/slot index and
-- a boolean isDeadBox flag for the Nuzlocke graveyard range (boxes 11–13).

function nullGetBoxes()
    local base = NULL_STORAGE_BASE + 4  -- Box data starts 4 bytes into gPokemonStorage
    local results = {}

    for box = 0, NULL_BOX_COUNT - 1 do
        for slot = 0, NULL_BOX_SLOTS - 1 do
            local addr = base + (box * NULL_BOX_SLOTS + slot) * NULL_BOX_MON_SIZE
            -- Quick screen: personality == 0 means empty
            if emu:read32(addr + OFF_PERSONALITY) ~= 0 then
                local mon = nullReadBoxMon(addr)
                if mon and mon.species ~= 0 then
                    mon.box       = box
                    mon.slot      = slot
                    mon.isDeadBox = (box >= DEAD_BOX_START and box <= DEAD_BOX_END)
                    table.insert(results, mon)
                end
            end
        end
    end

    return results
end

-- ── Battle State Reader ───────────────────────────────────────────────────────
-- Returns the current battle metadata for calculator consumption.

function nullGetBattleState()
    local bCount    = emu:read8( NULL_BATTLERS_COUNT)
    local outcome   = emu:read8( NULL_BATTLE_OUTCOME)
    local trainerA  = emu:read16(NULL_TRAINER_A)
    local trainerB  = emu:read16(NULL_TRAINER_B)
    local flags     = emu:read32(NULL_BATTLE_FLAGS)

    -- Bit 3 of gBattleTypeFlags = BATTLE_TYPE_TRAINER
    local isTrainerBattle = (math.floor(flags / 8) % 2 ~= 0)
    local inBattle = (bCount > 0 and outcome == 0 and trainerA ~= 0 and isTrainerBattle)

    return {
        inBattle       = inBattle,
        battlersCount  = bCount,
        outcome        = outcome,
        trainerIdA     = trainerA,
        trainerIdB     = trainerB,
        isTrainerBattle = isTrainerBattle,
        flags          = flags,
    }
end

-- ── Game Info ─────────────────────────────────────────────────────────────────

function nullGetInfo()
    return {
        version    = "null",
        like       = "emerald-expansion",
        generation = 3,
    }
end
