--[[

  Compile simple files with a list of AS numbers and associated ranges using data from bgp.he.net, using https://www.enjen.net/asn-blocklist/ as API.

]]--

local fp, ip, json, curl = require"kblibs.fp", require"kblibs.ip", require"json", require"cURL"
local map = fp.map

local ASlist, ranges = "", ip.ipset()
for AS in pairs(db.groups.kids) do
  print("AS" .. AS)
  ASlist = ASlist .. AS .. '\n'
  local j
  local function gather(s) j = j and j .. s or s return true end
  curl.easy()
    :setopt_url("https://www.enjen.net/asn-blocklist/index.php?asn=" .. AS .. "&type=json_split&api=1")
    :setopt_writefunction(gather)
    :perform()
    :close()
  for _, range in ipairs(json.decode(j).ipv4s) do
    local _ip = ip.ip(range)
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

print("Done.")
return commit and os.execute"git reset HEAD . && git add compiled/ && git commit -m 'Recompiled.'"
