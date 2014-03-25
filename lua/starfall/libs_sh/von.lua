--[[
	Copyright 2012-2013 Alexandru-Mihai Maftei
					aka Vercas

	You may use this for any purpose as long as:
	-	You don't remove this copyright notice.
	-	You don't claim this to be your own.
	-	You properly credit the author (Vercas) if you publish your work based on (and/or using) this.

	If you modify the code for any purpose, the above obligations still apply.

	Instead of copying this code over for sharing, rather use the link:
		https://dl.dropbox.com/u/1217587/GMod/Lua/von.lua

	The author may not be held responsible for any damage or losses directly or indirectly caused by
	the use of vON.

	If you disagree with the above, don't use the code.

-----------------------------------------------------------------------------------------------------------------------------

	Thanks to the following people for their contribution:
		-	Divran						Suggested improvements for making the code quicker.
										Suggested an excellent new way of deserializing strings.
										Lead me to finding an extreme flaw in string parsing.
		-	pennerlord					Provided some performance tests to help me improve the code.

-----------------------------------------------------------------------------------------------------------------------------

	The value types supported in this release of vON are:
		-	table
		-	number
		-	boolean
		-	string
		-	nil

	These are the native Lua types one would normally serialize.

-----------------------------------------------------------------------------------------------------------------------------

	New in this version:
		-	Added errors on (de)serialization when passwing the wrong data type.
		-	Removed two redundant arguments in the serialization functable.
--]]

--- vON Library
-- @shared
-- @deprecated Pure Lua implementation. This can be done with a user library.
local von, _ = SF.Libraries.Register("von")

local _deserialize, _serialize, _d_meta, _s_meta, d_findVariable, s_anyVariable
local sub, gsub, find, insert, concat, error, tonumber, tostring, type, next = string.sub, string.gsub, string.find, table.insert, table.concat, error, tonumber, tostring, type, next

--	This is kept away from the table for speed.
function d_findVariable(s, i, len, lastType)
	local i, c, typeRead, val = i or 1

	--	Keep looping through the string.
	while true do
		--	Stop at the end. Throw an error. This function MUST NOT meet the end!
		if i > len then
			SF.throw( "vON: Reached end of string, cannot form proper variable.", 3 )
		end

		--	Cache the character. Nobody wants to look for the same character ten times.
		c = sub(s, i, i)

		--	If it just read a type definition, then a variable HAS to come after it.
		if typeRead then
			--	Attempt to deserialize a variable of the freshly read type.
			val, i = _deserialize[lastType](s, i, len)
			--	Return the value read, the index of the last processed character, and the type of the last read variable.
			return val, i, lastType

			--	@ means nil. It should not even appear in the output string of the serializer. Nils are useless to store.
		elseif c == "@" then
			return nil, i, lastType

			--	n means a number will follow. Base 10... :C
		elseif c == "n" then
			lastType = "number"
			typeRead = true

			--	b means boolean flags.
		elseif c == "b" then
			lastType = "boolean"
			typeRead = true

			--	" means the start of a string.
		elseif c == "\"" then
			lastType = "string"
			typeRead = true

			--	{ means the start of a table!
		elseif c == "{" then
			lastType = "table"
			typeRead = true

			--	If no type has been found, attempt to deserialize the last type read.
		elseif lastType then
			val, i = _deserialize[lastType](s, i, len)
			return val, i, lastType

			--	This will occur if the very first character in the vON code is wrong.
		else
			SF.throw( "vON: Malformed data... Can't find a proper type definition. Char#" .. i .. ":" .. c, 3 )
		end

		--	Move the pointer one step forward.
		i = i + 1
	end
end

--	This is kept away from the table for speed.
--	Yeah, crapload of parameters.
function s_anyVariable(data, lastType, isNumeric, isKey, isLast, nice, indent)

	--	Basically, if the type changes.
	if lastType ~= type(data) then
		--	Remember the new type. Caching the type is useless.
		lastType = type(data)

		--	Return the serialized data and the (new) last type.
		--	The second argument, which is true now, means that the data type was just changed.
		return _serialize[lastType](data, true, isNumeric, isKey, isLast, nice, indent), lastType
	end

	--	Otherwise, simply serialize the data.
	return _serialize[lastType](data, false, isNumeric, isKey, isLast, nice, indent), lastType
end

_deserialize = {

	--	Well, tables are very loose...
	--	The first table doesn't have to begin and end with { and }.
	["table"] = function(s, i, len, unnecessaryEnd)
		local ret, numeric, i, c, lastType, val, ind, expectValue, key = {}, true, i or 1
		--	Locals, locals, locals, locals, locals, locals, locals, locals and locals.

		--	Keep looping.
		while true do
			--	Until it meets the end.
			if i > len then
				--	Yeah, if the end is unnecessary, it won't spit an error. The main chunk doesn't require an end, for example.
				if unnecessaryEnd then
					return ret, i

					--	Otherwise, the data has to be damaged.
				else
					SF.throw( "vON: Reached end of string, incomplete table definition.", 2 )
				end
			end

			--	Cache the character.
			c = sub(s,i,i)
			--print(i, "table char:", c, tostring(unnecessaryEnd))

			--	If it's the end of a table definition, return.
			if c == "}" then
				return ret, i

				--	If it's the component separator, switch to key:value pairs.
			elseif c == "~" then
				numeric = false

			elseif c == ";" then
				--	Lol, nothing!
				--	Remenant from numbers, for faster parsing.

				--	OK, now, if it's on the numeric component, simply add everything encountered.
			elseif numeric then
				--	Find a variable and it's value
				val, i, lastType = d_findVariable(s, i, len, lastType)
				--	Add it to the table.
				ret[#ret + 1] = val

				--	Otherwise, if it's the key:value component...
			else
				--	If a value is expected...
				if expectValue then
					--	Read it.
					val, i, lastType = d_findVariable(s, i, len, lastType)
					--	Add it?
					ret[key] = val
					--	Clean up.
					expectValue, key = false, nil

					--	If it's the separator...
				elseif c == ":" then
					--	Expect a value next.
					expectValue = true

					--	But, if there's a key read already...
				elseif key then
					--	Then this is malformed.
					SF.throw( "vON: Malformed table... Two keys declared successively? Char#" .. i .. ":" .. c, 2 )

					--	Otherwise the key will be read.
				else
					--	I love multi-return and multi-assignement.
					key, i, lastType = d_findVariable(s, i, len, lastType)
				end
			end

			i = i + 1
		end

		return nil, i
	end,


	--	Numbers are weakly defined.
	--	The declaration is not very explicit. It'll do it's best to parse the number.
	--	Has various endings: \n, }, ~, : and ;, some of which will force the table deserializer to go one char backwards.
	["number"] = function(s, i, len)
		local i, a = i or 1
		--	Locals, locals, locals, locals

		a = find(s, "[;:}~]", i)

		if a then
			return tonumber(sub(s, i, a - 1)), a - 1
		end

		SF.throw( "vON: Number definition started... Found no end.", 3 )
	end,


	--	A boolean is A SINGLE CHARACTER, either 1 for true or 0 for false.
	--	Any other attempt at boolean declaration will result in a failure.
	["boolean"] = function(s, i, len)
		local c = sub(s,i,i)
		--	Only one character is needed.

		--	If it's 1, then it's true
		if c == "1" then
			return true, i

			--	If it's 0, then it's false.
		elseif c == "0" then
			return false, i
		end

		--	Any other supposely "boolean" is just a sign of malformed data.
		SF.throw( "vON: Invalid value on boolean type... Char#" .. i .. ": " .. c, 3 )
	end,


	--	Strings are very easy to parse and also very explicit.
	--	" simply marks the type of a string.
	--	Then it is parsed until an unescaped " is countered.
	["string"] = function(s, i, len)
		local res, i, a = "", i or 1
		--	Locals, locals, locals, locals

		while true do
			a = find(s, "\"", i, true)

			if a then
				if sub(s, a - 1, a - 1) == "\\" then
					res = res .. sub(s, i, a - 2) .. "\""
					i = a + 1
				else
					return res .. sub(s, i, a - 2), a
				end
			else
				SF.throw( "vON: String definition started... Found no end.", 3 )
			end
		end
	end
}


_serialize = {

	--	Uh. Nothing to comment.
	--	Shitload of parameters.
	--	Makes shit faster than simply passing it around in locals.
	--	table.concat works better than normal concatenations WITH LARGE-ISH STRINGS ONLY.
	["table"] = function(data, mustInitiate, isNumeric, isKey, isLast, first)
	--print(string.format("data: %s; mustInitiate: %s; isKey: %s; isLast: %s; nice: %s; indent: %s; first: %s", tostring(data), tostring(mustInitiate), tostring(isKey), tostring(isLast), tostring(nice), tostring(indent), tostring(first)))

		local result, keyvals, len, keyvalsLen, keyvalsProgress, val, lastType, newIndent, indentString = {}, {}, #data, 0, 0
		--	Locals, locals, locals, locals, locals, locals, locals, locals, locals and locals.

		--	First thing to be done is separate the numeric and key:value components of the given table in two tables.
		--	pairs(data) is slower than next, data as far as my tests tell me.
		for k, v in next, data do
			--	Skip the numeric keyz.
			if type(k) ~= "number" or k < 1 or k > len then
				keyvals[#keyvals + 1] = k
			end
		end

		keyvalsLen = #keyvals

		--	Main chunk - no initial character.
		if not first then
			result[#result + 1] = "{"
		end

		--	Add numeric values.
		if len > 0 then
			for i = 1, len do
				val, lastType = s_anyVariable(data[i], lastType, true, false, i == len and not first, false, 0)
				result[#result + 1] = val
			end
		end

		--	If there are key:value pairs.
		if keyvalsLen > 0 then
			--	Insert delimiter.
			result[#result + 1] = "~"

			--	Insert key:value pairs.
			for _i = 1, keyvalsLen do
				keyvalsProgress = keyvalsProgress + 1

				val, lastType = s_anyVariable(keyvals[_i], lastType, false, true, false, false, 0)

				result[#result + 1] = val..":"

				val, lastType = s_anyVariable(data[keyvals[_i]], lastType, false, false, keyvalsProgress == keyvalsLen and not first, false, 0)

				result[#result + 1] = val
			end
		end

		--	Main chunk needs no ending character.
		if not first then
			result[#result + 1] = "}"
		end

		return concat(result)
	end,


	--	Normal concatenations is a lot faster with small strings than table.concat
	--	Also, not so branched-ish.
	["number"] = function(data, mustInitiate, isNumeric, isKey, isLast)
	--	If a number hasn't been written before, add the type prefix.
		if mustInitiate then
			if isKey or isLast then
				return "n"..data
			else
				return "n"..data..";"
			end
		end

		if isKey or isLast then
			return "n"..data
		else
			return "n"..data..";"
		end
	end,


	--	I hope gsub is fast enough.
	["string"] = function(data, mustInitiate, isNumeric, isKey, isLast)
		return "\"" .. gsub(data, "\"", "\\\"") .. "v\""
	end,


	--	Fastest.
	["boolean"] = function(data, mustInitiate, isNumeric, isKey, isLast)
	--	Prefix if we must.
		if mustInitiate then
			if data then
				return "b1"
			else
				return "b0"
			end
		end

		if data then
			return "1"
		else
			return "0"
		end
	end,


	--	Fastest.
	["nil"] = function(data, mustInitiate, isNumeric, isKey, isLast)
		return "@"
	end
}

local _s_table = _serialize.table
local _d_table = _deserialize.table

_d_meta = {
	__call = function(self, str)
		if type(str) == "string" then
			return _d_table(str, nil, #str, true)
		end
		SF.throw( "vON: You must deserialize a string, not a " .. type( str ), 2 )
	end
}
_s_meta = {
	__call = function(self, data)
		if type(data) == "table" then
			return _s_table(data, nil, nil, nil, nil, true)
		end
		SF.throw( "vON: You must serialize a table, not a " .. type( data ), 2 )
	end
}

--- Deserialize a string
-- @shared
-- @class function
-- @name von.deserialize
-- @param str String to deserialize
-- @return Table
von.deserialize = setmetatable(_deserialize,_d_meta)

--- Serialize a table
-- @shared
-- @class function
-- @name von.serialize
-- @param tbl Table to serialize
-- @return String
von.serialize = setmetatable(_serialize,_s_meta)
