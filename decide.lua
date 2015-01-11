--[[

  Interactively tag AS numbers.

]]--

local fp, lambda = require"kblibs.fp", require"kblibs.lambda"
local map, pick, Lr = fp.map, fp.pick, lambda.Lr


local colors = map.mp(function(name, code) return name, function(str)
  return code .. str .. "\27[0m"
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
}

local function firstmatch(line, regexes)
  for _, regex in ipairs(regexes) do if line:match(regex) then return true end end
end

local function prettywhois(whois)
  local colored, websites, inellipsis = "", {}, false
  for line in whois:lower():gmatch("[^\n]+") do
    map.tsi(websites, function(_, regex) return line:match(regex) end, whois_http)
    if line == "" or firstmatch(line, whois_ignore) then
      if not inellipsis then inellipsis, colored = true, colored .. colors.gray("[...]\n") end
    else inellipsis, colored = false, colored .. line .. '\n' end
  end
  for _, regex in ipairs(maybe_kids) do colored = colored:gsub(regex, colors.red) end
  for _, regex in ipairs(maybe_sirs) do colored = colored:gsub(regex, colors.green) end
  print(colored)
  websites = pick.p(function(match) return not firstmatch(match, whois_http_ignore) end, websites)
  if next(websites) then print(colors.cyan(table.concat(map.lp(Lr"'http://'.._", websites), " "))) end
end


local function fetchwhois(AS, force)
  local data = db[AS][AS]
  if data.whois and not force then return data.whois end
  local whois, err = io.popen("timeout 5 whois AS" .. AS)
  if not whois then print("Cannot fetch whois for AS" .. AS .. ": " .. err) return end
  local msg, err = whois:read"*a"
  local ok = whois:close()
  if not ok then print("Cannot fetch whois for AS" .. AS .. " (probably interrupted)") return end
  if not msg then print("Cannot fetch whois for AS" .. AS .. ": " .. err) return end
  data.whois = msg
  db:setdata(AS, data)
  return msg
end


local h = {
  {["<AS>[!-]"] = "Jump to AS number (! => add in database if non existent, - => delete)"},
  {d = "Decide AS numbers"},
  {k = "Review kids"},
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
  {p = "Print full whois"},
  {n = "Next"},
  {q = "Quit"},
}
local abbrev = { d = "dunno", k = "kids", s = "sirs" }
local tagcolor = { dunno = colors.blue, kids = colors.red, sirs = colors.green }

local function inspectAS(AS, tag)
  print("\n" .. colors.lightgray"========================================================================\n")
  local whois = fetchwhois(AS)
  if whois then prettywhois(whois) end
  print("\n" .. tagcolor[tag]("AS" .. AS))

  while true do
    local cmd
    while not cmd do
      io.write(colors.pink("Command (-/d/s/k/w/p/n/q): "))
      local l = io.read("*l"):lower()
      cmd = l:match("^ *([%-dskwpnq]+) *$")
      if not cmd then helpcmd(ASh) end
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
    elseif cmd == 'p' then
      local whois = fetchwhois(AS)
      if whois then
        local less = os.execute("which less >/dev/null 2>/dev/null") and io.popen("less", "w")
        if less then less:write(whois) less:close()
        else print(whois) end
      end
    elseif cmd == 'n' then break
    elseif cmd == 'q' then return false
    end
  end
  return true

end


while true do

  local cmd, flag
  while not cmd do
    io.write(colors.pink("Command (<AS>[!-]/d/k/r/c/q): "))
    local l = io.read("*l"):lower()
    cmd, flag = l:match("^ *([%ddkrcq]+)([%!%-]?) *$")
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
  elseif cmd == 'd' then for AS in pairs(db.groups.dunno) do
    if not inspectAS(AS, db[AS].tag) then break end
  end elseif cmd == 'c' then os.execute("git reset HEAD . && git add db/ && git commit")
  elseif cmd == 'k' then for AS in pairs(db.groups.kids) do
    if not inspectAS(AS, db[AS].tag) then break end
  end elseif cmd == 'r' then
    local regex
    while not regex do
      io.write(colors.pink("regex (lowercase): "))
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
