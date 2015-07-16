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
	print("==== test_digest ====")
	local text = "test"
	local digest = digest32(text, 12345)
	print(digest)
	assert(digest == 3834992036)
	print("OK")
end

local function test_hashVectors()
	print("==== test_hashValues ====")
	local vectors = {
		{src = "test", seed = 12345, expected = 3834992036},
		{src = "test", seed = 123, expected = 2758658570}
	}

	for _, v in ipairs(vectors) do
		local digest = tonumber(xxhash_ffi.LZ4_XXH32(v.src, #v.src, v.seed));

		io.write(string.format("%s %d %d %d\n", v.src, v.seed, v.expected, digest))
		assert(digest == v.expected)
	end
	print("OK")
end

local function test_hasher32()
	print("==== test_hasher32 ====")
	local hasher = xxhash.xxHasher32(123);

	hasher:update("te")
	hasher:update("st")
	local digest = hasher:finish();
	print(digest)
	assert(digest == 2758658570)
	print("OK")
end

local function test_hasher64()
	print("==== test_hasher64 ====")
	local hasher = xxhash.xxHasher64(123);

	print("update: ", hasher:update("test"))
	local digest = hasher:finish();
	print(digest)
	digest = tonumber(digest)
	print("OK")
end


test_simpleHash32();
test_simpleHash64();
test_hashVectors();
test_digest();
test_hasher32();
test_hasher64();