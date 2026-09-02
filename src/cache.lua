-- =============================================================================
-- cache.lua — Lazy read-cache for expensive memory operations
-- Part of Vs. Link | src/
-- =============================================================================
-- The PC storage scan (420 slots × 84 bytes each) is expensive to run on every
-- HTTP request. This module caches the result and re-reads only when:
--   1. An HTTP client explicitly hits /vs/boxes (always reads fresh on demand)
--   2. The cache is marked dirty via Cache:invalidate()
--   3. The game restarts (callbacks:add("start", ...) calls invalidate)
--
-- Party reads are always live (max 6 × 104 bytes — negligible cost).
-- =============================================================================

Cache = {}
Cache._boxes = nil
Cache._dirty = true
Cache._lastPartyCount = -1

-- Mark the box cache as stale. Called on game start or storage interaction.
function Cache:invalidate()
    self._dirty = true
    self._boxes = nil
end

-- Return the cached box list, re-reading from RAM only if dirty.
-- Pass the game's getBoxes function as `getBoxesFn`.
function Cache:getBoxes(getBoxesFn)
    if self._dirty or self._boxes == nil then
        if type(getBoxesFn) == "function" then
            self._boxes = getBoxesFn()
            self._dirty = false
        else
            return {}
        end
    end
    return self._boxes
end

-- Party is always read live — cheap and time-critical.
function Cache:getParty(getPartyFn)
    if type(getPartyFn) == "function" then
        return getPartyFn()
    end
    return {}
end

-- Lightweight frame-level probe: if party count changed, assume storage may
-- have changed too and invalidate the box cache. Hooked via callbacks:add("frame")
-- in main.lua.  Does NOT read all 420 slots — only reads 1 byte.
function Cache:frameProbe()
    local count = emu:read8(0x0200536D)  -- gPlayerPartyCount
    if count ~= self._lastPartyCount then
        self._lastPartyCount = count
        self:invalidate()
    end
end

-- Register the "start" callback to flush the cache on game/script reload
callbacks:add("start", function()
    Cache:invalidate()
end)
