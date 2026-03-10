-- ============================================================
--   REYVAN STORE v3.0 - LOADER
--   Paste script ini ke executor kamu (PC / Android / Xeno)
--
--   CARA PAKAI:
--   1. Upload ReyvanStore_v3.lua ke GitHub kamu
--   2. Copy URL raw-nya (contoh di bawah)
--   3. Paste loader ini ke executor, ganti URL_RAW_GITHUB
--
--   Xeno Android: paste langsung ke tab Script executor
-- ============================================================

-- ⬇️ GANTI URL INI dengan URL raw GitHub milikmu
local SCRIPT_URL = "https://raw.githubusercontent.com/USERNAME/REPO/main/ReyvanStore_v3.lua"

-- ============================================================
-- EXECUTOR COMPAT: cek apakah ada loadstring / syn.request / request
-- ============================================================
local function fetchAndRun(url)
    -- Coba berbagai metode HTTP yang ada di berbagai executor
    local success, result

    -- Method 1: game:HttpGet (Synapse X, KRNL, Fluxus, Delta, Xeno)
    if game.HttpGet then
        success, result = pcall(function()
            return game:HttpGet(url, true)
        end)
        if success and result and #result > 10 then
            local fn, err = loadstring(result)
            if fn then return fn() else warn("[ReyvanStore] Loadstring error: "..tostring(err)) end
        end
    end

    -- Method 2: syn.request (Synapse X)
    if not success and syn and syn.request then
        success, result = pcall(function()
            return syn.request({Url=url, Method="GET"}).Body
        end)
        if success and result and #result > 10 then
            local fn, err = loadstring(result)
            if fn then return fn() else warn("[ReyvanStore] Loadstring error: "..tostring(err)) end
        end
    end

    -- Method 3: request (KRNL, Arceus X, Xeno Android)
    if not success and request then
        success, result = pcall(function()
            return request({Url=url, Method="GET"}).Body
        end)
        if success and result and #result > 10 then
            local fn, err = loadstring(result)
            if fn then return fn() else warn("[ReyvanStore] Loadstring error: "..tostring(err)) end
        end
    end

    -- Method 4: http.request (beberapa executor lain)
    if not success and http and http.request then
        success, result = pcall(function()
            return http.request({Url=url, Method="GET"}).Body
        end)
        if success and result and #result > 10 then
            local fn, err = loadstring(result)
            if fn then return fn() else warn("[ReyvanStore] Loadstring error: "..tostring(err)) end
        end
    end

    -- Method 5: HttpService (fallback, biasanya diblokir tapi dicoba)
    if not success then
        success, result = pcall(function()
            return game:GetService("HttpService"):GetAsync(url)
        end)
        if success and result and #result > 10 then
            local fn, err = loadstring(result)
            if fn then return fn() else warn("[ReyvanStore] Loadstring error: "..tostring(err)) end
        end
    end

    if not success then
        warn("[ReyvanStore] ❌ Gagal fetch script. Cek URL atau koneksi internet!")
        warn("[ReyvanStore] Error: "..tostring(result))
    end
end

-- ============================================================
-- RUN
-- ============================================================
print("[ReyvanStore] 🔄 Loading script dari GitHub...")
fetchAndRun(SCRIPT_URL)
