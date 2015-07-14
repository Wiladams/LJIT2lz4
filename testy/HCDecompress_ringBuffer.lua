package.path = package.path..";../?.lua"

-- LZ4 HC streaming API example : ring buffer
-- Take a stream that was compressed using the HCCompress_ringBuffer.lua 
-- program, and decompress it.

local ffi = require("ffi")

local lz4 = require ("lz4_ffi")
local lz4hc = require ("lz4hc_ffi")
local stdlib = require("testy.stdlib")

local lz4lib = lz4.Lib_lz4
local rand = math.random;

local printf = stdlib.printf


local MESSAGE_MAX_BYTES   = 1024;
local RING_BUFFER_BYTES   = 1024 * 8 + MESSAGE_MAX_BYTES;
local DEC_BUFFER_BYTES    = RING_BUFFER_BYTES + MESSAGE_MAX_BYTES;   -- Intentionally larger to test unsynchronized ring buffers
local maxDstBytes = lz4.LZ4_COMPRESSBOUND(MESSAGE_MAX_BYTES)



local decBuf = ffi.new("char[?]", DEC_BUFFER_BYTES);
local cmpBuf = ffi.new("char[?]", maxDstBytes);

local function test_decompress(outFp, inpFp)
    print("==== test_decompress ====")

    local decOffset = 0;
    local lz4StreamDecode = lz4.LZ4_createStreamDecode();

    while(true) do
    
        local cmpBytes = 0;
        local r0 = 0;

        -- How many compressed bytes are we about to read
        r0, cmpBytes = inpFp:read_int32();
        if(r0 ~= 1 or cmpBytes <= 0) then
            break;
        end

        local r1 = inpFp:read(cmpBuf, cmpBytes);
        if(r1 ~= cmpBytes) then
            break;
        end


        -- uncompress bytes into the ring buffer
        local decPtr = ffi.cast("char *", decBuf) + decOffset;
        local decBytes = lz4lib.LZ4_decompress_safe_continue(lz4StreamDecode, cmpBuf, decPtr, cmpBytes, MESSAGE_MAX_BYTES);

        if (decBytes <= 0) then
            break;
        end

        decOffset = decOffset + decBytes;
        outFp:write(decPtr, decBytes);

        -- Wraparound the ringbuffer offset
        if (decOffset >= DEC_BUFFER_BYTES - MESSAGE_MAX_BYTES) then
            decOffset = 0;
        end
    end

end


local function main(argc, argv)

    local filename = argv[1];


    local lz4Filename = string.format("%s.lz4s-%d", filename, 9);
    local decFilename = string.format("%s.lz4s-%d.dec", filename, 9);

    printf("input   = [%s]\n", filename);
    printf("lz4     = [%s]\n", lz4Filename);
    printf("decoded = [%s]\n", decFilename);


    -- decompress
    inpFp = stdlib.StdFile:new(lz4Filename, "rb");
    outFp = stdlib.StdFile:new(decFilename, "wb");

    test_decompress(outFp, inpFp);

    return 0;
end

main(#arg, arg)

