#!/usr/bin/env lua

pcall(function() require("debugger")() end)

assert(pcall(function() loadstring"goto label ::label::"() end), "Lua version 5.2 or luajit is required")
bit32 = bit32 or bit or require"bit"

local lfs = require"lfs"

local oldcd = lfs.currentdir()
local script, sep = arg[0], package.config:sub(1, 1)
lfs.chdir(script:match(".*%" .. sep))

local fp, L, ip = require"kblibs.fp", require"kblibs.lambda", require"kblibs.ip"
local map = fp.map


geoipfn = oldcd .. sep .. "GeoIPASNum2.csv"
commit = false
force = false

local function getarg(option)
  assert(#arg > 0, "Missing argument for " .. option)
  return table.remove(arg, 1)
end
local options = {
  h = function()
    print[[
Usage: ASkidban {[-h] | [-g <GeoIPASNum2.csv file>]... {hits | decide | compile}}

Options:
	-h		show help
	-g <file>	GeoIP ASnum database
	-c		commit changes to git
	-f		force (refresh cached IP ranges)

Commands:
	hits		import IP hits from stdin to seed AS numbers list
	decide		tag AS numbers
	compile		fetch IP ranges associated with the AS numbers
]]
  end,
  g = function() geoipfn = getarg"-g" end,
  c = function() commit = true end,
  f = function() force = true end,
}
local commands = map.vm(L"_, loadfile(_ .. '.lua')", "hits", "decide", "compile")

local cmd
while #arg > 0 do
  local a = table.remove(arg, 1)
  if a:sub(1, 1) == '-' then assert(options[a:sub(2)], "Unknown option " .. a)()
  else cmd = assert(commands[a:match("([^%.]+)%.?l?u?a?")], "Unknown command " .. a) end
end


function fetchwhois(AS, force)
  local data = db[AS][AS]
  if data.whois and not force then return data.whois end
  io.write("Fetching whois... ")
  local whois, err = io.popen("timeout 5 whois AS" .. AS)
  if not whois then print("Cannot fetch whois for AS" .. AS .. ": " .. err) return end
  local msg, err = whois:read"*a"
  local ok = whois:close()
  if not ok then print("Cannot fetch whois for AS" .. AS .. " (probably interrupted)") return end
  if not msg then print("Cannot fetch whois for AS" .. AS .. ": " .. err) return end
  data.whois = msg
  db:setdata(AS, data)
  print()
  return msg
end

function fetchpdb(AS, force)
  local data = db[AS][AS]
  if data.pdb ~= nil and not force then return data.pdb end
  io.write ("Fetching PeeringDB... ")
  local whois, err = io.popen("timeout 5 whois -h peeringdb.com AS" .. AS)
  if not whois then print("Cannot fetch PeeringDB for AS" .. AS .. ": " .. err) return end
  local msg, err = whois:read"*a"
  local ok = whois:close()
  if not ok then print("Cannot fetch PeeringDB for AS" .. AS .. " (probably interrupted)") return end
  if not msg then print("Cannot fetch PeeringDB for AS" .. AS .. ": " .. err) return end
  data.pdb = not msg:match"Record not found" and msg or false
  db:setdata(AS, data)
  if not data.pdb then print("Not found.") else print() end
  return data.pdb
end

function getexclusions(AS)
  return map.si(function(_, sip) return assert(ip.ip(sip), "Invalid exclusion range in AS" .. AS) end, db[AS][AS].exclusions or {})
end

function setexclusions(AS, exclusions)
  local data = db[AS][AS]
  data.exclusions = next(exclusions) and map.lp(tostring, exclusions) or nil
  db:setdata(AS, data)
end


db = require"kblibs.db".load"db"
print("Database check succeeded.")
return cmd and cmd()
