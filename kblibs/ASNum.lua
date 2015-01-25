--[[

  GeoIPASNum structure from CSV data.

]]--

local fp, L, ip = require"kblibs.fp", require"kblibs.lambda", require"kblibs.ip"
local map = fp.map

--balanced binary search tree
local function populate(records, s, e)
  if e == s then return { records[s][2] + 1, records[s][3] } end --a result: { [1] = upper_exclusive, [2] = ASN }
  local midpoint = math.floor((s + e) / 2)
  return { records[midpoint + 1][1], populate(records, s, midpoint), populate(records, midpoint + 1, e) } --a choice: { [1] = lower_inclusive, [2] = nextchoice_less, [2] = nextchoice_greaterequal }
end

local findnode
findnode = function(base, s, curchoice)
  curchoice = curchoice or base
  if #curchoice == 2 then return curchoice end
  return findnode(base, s, curchoice[1 + (s >= curchoice[1] and 2 or 1)])
end

local meta = { __call = function(base, _ip)
  _ip = _ip.ip and _ip or ip.ip(_ip)
  local node = findnode(base, _ip.ip)
  return node[1] > _ip.ip and node[2]
end }

return function(geoipf)
  local records = { { 0, -1, false } }
  for l in geoipf:lines() do
    local r = map.lv(tonumber, l:match'^(%d+),(%d+),"AS(%d+) ')
    if r[1] then table.insert(records, r) end
  end
  table.sort(records, L"_1[1] < _2[1]")
  for i = 1, #records - 1 do assert(records[i][2] < records[i + 1][1], "Overlapping ranges in ASNum database") end

  return setmetatable(populate(records, 1, #records), meta)
end
