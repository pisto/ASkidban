--[[

  Read hits from stdin, resolve AS with local lookup, populate database.

]]--

local geoipf = assert(io.open(geoipfn))
print("Parsing " .. geoipfn)
local geoipdb = require"kblibs.ASNum"(geoipf)
geoipf:close()
collectgarbage()

local ip = require"kblibs.ip"

print("Parsing hits")
for l in io.lines() do
  local AS = tonumber(l:match("AS(%d+)"))
  if not AS then
    local _ip = ip.ip(l)
    if not _ip then print("Bad format " .. l) goto next
    else
      AS = geoipdb(_ip)
      if not AS then print("Cannot find AS for " .. tostring(_ip)) end
    end
  end
  if not db[AS] then db:settag(AS, "dunno") print(AS) end
  :: next ::
end

print("Done.")
return commit and os.execute("git reset HEAD . && git add db/ && git commit -m 'New hits.'")
