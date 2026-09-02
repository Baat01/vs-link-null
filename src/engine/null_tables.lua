-- =============================================================================
-- null_tables.lua — Pokémon Null data tables for Vs. Link
-- Part of Vs. Link | src/engine/
-- =============================================================================
-- This file exposes module-level globals (NULL_MONS, NULL_MOVES, NULL_NATURES,
-- NULL_ITEMS) used by gen3null.lua for species/move/item/nature name resolution.
--
-- STRATEGY: The Baat Tracking Script V1.2.x already defines the authoritative
-- tables (mons[], move[], nature[], item[], charmap[]) as Lua globals when it
-- runs alongside Vs. Link. This file checks for those globals and aliases them,
-- so there is no duplication of the ~3 000-entry tables.
--
-- If Vs. Link runs standalone (without the Baat script), this file provides
-- the nature table inline (only 25 entries) and leaves species/move/item as nil,
-- which gen3null.lua handles gracefully by outputting raw numeric IDs.
-- =============================================================================

-- ── Nature Table (25 entries, pokeemerald order) ──────────────────────────────
-- Index 1–25 maps to hiddenNature / (personality % 25).

NULL_NATURES = {
    "Hardy",   "Lonely",  "Brave",   "Adamant", "Naughty",
    "Bold",    "Docile",  "Relaxed", "Impish",  "Lax",
    "Timid",   "Hasty",   "Serious", "Jolly",   "Naive",
    "Modest",  "Mild",    "Quiet",   "Bashful", "Rash",
    "Calm",    "Gentle",  "Sassy",   "Careful", "Quirky",
}

-- ── Alias Baat Script Globals (when available) ────────────────────────────────
-- The Baat Tracking Script defines: mons[], move[], item[], charmap[], nature[]
-- as plain globals. We alias them to our namespaced names.

-- Species table: mons[speciesId] = "Name" (1-indexed, Showdown capitalization)
if type(mons) == "table" then
    NULL_MONS = mons
else
    -- Standalone fallback: empty table — gen3null.lua will output speciesId numerically
    NULL_MONS = {}
    Malachite:log("[null_tables] WARNING: mons[] not found — running without Baat Tracking Script. Species names will be numeric IDs.")
end

-- Move table: move[moveId + 1] = "Name" (1-indexed, move ID 0 = "")
if type(move) == "table" then
    NULL_MOVES = move
else
    NULL_MOVES = {}
    Malachite:log("[null_tables] WARNING: move[] not found — move names will be numeric IDs.")
end

-- Item table: item[itemId] = "Name" (1-indexed)
if type(item) == "table" then
    NULL_ITEMS = item
else
    NULL_ITEMS = {}
    Malachite:log("[null_tables] WARNING: item[] not found — item names will be numeric IDs.")
end

-- Ability table (used by getAbility() in Baat script, exposed here for reference)
if type(abilities) == "table" then
    NULL_ABILITIES = abilities
else
    NULL_ABILITIES = {}
end

-- ── GBA Character Map Fallback ───────────────────────────────────────────────
-- Standard pokeemerald-expansion / GBA Pokemon character map (0x00 to 0xFE).
-- Ensures string decoding always works even if Baat Tracking Script was not loaded first.
if type(charmap) ~= "table" then
    charmap = { [0]=
        " ", "À", "Á", "Â", "Ç", "È", "É", "Ê", "Ë", "Ì", "こ", "Î", "Ï", "Ò", "Ó", "Ô",
        "Œ", "Ù", "Ú", "Û", "Ñ", "ß", "à", "á", "ね", "ç", "è", "é", "ê", "ë", "ì", "ま",
        "î", "ï", "ò", "ó", "ô", "œ", "ù", "ú", "û", "ñ", "º", "ª", " ", "&", "+", "あ",
        "ぃ", "ぅ", "ぇ", "ぉ", "v", "=", "ょ", "が", "ぎ", "ぐ", "げ", "ご", "ざ", "じ", "ず", "ぜ",
        "ぞ", "だ", "ぢ", "づ", "で", "ど", "ば", "び", "ぶ", "べ", "ぼ", "ぱ", "ぴ", "ぷ", "ぺ", "ぽ",
        "っ", "¿", "¡", "P\u{200d}k", "M\u{200d}n", "P\u{200d}o", "K\u{200d}é", " ", " ", " ", "Í", "%", "(", ")", "セ", "ソ",
        "タ", "チ", "ツ", "テ", "ト", "ナ", "ニ", "ヌ", "â", "ノ", "ハ", "ヒ", "フ", "ヘ", "ホ", "í",
        "ミ", "ム", "メ", "モ", "ヤ", "ユ", "ヨ", "ラ", "リ", "⬆", "⬇", "⬅", "➡", "ヲ", "ン", "ァ",
        "ィ", "ゥ", "ェ", "ォ", "ャ", "ュ", "ョ", "ガ", "ギ", "グ", "ゲ", "ゴ", "ザ", "ジ", "ズ", "ゼ",
        "ゾ", "ダ", "ヂ", "ヅ", "デ", "ド", "バ", "ビ", "ブ", "ベ", "ボ", "パ", "ピ", "プ", "ペ", "ポ",
        "ッ", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "!", "?", ".", "-", "・",
        "…", "“", "”", "‘", "’", "♂", "♀", "$", ",", "×", "/", "A", "B", "C", "D", "E",
        "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U",
        "V", "W", "X", "Y", "Z", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k",
        "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "▶",
        ":", "Ä", "Ö", "Ü", "ä", "ö", "ü", "⬆", "⬇", "⬅", " ", " ", " ", " ", " ", ""
    }
end

Malachite:log("[null_tables] Data tables initialized (mons=" ..
    (NULL_MONS ~= nil and #NULL_MONS or 0) .. " natures=" .. #NULL_NATURES ..
    " moves=" .. (NULL_MOVES ~= nil and #NULL_MOVES or 0) .. ")")
