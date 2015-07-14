package.path = package.path..";../?.lua"

-- LZ4 HC streaming API example : ring buffer
-- Based on previous work from Takayuki Matsuoka



local ffi = require("ffi")

local lz4 = require ("lz4_ffi")()
local lz4hc = require ("lz4hc_ffi")()
local stdlib = require("testy.stdlib")()

local rand = math.random;

ffi.cdef[[
typedef union {
    char bytes[4];
    int32_t intValue;    
} typealias;
]]
local typealias = ffi.typeof("typealias")


local MESSAGE_MAX_BYTES   = 1024;
local RING_BUFFER_BYTES   = 1024 * 8 + MESSAGE_MAX_BYTES;
local DEC_BUFFER_BYTES    = RING_BUFFER_BYTES + MESSAGE_MAX_BYTES;   -- Intentionally larger to test unsynchronized ring buffers
local maxDstBytes = LZ4_COMPRESSBOUND(MESSAGE_MAX_BYTES)



local function write_int32(fp, i) 
    local talias = typealias({intValue=i})
    --print("write_int32: ", i, talias.intValue)
    fp:write(talias.bytes, 4);
    return 1;
end

local function write_bin(fp, array, arrayBytes)
    return fp:write(array, arrayBytes);
end

local function read_int32(fp)
    local talias = typealias();
    local res = fp:read(talias.bytes, 4);
    print("read_int32: ", res, talias.intValue)
    if res ~= 4 then
        return 0;
    end

    return 1, tonumber(talias.intValue);
end


local inpBuf = ffi.new("char[?]",RING_BUFFER_BYTES);

local function test_compress(outFp, inpFp)

    local lz4Stream = LZ4_createStreamHC();
    ffi.gc(lz4Stream, LZ4_freeStreamHC);

    local inpOffset = 0;

    while (true) do    
        local inpPtr = ffi.cast("char *", inpBuf) + inpOffset;
        local randomLength = rand(1, MESSAGE_MAX_BYTES);
        local inpBytes = inpFp:read(inpPtr, randomLength);
        if (0 == inpBytes) then
            break;
        end

        do
            cmpBuf = ffi.new("char[?]", maxDstBytes);
            local cmpBytes = LZ4_compress_HC_continue(lz4Stream, inpPtr, cmpBuf, inpBytes, maxDstBytes);

            if (cmpBytes <= 0) then
                break;
            end

            write_int32(outFp, cmpBytes);
            outFp:write(cmpBuf, cmpBytes);

            inpOffset = inpOffset + inpBytes;

            -- Wraparound the ringbuffer offset
            if (inpOffset >= RING_BUFFER_BYTES - MESSAGE_MAX_BYTES) then
                inpOffset = 0;
            end
        end
    end

    write_int32(outFp, 0);
end



local function main(argc, argv)

    local filename = argv[1]

    local inpFilename = filename;
    local lz4Filename = string.format("%s.lz4s-%d", filename, 9);

    printf("input   = [%s]\n", inpFilename);
    printf("lz4     = [%s]\n", lz4Filename);

    -- compress
    do
        inpFp, errstr = StdFile(inpFilename, "rb");
  print("inpFp, err: ", inpFp, errstr);      
        outFp, errstr = StdFile(lz4Filename, "wb");

        test_compress(outFp, inpFp);

        inpFp:close();
        outFp:close();
    end
    
    return 0;
end

main(#arg, arg)

