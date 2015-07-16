-- xxhash.lua
local ffi = require("ffi")

local xxhash_ffi = require("xxhash_ffi")


--[[
	32-bit incremental hashing object
--]]
local xxHasher32 = {}
setmetatable(xxHasher32, {
	__call = function(self, ...)
		return self:new(...);
	end,
})

local xxHasher32_mt = {__index = xxHasher32}

function xxHasher32.init(self, handle)
	local obj = {
		Handle = handle;
	}
	setmetatable(obj, xxHasher32_mt);

	return obj;
end

function xxHasher32.new(self, seed)
	seed = seed or 0
	local state = xxhash_ffi.LZ4_XXH32_createState();
	if nil == state then
		return nil;
	end

	ffi.gc(state, xxhash_ffi.LZ4_XXH32_freeState);
	xxhash_ffi.LZ4_XXH32_reset(state, seed);

	return self:init(state);
end

function xxHasher32.update(self, data, len)
	len = len or #data
	local errcode = xxhash_ffi.LZ4_XXH32_update(self.Handle, data, len)

	return errcode;
end

function xxHasher32.finish(self)
	local digest = xxhash_ffi.LZ4_XXH32_digest(self.Handle)
	self.digest = digest;

	return digest;
end

--[[
	64-bit incremental hashing object
--]]
local xxHasher64 = {}
setmetatable(xxHasher64, {
	__call = function(self, ...)
		return self:new(...);
	end,
})

local xxHasher64_mt = {__index = xxHasher64}

function xxHasher64.init(self, handle)
	local obj = {
		Handle = handle;
	}
	setmetatable(obj, xxHasher64_mt);

	return obj;
end

function xxHasher64.new(self, seed)
	seed = seed or 0
	local state = xxhash_ffi.LZ4_XXH64_createState();
	if nil == state then
		return nil;
	end

	ffi.gc(state, xxhash_ffi.LZ4_XXH64_freeState);
	xxhash_ffi.LZ4_XXH64_reset(state, seed);

	return self:init(state);
end

function xxHasher64.update(self, data, len)
	len = len or #data
	local errcode = xxhash_ffi.LZ4_XXH64_update(self.Handle, data, len)

	return tonumber(errcode);
end

function xxHasher64.finish(self)
	local digest = xxhash_ffi.LZ4_XXH64_digest(self.Handle)
	self.digest = digest;

	return digest;
end


-- A couple of convenience functions for quick single hashes
local function digest32(str, seed)
    seed = seed or 0
    return tonumber(xxhash_ffi.LZ4_XXH32(str, #str, seed));
end

local function digest64(str, seed)
    seed = seed or 0
    return xxhash_ffi.LZ4_XXH64(str, #str, seed);
end


local exports = {
	xxHasher32 = xxHasher32;
	xxHasher64 = xxHasher64;

	    -- local functions
    digest32 = digest32;
    digest64 = digest64;

}

setmetatable(exports, {
	__call = function(self, ...)
		for k,v in pairs(self) do
			_G[k] = v;
		end

		return self;
	end,

})

return exports
