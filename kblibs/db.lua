--[[

  File system database manipulation.

]]--

local lfs, json, fp, lambda = require"lfs", require"json", require"kblibs.fp", require"kblibs.lambda"
local map = fp.map

local module = {}

local sep = package.config:sub(1, 1)
local function loadtag(t, path, name)
  local group = setmetatable({}, { __index = { tag = name } })
  t.groups[name] = group
  local tot = 0
  for file in lfs.dir(path .. sep .. name) do
    if file == ".." or file == "." or file == ".keepme" then goto next end
    local AS = tonumber(file)
    local fname = path .. sep .. name .. sep .. file
    if not AS or lfs.attributes(fname, "mode") ~= "file" then print("stray file in database: " .. file) goto next end
    if t[AS] then error("database inconsistency: duplicate AS" .. AS) end
    local dataf = io.open(fname)
    if not dataf then error("cannot read " .. fname) end
    local ok, data = pcall(function() return json.decode(dataf:read"*a") end)
    dataf:close()
    if not ok then error("Invalid json in " .. fname) end
    t[AS], group[AS] = group, data
    tot = tot + 1
    :: next ::
  end
  return tot
end

local emptyjson = json.encode{}
local meta = {
  __index = {
    settag = function(db, AS, tag)
      local oldgroup = db[AS]
      local oldfname = oldgroup and db.path .. sep .. oldgroup.tag .. sep .. AS
      if not tag then
        if oldgroup then
          local ok, err = os.remove(oldfname)
          assert(ok, err)
          db[AS], oldgroup[AS] = nil
        end
        return
      end
      assert(db.groups[tag], "Invalid tag")
      local newfname, data = db.path .. sep .. tag .. sep .. AS, oldgroup and oldgroup[AS] or {}
      if oldgroup then
        if oldgroup.tag == tag then return end
        local ok, err = os.rename(oldfname, newfname)
        assert(ok, err)
        db[AS], db.groups[tag][AS], oldgroup[AS] = db.groups[tag], data
      else
        local dataf, err = io.open(newfname, "w")
        assert(dataf, err)
        dataf, err = dataf:write(emptyjson)
        assert(dataf, err)
        dataf:close()
        db[AS], db.groups[tag][AS] = db.groups[tag], data
      end
      return data
    end,
    setdata = function(db, AS, data)
      local group = db[AS]
      assert(group, "AS " .. AS .. " is not in the database")
      local j = json.encode(data)
      local dataf, err = io.open(db.path .. sep .. group.tag .. sep .. AS, "w")
      assert(dataf, err)
      dataf, err = dataf:write(j)
      assert(dataf, err)
      dataf:close()
      group[AS] = data
      return data
    end
  }
}

function module.load(path)
  local db = setmetatable({ groups = {}, path = path }, meta)
  for _, tag in ipairs{"dunno", "kids", "sirs"} do
    print("Loaded " .. loadtag(db, path, tag) .. " " .. tag)
  end
  return db
end

return module
