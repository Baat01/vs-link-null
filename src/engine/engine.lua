local m = Malachite

PLATFORM_GBA = 0
PLATFORM_GB = 1

local gameLookup = {}

function versionId(platform, code, title, crc)
	return {
		platform = platform,
		code = code,
		title = title,
		crc = crc
	}
end

function addGame(id, game)
	local lookup = gameLookup
	if lookup[id.platform] == nil then
		lookup[id.platform] = {}
	end
	lookup = lookup[id.platform]
	if lookup[id.code] == nil then
		lookup[id.code] = {}
	end
	lookup = lookup[id.code]
	if lookup[id.title] == nil then
		lookup[id.title] = {}
	end
	lookup = lookup[id.title]
	table.insert(lookup, {
		id = id,
		game = game
	})
end

local function lookupGame(id)
	-- Support both raw code ("AGB-BPEE") and short code ("BPEE")
	local codesToTry = { id.code }
	local shortCode = id.code:match("-(.*)")
	if shortCode then
		table.insert(codesToTry, shortCode)
	end

	for _, code in ipairs(codesToTry) do
		if gameLookup[id.platform] ~= nil and gameLookup[id.platform][code] ~= nil and gameLookup[id.platform][code][id.title] ~= nil then
			local games = gameLookup[id.platform][code][id.title]
			-- Pass 1: look for exact CRC match
			for i, game in ipairs(games) do
				if game.id.crc ~= nil and game.id.crc == id.crc then
					return {
						game = game.game,
						exact = true
					}
				end
			end
			-- Pass 2: look for wildcard CRC match
			for i, game in ipairs(games) do
				if game.id.crc == nil then
					return {
						game = game.game,
						exact = false
					}
				end
			end
			return {
				game = games[1].game,
				exact = false
			}
		end
	end
	return nil
end

function getCurrentGame()
	local platform = emu:platform()
	local crcString = emu:checksum(C.CHECKSUM.CRC32)
	local crc = (string.byte(crcString, 1) << 24) | (string.byte(crcString, 2) << 16) | (string.byte(crcString, 3) << 8) | (string.byte(crcString, 4))
	local code = emu:getGameCode()
	local rawTitle = emu:getGameTitle()
	-- GBA ROM headers pad the 12-byte title with spaces or \0
	local title = rawTitle:gsub("%z", ""):match("^%s*(.-)%s*$") or rawTitle
	local version = versionId(platform, code, title, crc)
	local game, match = lookupGame(version)
	if game == nil then
		m:log(string.format("Unknown version ID: code='%s', title='%s', crc=0x%08X", code, title, crc))
	end
	return game
end

-- Gen 2

-- Pokemon Crystal
local CRYSTAL_PARTY_ADDR = 0xdcd7
local CRYSTAL_PARTY_END_ADDR = 0xde83
addGame(
	versionId(PLATFORM_GB, "CGB-BYTE", "PM_CRYSTAL", 0x373BAD72),
	{
		getInfo = function()
			return {
				version = "crystal",
				like = "crystal",
				generation = 2
			}
		end,
		getParty = function()
			return gen2Party(CRYSTAL_PARTY_ADDR, CRYSTAL_PARTY_END_ADDR)
		end
	}
)


-- Gen 3

-- Pokemon Emerald (vanilla)
local EMERALD_PARTY_LENGTH = 0x20244e9
local EMERALD_PARTY = 0x20244ec
local emeraldProfile = {
	getInfo = function()
		return {
			version = "emerald",
			like = "emerald",
			generation = 3
		}
	end,
	getParty = function() return gen3Party(EMERALD_PARTY_LENGTH, EMERALD_PARTY) end
}
addGame(versionId(PLATFORM_GBA, "BPEE", "POKEMON EMER", 0x1f1c08fb), emeraldProfile)
addGame(versionId(PLATFORM_GBA, "AGB-BPEE", "POKEMON EMER", 0x1f1c08fb), emeraldProfile)

-- GBA Expansion profiles (Pokémon Null and future patches)
-- are declared in profiles.lua and registered via registerGbaProfiles().
if registerGbaProfiles then
	registerGbaProfiles()
end