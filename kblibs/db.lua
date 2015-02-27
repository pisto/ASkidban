--[[

  File system database manipulation.

]]--

local lfs, json, fp, lambda = require"lfs", require"dkjson", require"kblibs.fp", require"kblibs.lambda"
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
    assert(not t[AS], "database inconsistency: duplicate AS" .. AS)
    local dataf = assert(io.open(fname))
    local data = json.decode(dataf:read"*a")
    dataf:close()
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
          assert(os.remove(oldfname))
          db[AS], oldgroup[AS] = nil
        end
        return
      end
      assert(db.groups[tag], "Invalid tag")
      local newfname, data = db.path .. sep .. tag .. sep .. AS, oldgroup and oldgroup[AS] or {}
      if oldgroup then
        if oldgroup.tag == tag then return end
        assert(os.rename(oldfname, newfname))
        db[AS], db.groups[tag][AS], oldgroup[AS] = db.groups[tag], data
      else
        assert(assert(io.open(db.ignorefile, "w")):write(emptyjson)):close()
        assert(os.rename(db.ignorefile, newfname))
        db[AS], db.groups[tag][AS] = db.groups[tag], data
      end
      return data
    end,
    setdata = function(db, AS, data)
      local group = db[AS]
      assert(group, "AS " .. AS .. " is not in the database")
      local j = json.encode(data, {indent = true})
      assert(assert(io.open(db.ignorefile, "w")):write(j)):close()
      assert(os.rename(db.ignorefile, db.path .. sep .. group.tag .. sep .. AS))
      group[AS] = data
      return data
    end
  }
}

function module.load(path)
  local db = setmetatable({ groups = {}, path = path, ignorefile = path .. sep .. ".ignoreme" }, meta)
  for _, tag in ipairs{"dunno", "kids", "sirs"} do
    print("Loaded " .. loadtag(db, path, tag) .. " " .. tag)
  end
  return db
end

return module
