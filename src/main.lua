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

-- =============================================================================
-- loadUserScripts(scriptsDir)
--
-- Discovers and executes every *.lua file found in `scriptsDir` BEFORE any
-- engine file runs, so user-defined globals (mons, move, charmap, storageLoc,
-- readPartyMon, …) are populated when null_tables.lua, gen3null.lua, and
-- endpoints.lua are loaded.
--
-- Load order guarantees:
--   1. All filenames are sorted alphabetically.
--   2. Any file whose name contains "tracking" (case-insensitive) is hoisted
--      to the front so foundational memory tables are ready for secondary
--      scripts (frag counters, PP trackers, etc.).
--   3. Each dofile() is wrapped in pcall — a broken script is logged via
--      m:error() but never aborts the Vs. Link boot sequence.
--
-- Discovery strategy:
--   Tier 1 — io.popen:
--     Windows : dir /b /on "<path>\*.lua" 2>nul
--     Unix    : ls -1 "<path>" 2>/dev/null  (filtered to .lua in Lua)
--   Tier 2 — hardcoded manifest fallback (when io.popen is sandboxed):
--     Attempts to open each well-known filename; loads those that exist.
-- =============================================================================
local function loadUserScripts(scriptsDir)
	m:log("[scripts] Scanning: " .. scriptsDir)

	-- ── Step 1: collect filenames ─────────────────────────────────────────────
	local files = {}
	local scanOk = false

	if io.popen then
		local cmd
		if package.config and package.config:sub(1, 1) == "\\" then
			-- Windows: /b = bare names, /on = sort alphabetically
			cmd = 'dir /b /on "' .. scriptsDir:gsub("/", "\\") .. '*.lua" 2>nul'
		else
			-- Unix / macOS
			cmd = 'ls -1 "' .. scriptsDir .. '" 2>/dev/null'
		end

		local ok, p = pcall(io.popen, cmd)
		if ok and p then
			for line in p:lines() do
				local name = line:match("^%s*(.-)%s*$") -- trim surrounding whitespace
				if name and name ~= "" and name:match("%.lua$") then
					files[#files + 1] = name
				end
			end
			p:close()
			scanOk = true
		end
	end

	-- ── Step 2: manifest fallback (io.popen unavailable or returned nothing) ──
	if not scanOk or #files == 0 then
		m:log("[scripts] io.popen unavailable or returned no results — trying manifest fallback.")
		-- List every known script here. Only files that actually exist are loaded.
		local manifest = {
			"Baat Tracking Script V1.2.4.lua",
			"Baat frag counter assistant.lua",
		}
		for _, name in ipairs(manifest) do
			local f = io.open(scriptsDir .. name, "r")
			if f then
				f:close()
				files[#files + 1] = name
			end
		end
	end

	-- ── Step 3: sort alphabetically, hoist *tracking* files to front ──────────
	table.sort(files)
	local priority, rest = {}, {}
	for _, name in ipairs(files) do
		if name:lower():find("tracking") then
			priority[#priority + 1] = name
		else
			rest[#rest + 1] = name
		end
	end
	-- Final order: tracking scripts (sorted) → all others (sorted)
	local ordered = {}
	for _, v in ipairs(priority) do ordered[#ordered + 1] = v end
	for _, v in ipairs(rest)     do ordered[#ordered + 1] = v end

	-- ── Step 4: execute with per-script error isolation ───────────────────────
	if #ordered == 0 then
		m:log("[scripts] No .lua files found in scripts/ — continuing without user scripts.")
		return
	end

	m:log("[scripts] Load order (" .. #ordered .. " file(s)):")
	for i, name in ipairs(ordered) do
		m:log("[scripts]   " .. i .. ". " .. name)
	end

	for i, name in ipairs(ordered) do
		local path = scriptsDir .. name
		m:log("[scripts] Loading [" .. i .. "/" .. #ordered .. "]: " .. name)
		local ok, err = pcall(dofile, path)
		if ok then
			m:log("[scripts] OK: " .. name)
		else
			m:error("[scripts] FAILED: " .. name .. "\n  " .. tostring(err))
			-- Continue loading remaining scripts — do not crash the bridge.
		end
	end
end

function start()
	if buf and buf.clear then
		buf:clear()
	end
	m:log("=== Vs. Link v" .. VERSION .. " ===")
	wd = debug.getinfo(start).source:match("@?(.*[/\\])") or ""

	-- ── [1] User scripts FIRST — populates mons/move/charmap/etc. ─────────────
	-- Engine files (especially null_tables.lua) alias these globals, so they
	-- must exist before any engine dofile runs.
	loadUserScripts(wd .. "../scripts/")

	-- ── [2] Core engine files ─────────────────────────────────────────────────
	dofile(wd .. "engine/engine.lua")
	dofile(wd .. "engine/tables.lua")
	dofile(wd .. "engine/gen2.lua")
	dofile(wd .. "engine/gen3.lua")
	dofile(wd .. "engine/null_tables.lua")  -- aliases mons/move/charmap from user scripts
	dofile(wd .. "engine/gen3null.lua")      -- uses NULL_MONS/NULL_MOVES from null_tables
	dofile(wd .. "engine/profiles.lua")      -- declarative game & patch profiles
	dofile(wd .. "cache.lua")               -- lazy box cache (must come before endpoints)
	dofile(wd .. "endpoints.lua")

	-- ── [3] HTTP server ───────────────────────────────────────────────────────
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
