local out = os.getenv("ASSET_AUDIT")
if not out or out == "" then return end

local fh = io.open(out, "a")
if not fh then return end
local seen = {}

local function rec(tag, p)
    if type(p) ~= "string" then return end
    local k = tag .. " " .. p
    if seen[k] then return end
    seen[k] = true
    fh:write(k, "\n")
    fh:flush()
end

local function wrap(mod, name, tag, onlyHit)
    local orig = mod and mod[name]
    if not orig then return end
    mod[name] = function(a, ...)
        local r = { orig(a, ...) }
        if not onlyHit or r[1] then rec(tag, a) end
        return unpack(r)
    end
end

if love.graphics then wrap(love.graphics, "newImage", "IMG") end
if love.image then wrap(love.image, "newImageData", "IMG") end
wrap(love.filesystem, "getInfo", "INFO", true)
wrap(love.filesystem, "getDirectoryItems", "DIR")
wrap(love.filesystem, "newFileData", "FILE")
wrap(love.filesystem, "read", "FILE", true)
