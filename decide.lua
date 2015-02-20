--[[

  Interactively tag AS numbers.

]]--

local fp, L, ip = require"kblibs.fp", require"kblibs.lambda", require"kblibs.ip"
local map, pick = fp.map, fp.pick


local colors = map.mp(function(name, code) return name, function(str)
  return code .. tostring(str) .. "\27[0m"
end end, {
  red   = "\27[1;31m",
  green = "\27[1;32m",
  gray  = "\27[9;37m",
  blue  = "\27[1;34m",
  yellow  = "\27[1;33m",
  bold  = "\27[1;37m",
  lightgray = "\27[5;37m",
  cyan  = "\27[0;36m",
  pink  = "\27[1;35m",
  orange  = "\27[0;33m"
})

local whois_ignore = {
  "^[#%%]",
  "^[^ ]*abuse",
  "^[^ ]*tech",
  "^[^ ]*phone",
  "^[^ ]*mnt",
  "^[^ ]*hdl",
  "^[^ ]*source",
  "^[^ ]*country",
  "^[^ ]*updated",
  "^[^ ]*regdate",
  "^[^ ]*person",
  "^[^ ]*fax",
  "^[^ ]*address",
  "^[^ ]*handle",
  "^[^ ]*stateprov",
  "^[^ ]*postal",
  "^[^ ]*city",
  "^[^ ]*email",
  "^[^ ]*role",
  "^[^ ]*changed",
  "^[^ ]*created",
  "^[ \t]*$",
}

local whois_http = {
  "https?://(%l[%w%-%.]*%.%l%l+)",
  "@(%l[%w%-%.]*%.%l%l+)",  --email
  "%l[%w%-%.]*%.%l[%w%-%.]*%.%l%l+",  -- so.me.thing
}

local whois_http_ignore = {
  "arin%.net",
  "ripe%.net",
  "registro%.br",
  "apnic%.net",
  "cert%.br",
  "nic%.ad%.jp",
  "whois%.",
  "twnic%.net",
  "apjii%.or%.id",
  "idnic%.net",
  "vnnic%.net%.vn",
  "lacnic%.net",
  "p%.o%.box",
  "afrinic%.net",
  "iana%.org",
}

local maybe_kids = {
  "vpn",
  "hosting",
  "vps",
  "servers",
  "anonym",
}

local maybe_sirs = {
  "tele[ck]om",
  "dynamic i?p? ?pool",
  "broadband",
  "landline",
  "mobile",
  "dsl",
  "cable",
}

local function firstmatch(line, regexes)
  for _, regex in ipairs(regexes) do if line:match(regex) then return true end end
end

local function prettywhois(whois)
  print(colors.yellow("\tWhois:\n"))
  local colored, websites, inellipsis = "", {}, false
  for line in whois:lower():gmatch("[^\n]+") do
    map.tsi(websites, function(_, regex) return line:match(regex) end, whois_http)
    if line == "" or firstmatch(line, whois_ignore) or firstmatch(line, whois_http_ignore) then
      if not inellipsis then inellipsis, colored = true, colored .. colors.gray("[...]\n") end
    else inellipsis, colored = false, colored .. line .. '\n' end
  end
  for _, regex in ipairs(maybe_kids) do colored = colored:gsub(regex, colors.red) end
  for _, regex in ipairs(maybe_sirs) do colored = colored:gsub(regex, colors.green) end
  print(colored)
  websites = pick.p(function(match) return not firstmatch(match, whois_http_ignore) and not websites["www." .. match] end, websites)
  if next(websites) then print(colors.cyan(table.concat(map.lp(L"'http://'.._", websites), " "))) end
  print()
end

local typecolors = {
  ["Educational/Research"] = colors.green,
  ["Non-Profit"] = colors.green,
  ["Cable/DSL/ISP"] = colors.green,
  ["Content"] = colors.red,
  ["Enterprise"] = colors.red,
  ["NSP"] = colors.red,
}
local function prettypdb(pdb)
  print(colors.yellow("\tPeeringDB:\n"))
  local website = pdb:match"\nWebsite *: ([^\n]+)"
  if website then print(colors.cyan(website)) end
  local type = pdb:match"\nNetwork Type *: ([^\n]+)"
  if type then print("Network Type: " .. (typecolors[type] or colors.blue)(type)) end
  local ratio = pdb:match"\nTraffic Ratios *: ([^\n]+)"
  if ratio then print("Traffic Ratios: " .. ratio) end
  print()
end


local h = {
  {["<AS>[!-]"] = "Jump to AS number (! => add in database if non existent, - => delete)"},
  {d = "Review dunno"},
  {k = "Review kids"},
  {s = "Review sirs"},
  {r = "Decide AS numbers with whois matching regex"},
  {c = "Commit"},
  {q = "Quit"},
}
local flags = { ['-'] = false, ['!'] = true }
local function helpcmd(t)
  for _, cmd in ipairs(t) do
    local code, msg = next(cmd)
    print("", colors.pink(code), msg)
  end
end

local ASh = {
  {["-"] = "Delete this AS"},
  {d = "Dunno"},
  {s = "Sir"},
  {k = "Kid"},
  {w = "Fetch whois again"},
  {l = "Print long whois"},
  {p = "Fetch PeeringDB data again"},
  {["e [ex]"] = "Print exclusions, or set/get exclusion 'ex'"},
  {n = "Next"},
  {q = "Quit"},
}
local abbrev = { d = "dunno", k = "kids", s = "sirs" }
local tagcolor = { dunno = colors.blue, kids = colors.red, sirs = colors.green }

local function inspectAS(AS, tag)
  local whois, pdb, exclusions = fetchwhois(AS), fetchpdb(AS), getexclusions(AS)
  print("\n" .. colors.lightgray"========================================================================\n")
  if whois then prettywhois(whois) end
  if pdb then prettypdb(pdb) end
  print(tagcolor[tag]("AS" .. AS))

  while true do
    local cmd, e
    while not cmd do
      io.write(colors.pink("Command (-/d/s/k/w/l/p/e/n/q): "))
      local l = io.read("*l"):lower()
      cmd, e = l:match("^ *([%-dskwlpnqe]) *([%d%./]*)$")
      if not cmd or cmd == "e" and e ~= "" and not ip.ip(e)  then helpcmd(ASh) end
    end

    if cmd == '-' then
      db:settag(AS)
      print("Deleted AS" .. AS)
      break
    elseif abbrev[cmd] then
      db:settag(AS, abbrev[cmd])
      print(tagcolor[abbrev[cmd]]("AS" .. AS))
    elseif cmd == 'w' then
      local whois = fetchwhois(AS, true)
      if whois then prettywhois(whois) end
    elseif cmd == 'l' then
      local whois = fetchwhois(AS)
      if whois then
        local less = os.execute("which less >/dev/null 2>/dev/null") and io.popen("less", "w")
        if less then less:write(whois):close()
        else print(whois) end
      end
    elseif cmd == 'p' then
      local pdb = fetchpdb(AS, true)
      if pdb then prettypdb(pdb) end
    elseif cmd == 'n' then break
    elseif cmd == 'q' then return false
    elseif cmd == 'e' then
      if e == "" then
        if not next(exclusions) then print("No exclusions.")
        else for exclusion in pairs(exclusions) do print(colors.orange(exclusion)) end end
      else
        e = ip.ip(e)
        for exclusion in pairs(exclusions) do if exclusion == e then
          exclusions[exclusion] = nil
          setexclusions(AS, exclusions)
          print(colors.red("Removed") .. " exclusion " .. colors.orange(exclusion))
          goto nextcmd
        end end
        exclusions[e] = true
        setexclusions(AS, exclusions)
        print(colors.green("Added") .. " exclusion " .. colors.orange(e))
      end
    end
    :: nextcmd ::
  end
  return true

end


while true do

  local cmd, flag
  while not cmd do
    io.write(colors.pink("Command (<AS>[!-]/d/k/s/r/c/q): "))
    local l = io.read("*l"):lower()
    cmd, flag = l:match("^ *([%ddksrcq]+)([%!%-]?) *$")
    flag = flags[flag]
    if not cmd or (force and not tonumber(cmd)) then helpcmd(h) end
  end

  local AS = tonumber(cmd)
  if AS then
    if not db[AS] then
      if not flag then print("AS" .. AS .. " is not in the database.") goto nextcmd end
      db:settag(AS, "dunno")
    elseif flag == false then
      db:settag(AS)
      print("Deleted AS" .. AS)
      goto nextcmd
    end
    inspectAS(AS, db[AS].tag)
  elseif abbrev[cmd] then for AS in pairs(db.groups[abbrev[cmd]]) do
    if not inspectAS(AS, abbrev[cmd]) then break end
  end elseif cmd == 'c' then os.execute("git reset HEAD . && git add db/ && git commit")
  elseif cmd == 'r' then
    local regex
    while not regex do
      io.write(colors.pink("regex: "))
      regex = io.read("*l")
      if regex == "" then goto nextcmd end
      regex = pcall(function() (""):match(regex) end) and regex or print("Invalid pattern")
    end
    for AS in pairs(db.groups.dunno) do
      local whois = fetchwhois(AS)
      if whois and whois:lower():match(regex) then if not inspectAS(AS, db[AS].tag) then break end end
    end
  else return end

  :: nextcmd ::

end
