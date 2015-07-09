package.path = package.path..";../?.lua"

local lz4 = require("lz4_ffi")
lz4();

local function main()
	print(string.format("Hello World ! LZ4 Library version = %d", LZ4_versionNumber()))
	local vertuple = LZ4_Version();
	print("Version Breakout: ", vertuple.major, vertuple.minor, vertuple.release);
end

main()
