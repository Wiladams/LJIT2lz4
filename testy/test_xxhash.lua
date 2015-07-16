package.path = package.path..";../?.lua"

local xxhash_ffi = require("xxhash_ffi")
local xxhash = require("xxhash")
local digest32 = xxhash.digest32;
local digest64 = xxhash.digest64;


local src = "Hello World!";

local function test_simpleHash32()
	print("==== test_simpleHash32 ====")
	local digest = xxhash_ffi.LZ4_XXH32(src, #src, 1);
	print(string.format("digest: 0x%x", digest))
end

local function test_simpleHash64()
	print("==== test_simpleHash64 ====")
	local digest = xxhash_ffi.LZ4_XXH32(src, #src, 1);
	print(string.format("digest: 0x%x", digest))
end

local function test_digest()
	local text = "test"
	local digest = digest32(text, 12345)
	print(digest)
end

local function test_hashVectors()
	print("==== test_hashValues ====")
	local vectors = {
		{src = "test", seed = 12345, expected = 3834992036},
		{src = "test", seed = 123, expected = 2758658570}
	}

	for _, v in ipairs(vectors) do
		local digest = tonumber(xxhash.LZ4_XXH32(v.src, #v.src, v.seed));

		io.write(string.format("%s %d %d %d\n", v.src, v.seed, v.expected, digest))
		assert(digest == v.expected)
	end
	print("OK")
end

--test_simpleHash32();
--test_simpleHash64();
--test_hashVectors();
test_digest();
