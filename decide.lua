--[[

  Interactively tag AS numbers.

]]--

local fp = require"kblibs.fp"
local map = fp.map


local function fetchwhois(AS, force)
  local data = db[AS][AS]
  if data.whois and not force then return data.whois end
  local whois, err = io.popen("whois AS" .. AS)
  if not whois then print("Cannot fetch whois: " .. err) return end
  local msg, err = whois:read"*a"
  whois:close()
  if not msg then print("Cannot fetch whois: " .. err) return end
  data.whois = msg
  db:setdata(AS, data)
end


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

local h = {
  {["<AS>[!-]"] = "Jump to AS number (! => add in database if non existent, - => delete)"},
  {d = "Decide AS numbers"},
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
  local whois = fetchwhois(AS)
  if whois then
    print("\n" .. colors.lightgray"========================================================================\n")
    --TODO print miniwhois
  end
  print("\n\n" .. tagcolor[tag]("AS" .. AS))

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
      if whois then
        --TODO print miniwhois
      end
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
    io.write(colors.pink("Command (<AS>[!-]/d/c/q): "))
    local l = io.read("*l"):lower()
    cmd, flag = l:match("^ *([%dcdq]+)([%!%-]?) *$")
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
  else return end

  :: nextcmd ::

end
