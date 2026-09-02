-- =============================================================================
-- profiles.lua — Declarative Game Profiles for Pokémon Null & Expansion Hacks
-- Part of Vs. Link | src/engine/
-- =============================================================================
-- To add support for a new patch or ROM version (e.g. Null 1.2.5), simply copy
-- one of the tables below, update the CRC and memory addresses from the .map file.
-- All parsing logic (104-byte PartyMon, +4 shift, box levels, etc.) is applied
-- automatically by createExpansionReader().
-- =============================================================================

GBA_EXPANSION_PROFILES = {
    -- ── Pokémon Null v1.2.4 (Active Release) ──────────────────────────────────
    {
        name       = "Pokemon Null v1.2.4",
        version    = "null-1.2.4",
        like       = "emerald-expansion",
        generation = 3,

        -- ROM Header matching
        code       = "AGB-BPEE",       -- Matches both "AGB-BPEE" and "BPEE"
        title      = "POKEMON EMER",   -- Header title in Null v1.2.4 ROM
        crc        = 0x0FA75094,       -- Exact CRC of Null v1.2.4

        -- Memory addresses extracted from pokeemerald .map
        addresses  = {
            partyCount    = 0x0200536D, -- gPlayerPartyCount (u8)
            party         = 0x02005370, -- gPlayerParty (PartyMon[6], 104 bytes each)
            storage       = 0x0200A154, -- gPokemonStorage (BoxMon data at storage + 4)
            speciesInfo   = 0x083E0448, -- gSpeciesInfo table in ROM (curve offset +21)
            battlersCount = 0x02004D40, -- gBattlersCount (u8)
            battleOutcome = 0x02005110, -- gBattleOutcome (u8)
            trainerA      = 0x0201962E, -- gTrainerBattleOpponent_A (u16)
            trainerB      = 0x02019630, -- gTrainerBattleOpponent_B (u16)
            battleFlags   = 0x02004CB4, -- gBattleTypeFlags (u32)
        },

        -- Structural layout (defaults to pokeemerald-expansion if omitted)
        layout     = {
            partyMonSize    = 104,  -- sizeof(struct Pokemon)
            boxMonSize      = 84,   -- sizeof(struct BoxPokemon)
            encryptedOffset = 0x24, -- Substructs offset (32 + 4 for Null)
            boxCount        = 14,   -- 14 PC boxes
            boxSlots        = 30,   -- 30 slots per box
            deadBoxStart    = 11,   -- Nuzlocke graveyard start (box index 11)
            deadBoxEnd      = 13,   -- Nuzlocke graveyard end   (box index 13)
            hasEVs          = false, -- Pokémon Null has no EVs (all EVs forced to 0)
        }
    },

    -- ── Pokémon Null (Wildcard Fallback for other builds) ─────────────────────
    {
        name       = "Pokemon Null (Fallback)",
        version    = "null",
        like       = "emerald-expansion",
        generation = 3,

        code       = "AGB-BPEE",
        title      = "POKEMON NULL",
        crc        = nil,              -- Wildcard: matches any build titled POKEMON NULL

        addresses  = {
            partyCount    = 0x0200536D,
            party         = 0x02005370,
            storage       = 0x0200A154,
            speciesInfo   = 0x083E0448,
            battlersCount = 0x02004D40,
            battleOutcome = 0x02005110,
            trainerA      = 0x0201962E,
            trainerB      = 0x02019630,
            battleFlags   = 0x02004CB4,
        },

        layout     = {
            partyMonSize    = 104,
            boxMonSize      = 84,
            encryptedOffset = 0x24,
            boxCount        = 14,
            boxSlots        = 30,
            deadBoxStart    = 11,
            deadBoxEnd      = 13,
            hasEVs          = false,
        }
    },

    -- ── EXEMPLE : Pour ajouter un futur patch v1.2.5 ─────────────────────────
    -- Décommentez et renseignez simplement le CRC et les nouvelles adresses :
    --[[
    {
        name       = "Pokemon Null v1.2.5",
        version    = "null-1.2.5",
        like       = "emerald-expansion",
        generation = 3,
        code       = "AGB-BPEE",
        title      = "POKEMON EMER",
        crc        = 0x12345678, -- Remplacer par le CRC affiché sur /vs/debug
        addresses  = {
            partyCount    = 0x0200xxxx,
            party         = 0x0200xxxx,
            storage       = 0x0200xxxx,
            speciesInfo   = 0x083Exxxx,
            battlersCount = 0x0200xxxx,
            battleOutcome = 0x0200xxxx,
            trainerA      = 0x0201xxxx,
            trainerB      = 0x0201xxxx,
            battleFlags   = 0x0200xxxx,
        }
    },
    --]]
}

-- ── Register all profiles into the engine ─────────────────────────────────────
function registerGbaProfiles()
    for _, profile in ipairs(GBA_EXPANSION_PROFILES) do
        local reader = createExpansionReader(profile)

        -- Register with both raw code and stripped code (e.g. "AGB-BPEE" and "BPEE")
        addGame(versionId(PLATFORM_GBA, profile.code, profile.title, profile.crc), reader)

        local shortCode = profile.code:match("-(.*)")
        if shortCode then
            addGame(versionId(PLATFORM_GBA, shortCode, profile.title, profile.crc), reader)
        end

        -- Also register aliases if title is "POKEMON NULL"
        if profile.title == "POKEMON NULL" then
            addGame(versionId(PLATFORM_GBA, profile.code, "POKEMON_NULL", profile.crc), reader)
            addGame(versionId(PLATFORM_GBA, profile.code, "POKEMONNULL", profile.crc), reader)
            if shortCode then
                addGame(versionId(PLATFORM_GBA, shortCode, "POKEMON_NULL", profile.crc), reader)
                addGame(versionId(PLATFORM_GBA, shortCode, "POKEMONNULL", profile.crc), reader)
            end
        end
    end
end

-- Auto-register on file evaluation
registerGbaProfiles()
