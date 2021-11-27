function parseDeclaration(str)
	local tokens = {}
	local ignore_until = -1
	local splitstr = {}
	
	for char in str:gmatch(".") do
		table.insert(splitstr, char)
	end
	
	for i, char in pairs(splitstr) do
		if ignore_until == -1 or ignore_until == i then 
			ignore_until = -1
			
			if char == "(" then
				table.insert(tokens, "(")
			elseif char == ")" then
				table.insert(tokens, ")")
			elseif char == "," then
			else
				if char ~= " " then
					if type(temp) ~= "string" then temp = "" end
					for a = i, #splitstr do
						local char = splitstr[a]
						if char == "(" or char == ")" or char == "," or char == " " then break end
						temp = temp .. splitstr[a]
					end
					
					table.insert(tokens, temp)
					ignore_until =  i + #temp
					
					temp = nil
				end
			end
		end
	end
	
	if #tokens < 3 then
		print("INVALID DECLARATION")
	end
	
	local data = {}
	data.returnType = tokens[1]
	data.expectedParameters = {}
	data.parameterNames = {}
	
	local inside = false
	for i,v in pairs(tokens) do
		if v == "(" then inside = true end
		if v == ")" then inside = false end
		
		if inside then
			if v == "int" or v == "void" or v == "string" or v == "double" or v == "float" or v == "bool" or v == "char*" or v == "uintptr_t" or v == "uint64_t" or v == "uint32_t" or v == "uint16_t" or v == "uint8_t" then
				table.insert(data.expectedParameters, v)
			elseif v ~= "(" then
				print(v)
				table.insert(data.parameterNames, v)
			end
		end
	end
	
	return data
end

function safetycheck(self)
	if not self then
		error("Missing self! Did you mean to use ':' and not '.'?")
		return false
	end	
	
	return true
end

function declareNamespace(namespace)
	setmetatable(namespace, {
		__index = function(self, idx)
			error("indexed an unknown value [" .. tostring(idx) .. "] in namespace: " .. namespace.namespace)
		end
	})
	
	return namespace
end


value = declareNamespace({
	namespace = "value",
	new = function(val, valtype)
		local realvalue = val
		
		local self = setmetatable({type = valtype or type(val)}, {
			__index = function(self, idx)
				if idx == "Value" then
					return realvalue
				end
				return value[idx]
			end,
			__newindex = function(self, idx, newval)
				if idx == "Value" then
					if self:checkvalue(newval) then
						realvalue = newval
					else
						error("attempt to set to '" .. type(newval) .. "', '" .. self.type .. "' expected")
					end
				end
			end,
			__tostring = function(self)
				return tostring(realvalue)
			end
		})
		
		if not self:checkvalue(val) then
			return nil
		end
		
		return self
	end,
	checkvalue = function(self, newval)
		local types = {
			["number"] = {"int", "float", "double", "number", "byte", "char", "uintptr_t", "uint64_t", "uint32_t", "uint16_t", "uint8_t"},
			["string"] = {"char*", "std::string", "string"},
			["boolean"] = {"bool", "boolean"},
			["nil"] = {"void", "nil"}
		}
		
		for basetype,tbl in pairs(types) do
			for _, subtype in pairs(tbl) do
				if self.type == subtype then
					return type(newval) == basetype
				end
			end
		end
	end
})

functional = declareNamespace({ -- dont make direct calls to functional unless you know what you're doing
	namespace = "functional",
	new = function(decl)
		return setmetatable({
			name = nil,
			declaration = decl,
			decl_str = nil
		}, {
			__index = functional,
			__call = function(self, funcstr)
				local internalfunc = loadstring(funcstr)
				
				local cpp_value_pool = {}
				local newenv = setmetatable({}, {
					__index = function(self, idx) -- keep typechecking but remove the need of an actual simulated object
						if cpp_value_pool[idx] then
							return cpp_value_pool[idx].Value
						end
						
						return _G[idx]
					end,
					__newindex = function(self, idx, newval) 
						if cpp_value_pool[idx] then
							cpp_value_pool[idx].Value = newval
							return
						end
						
						_G[idx] = newval
					end
				})
				
				return function(...)
					local tbl = {...}
				
					if #self.declaration.expectedParameters > #tbl then
						error("Not every parameter was filled in during function call!")
						return
					end
					
					for i,v in pairs(tbl) do
						if self.declaration.parameterNames[i] and self.declaration.expectedParameters[i] then
							local obj = value.new(v, self.declaration.expectedParameters[i])
							if not obj then
								error("attempt to call function with invalid arguments! expected: '" .. tostring(self.declaration.expectedParameters[i]) .. "', got '" .. type(v) .. "', field: '" .. tostring(self.declaration.parameterNames[i]) .. "'")
								return
							end
							cpp_value_pool[self.declaration.parameterNames[i]] = obj
						end
					end
					
					setfenv(internalfunc, newenv)
					local res = internalfunc()
					local retval = value.new(res, self.declaration.returnType)
					if not retval then
						error("attempt to return invalid type, got '" .. type(res) .. "' expected '" .. self.declaration.returnType .. "'")
					end
					
					return retval
				end
			end
		})
	end,
	printname = function(self, start_text)
		if not safetycheck(self) then return end
		print(start_text or "current function:", self.name)
	end
})

cpp = declareNamespace({
	namespace = "cpp",
	new = function()
		local object = {
			functionlist = {}
		}
		setmetatable(object, {__index = cpp})
		return object
	end,
	declare = function(self, declaration)
		if not safetycheck(self) then return end
		local parsed_decl = parseDeclaration(declaration)
		local newfunc = functional.new(parsed_decl)
		table.insert(self.functionlist, newfunc)
		return newfunc
	end
})


local mycpp = cpp.new()
local forward_decl = mycpp:declare("uint32_t(uintptr_t a, uintptr_t b)")

addfunc = forward_decl[[ -- objects passed at top are C++ OBJECTS, NOT LUA
	return a + b
]]

subfunc = forward_decl[[
	return a - b
]]

mulfunc = forward_decl[[
	b = "hi there"
	return a * b
]]

local res = addfunc(5, 10)
local res2 = subfunc(10, 5)
local res3 = mulfunc(res.Value, res2.Value)

print(res.Value, res2.Value, res3.Value)











