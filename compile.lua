--[[

  Compile simple files with a list of AS numbers and associated ranges using data from bgp.he.net, using https://www.enjen.net/asn-blocklist/ as API.

]]--

local L, fp, ip, json, curl = require"kblibs.lambda", require"kblibs.fp", require"kblibs.ip", require"dkjson", require"cURL"
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

local function checkexclusion(set, ip, AS, isexclusion)
  local matcher, matcherAS = set:matcherof(ip)
  if matcher then
    if isexclusion then error(("AS%d:%s matches exclusion AS%d:%s"):format(matcherAS, matcher, AS, ip))
    else error(("AS%d:%s matches exclusion AS%d:%s"):format(AS, ip, matcherAS, matcher)) end
  end
  local matched = set:matchesof(ip)
  if next(matched) then
    matched = map.lp(L"('AS%d:%s'):format(_2, _1)", matched)
    if isexclusion then error(("%s are matched by exclusion AS%d:%s"):format(table.concat(matched, ", "), AS, ip))
    else error(("AS%d:%s matches exclusions %s"):format(AS, ip, matched)) end
  end
end

local ASlist, ranges, exclusions = "", ip.ipset(8), ip.ipset(8)
for _, AS in ipairs(table.sort(map.lp(L"_", db.groups.kids))) do
  ASlist = ASlist .. AS .. '\n'
  local ASexclusions = getexclusions(AS)
  for _, ips in ipairs(fetchranges(AS, force)) do
    local _ip = ip.ip(ips)
    for ASexclusion in pairs(ASexclusions) do if ASexclusion == _ip then
      checkexclusion(ranges, ASexclusion, AS, true)
      local ok, shadows = exclusions:put(ASexclusion, AS)
      if not ok and not shadows.matcher then
        for shadow in pairs(shadows) do exclusions:remove(shadow) end
        exclusions:put(ip, AS)
      end
      ASexclusions[ASexclusion] = nil
      goto nextrange
    end end
    checkexclusion(exclusions, _ip, AS, false)
    while true do
      local complement = ip.ip(bit32.bxor(_ip.ip, 2 ^ (32 - _ip.mask)) % 2^32, _ip.mask)
      if ranges:matcherof(complement) == complement then
        ranges:remove(complement)
        _ip = ip.ip(_ip.ip, _ip.mask - 1)
        ranges:put(_ip, AS)
      else break end
    end
    local ok, overlap = ranges:put(_ip, AS)
    if not ok and not overlap.matcher then
      for shadowed in pairs(overlap) do ranges:remove(shadowed) end
      ranges:put(_ip, AS)
    end
    :: nextrange ::
  end
  if next(ASexclusions) then error(("AS%d does not announce anymore excluded ranges %s"):format(AS, table.concat(map.lp(tostring, ASexclusions), ", "))) end
end

local ASlistf = assert(io.open("compiled/AS", "w"))
assert(ASlistf:write(ASlist))
ASlistf:close()

local iplistf, ipclistf = assert(io.open("compiled/ipv4", "w")), assert(io.open("compiled/ipv4_compact", "w"))
for _, range in ipairs(table.sort(map.lf(L"_", ranges:enum()), L"_1.ip < _2.ip")) do
  iplistf:write(tostring(range) .. '\n')
  ipclistf:write(range.ip * 0x40 + range.mask .. '\n')
end
iplistf:close() ipclistf:close()

print("Done.")
return commit and os.execute"git reset HEAD . && git add db/kids compiled/ && git commit -m 'Recompiled.'"
