Malachite:init()
local m = Malachite

VERSION = "0.1.0"

wd = nil
if not buf then
	buf = console:createBuffer("Vs. Link")
	if buf and buf.setSize then
		buf:setSize(600, 450)
	end
end

function start()
	if buf and buf.clear then
		buf:clear()
	end
	m:log("=== Vs. Link v" .. VERSION .. " ===")
	wd = debug.getinfo(start).source:match("@?(.*[/\\])") or ""
	dofile(wd .. "engine/engine.lua")
	dofile(wd .. "engine/tables.lua")
	dofile(wd .. "engine/gen2.lua")
	dofile(wd .. "engine/gen3.lua")
	dofile(wd .. "engine/null_tables.lua")  -- Null data tables (aliases Baat globals)
	dofile(wd .. "engine/gen3null.lua")      -- Generic expansion memory reader (createExpansionReader)
	dofile(wd .. "engine/profiles.lua")      -- Declarative game & patch profiles
	dofile(wd .. "cache.lua")               -- Lazy box cache (must come before endpoints)
	dofile(wd .. "endpoints.lua")

	local server = m.Http.Server:new(nil, 31123, function(req, res)
		callEndpoint(req, res)
	end)
	server:start()

	-- Register frame-level cache probe: checks gPlayerPartyCount each frame.
	-- Invalidates the box cache when the count changes (e.g. after PC interactions).
	-- This adds negligible overhead (1 byte read per frame).
	callbacks:add("frame", function()
		if Cache then Cache:frameProbe() end
	end)

	m:log("Vs. Link ready on port 31123")
	m:log("Endpoints: /vs/info /vs/game /vs/party /vs/boxes /vs/battle /vs/all /update")
end

start()

