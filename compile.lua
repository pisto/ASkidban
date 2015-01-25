--[[

  Compile simple files with a list of AS numbers and associated ranges using data from bgp.he.net, using https://www.enjen.net/asn-blocklist/ as API.

]]--

local fp, ip, json, curl = require"kblibs.fp", require"kblibs.ip", require"json", require"cURL"
local map = fp.map

local function fetchranges(AS, force)
  local data = db[AS][AS]
  if data.ranges and not force then return data.ranges end
  print("Ranges AS" .. AS)
  local j
  local function gather(s) j = j and j .. s or s return true end
  curl.easy()
    :setopt_url("https://www.enjen.net/asn-blocklist/index.php?asn=" .. AS .. "&type=json_split&api=1")
    :setopt_writefunction(gather)
    :perform()
    :close()
  data.ranges = map.il(function(_, ips)
    return tostring(assert(ip.ip(ips), "API returned bad range specification: " .. ips))
  end, json.decode(j).ipv4s)
  db:setdata(AS, data)
  return data.ranges
end

local ASlist, ranges = "", ip.ipset()
for AS in pairs(db.groups.kids) do
  for _, ips in ipairs(fetchranges(AS, force)) do
    local _ip = ip.ip(ips)
    local complement = ip.ip(bit32.bxor(_ip.ip, 2 ^ (32 - _ip.mask)), _ip.mask)
    if ranges:matcherof(complement) == complement then
      ranges:remove(complement)
      _ip = ip.ip(_ip.ip, _ip.mask - 1)
    end
    local ok, overlap = ranges:put(_ip)
    if not ok and not overlap.matcher then
      for shadowed in pairs(overlap) do ranges:remove(shadowed) end
      ranges:put(_ip)
    end
  end
end

local ASlistf, err = io.open("compiled/AS", "w")
assert(ASlistf, err)
ASlistf:write(ASlist)
ASlistf:close()

local iplistf, err = io.open("compiled/ipv4", "w")
assert(iplistf, err)
for range in ranges:enum() do iplistf:write(tostring(range) .. '\n') end
iplistf:close()

local ipclistf, err = io.open("compiled/ipv4_compact", "w")
assert(ipclistf, err)
for range in ranges:enum() do ipclistf:write(range.ip * 0x40 + range.mask .. '\n') end
ipclistf:close()

print("Done.")
return commit and os.execute"git reset HEAD . && git add db/kids compiled/ && git commit -m 'Recompiled.'"
