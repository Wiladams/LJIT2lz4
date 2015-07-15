package.path = package.path..";../?.lua"

local xxhash = require("xxhash_ffi")

--unsigned int       LZ4_XXH32 (const void* input, size_t length, unsigned seed);
--unsigned long long LZ4_XXH64 (const void* input, size_t length, unsigned long long seed);

local src = "Hello World!";

local function test_simpleHash32()
	print("==== test_simpleHash32 ====")
	local digest = xxhash.LZ4_XXH32(src, #src, 1);
	print(string.format("digest: 0x%x", digest))
end

local function test_simpleHash64()
	print("==== test_simpleHash64 ====")
	local digest = xxhash.LZ4_XXH32(src, #src, 1);
	print(string.format("digest: 0x%x", digest))
end

test_simpleHash32();
test_simpleHash64();
