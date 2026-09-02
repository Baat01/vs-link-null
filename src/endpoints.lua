local m = Malachite
local endpoints = {}

function callEndpoint(req, res)
	local method = req.method
	local path = req.path

	if path:sub(-1) == "/" then
		path = path:sub(1, #path - 1)
	end
	if endpoints[method] == nil or endpoints[method][path] == nil then
		res.code = 404
		res.content = "Unknown endpoint " .. method .. " " .. path
		return
	end
	local game = getCurrentGame()
	local json, err = req:getJson()
	local data = {
		game = game,
		json = json,
		req = req,
		res = res
	}
	endpoints[method][path](data)
end

function addEndpoint(method, path, callback)
	if endpoints[method] == nil then
		endpoints[method] = {}
	end
	endpoints[method][path] = callback
end

-- ── Helper: build the combined /vs/all payload ────────────────────────────────

local function makeAllPayload(game)
	if game == nil then return nil end
	local g = game.game
	return {
		game   = g.getInfo   and g.getInfo()   or nil,
		party  = g.getParty  and Cache:getParty(g.getParty)  or nil,
		boxes  = g.getBoxes  and Cache:getBoxes(g.getBoxes)  or nil,
		battle = g.getBattle and g.getBattle() or nil,
	}
end

-- ── Generic Info ──────────────────────────────────────────────────────────────

addEndpoint("GET", "/vs/info", function(data)
	data.res.content = {
		name    = "Vs. Link",
		version = VERSION
	}
end)

-- ── Game Info ─────────────────────────────────────────────────────────────────

addEndpoint("GET", "/vs/game", function(data)
	if data.game == nil then
		data.res.code = 503
		data.res.content = "No supported game detected"
		return
	end
	data.res.content = data.game.game.getInfo()
end)

addEndpoint("GET", "/vs/badges", function(data)
	data.res.content = getBadges()
end)

-- ── Party ─────────────────────────────────────────────────────────────────────

addEndpoint("GET", "/vs/party", function(data)
	if data.game == nil then
		data.res.code = 503
		data.res.content = "No supported game detected"
		return
	end
	local g = data.game.game
	if g.getParty == nil then
		data.res.code = 404
		data.res.content = "Party not supported for this game"
		return
	end
	data.res.content = Cache:getParty(g.getParty)
end)

-- ── PC Boxes ──────────────────────────────────────────────────────────────────
-- Returns all occupied box slots across 14 boxes.
-- Each entry includes { box, slot, isDeadBox, speciesId, speciesName, ... }.
-- The cache is invalidated when gPlayerPartyCount changes (detected by Cache:frameProbe).

addEndpoint("GET", "/vs/boxes", function(data)
	if data.game == nil then
		data.res.code = 503
		data.res.content = "No supported game detected"
		return
	end
	local g = data.game.game
	if g.getBoxes == nil then
		data.res.code = 404
		data.res.content = "PC boxes not supported for this game"
		return
	end
	-- Invalidate cache on every explicit /vs/boxes request to ensure fresh data
	Cache:invalidate()
	data.res.content = Cache:getBoxes(g.getBoxes)
end)

-- ── Battle State ──────────────────────────────────────────────────────────────

addEndpoint("GET", "/vs/battle", function(data)
	if data.game == nil then
		data.res.code = 503
		data.res.content = "No supported game detected"
		return
	end
	local g = data.game.game
	if g.getBattle == nil then
		data.res.code = 404
		data.res.content = "Battle state not supported for this game"
		return
	end
	data.res.content = g.getBattle()
end)

-- ── Combined Snapshot — /vs/all ───────────────────────────────────────────────
-- Returns party + boxes + battle state in one payload.
-- Preferred endpoint for external calculators that want a single call.

addEndpoint("GET", "/vs/all", function(data)
	local payload = makeAllPayload(data.game)
	if payload == nil then
		data.res.code = 503
		data.res.content = "No supported game detected"
		return
	end
	data.res.content = payload
end)

-- ── /update — Legacy alias for /vs/all ───────────────────────────────────────
-- Provided for backward-compatibility with external calculators.

addEndpoint("GET", "/update", function(data)
	local payload = makeAllPayload(data.game)
	if payload == nil then
		data.res.code = 503
		data.res.content = "No supported game detected"
		return
	end
	data.res.content = payload
end)

-- ── /vs/debug — ROM identity diagnostic ──────────────────────────────────────
-- Exposes the raw values mGBA reports for the loaded ROM.
-- Use this to diagnose "No supported game detected" errors.

addEndpoint("GET", "/vs/debug", function(data)
	local platform = emu:platform()
	local crcString = emu:checksum(C.CHECKSUM.CRC32)
	local crc = (string.byte(crcString, 1) << 24) | (string.byte(crcString, 2) << 16) | (string.byte(crcString, 3) << 8) | (string.byte(crcString, 4))
	local rawTitle = emu:getGameTitle()
	local trimmedTitle = rawTitle:gsub("%z", ""):match("^%s*(.-)%s*$") or rawTitle
	local code = emu:getGameCode()
	data.res.content = {
		detected           = (data.game ~= nil),
		detectedVersion    = data.game and data.game.game.getInfo() or nil,
		platform           = platform,
		gameCode           = code,
		rawTitle           = rawTitle,
		trimmedTitle       = trimmedTitle,
		crc                = string.format("0x%08X", crc),
		nullMonsCount      = NULL_MONS and #NULL_MONS or 0,
		nullMovesCount     = NULL_MOVES and #NULL_MOVES or 0,
		charmapLoaded      = (type(charmap) == "table"),
		vsLinkVersion      = VERSION,
	}
end)


