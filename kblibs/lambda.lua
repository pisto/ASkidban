local compiled = {}

local function L(code)
	local cached = compiled[code]
	if cached then return cached end
		local L, err, Lr, errr = load("local _, _1, _2, _3, _4, _5, _6, _7, _8, _9 = ..., ... " .. code, "<lambda>")
		if not L then Lr, errr = load("local _, _1, _2, _3, _4, _5, _6, _7, _8, _9 = ..., ... return " .. code, "<lambda>") end
		L = L or Lr
		assert(L, "Cannot compile lambda: " .. tostring(err) .. " | " .. tostring(errr))
		compiled[code] = L
	return L
end

return L
