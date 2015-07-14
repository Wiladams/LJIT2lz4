package.path = package.path..";../?.lua"

-- LZ4 HC streaming API example : ring buffer
-- Based on previous work from Takayuki Matsuoka



local ffi = require("ffi")

local lz4 = require ("lz4_ffi")()
local lz4hc = require ("lz4hc_ffi")()
local stdlib = require("testy.stdlib")()

local lz4lib = lz4.Lib_lz4
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


local function read_int32(fp)
    local talias = typealias();
    local res = fp:read(talias.bytes, 4);
    --print("read_int32: ", res, talias.intValue)
    if res ~= 4 then
        return 0;
    end

    return 1, tonumber(talias.intValue);
end


local function createStreamDecode()
    local lz4s = ffi.cast("LZ4_streamDecode_t *", ffi.C.calloc(1, ffi.sizeof("LZ4_streamDecode_t")));
    --local lz4s = (LZ4_streamDecode_t*) ALLOCATOR(1, sizeof(LZ4_streamDecode_t));
    return lz4s;
end

--local decBuf = ffi.new("char[?]", DEC_BUFFER_BYTES);
local decBuf = ffi.C.malloc(DEC_BUFFER_BYTES)
--local cmpBuf = ffi.new("char[?]", maxDstBytes);
local cmpBuf = ffi.C.malloc(maxDstBytes);

local function test_decompress(outFp, inpFp)
    print("==== test_decompress ====")
    print("outFp: ", outFp)
    print("inpFp: ", inpFp)

    local decOffset = 0;
--    local lz4streamDecode = LZ4_createStreamDecode();
    local lz4streamDecode = createStreamDecode()
--print("Sizeof lzstreamDecode: ", ffi.sizeof(lz4streamDecode), lz4streamDecode)
--print("Sizeof LZ4_streamHC_t: ", ffi.sizeof("LZ4_streamHC_t"))

    while(true) do
    
        local cmpBytes = 0;
        local r0 = 0;

        --do
            r0, cmpBytes = read_int32(inpFp);
            if(r0 ~= 1 or cmpBytes <= 0) then
                break;
            end

            local r1 = inpFp:read(cmpBuf, cmpBytes);
print("read_bin: ", r1, cmpBytes)
            if(r1 ~= cmpBytes) then
                break;
            end
        --end
--print("next section")
        --do
            local decPtr = ffi.cast("char *", decBuf) + decOffset;
--print("1.0, offset: ", decOffset, decBuf, decPtr, MESSAGE_MAX_BYTES)  
print("1.0, cmpBuf: ", cmpBuf, cmpBytes)
--print("1.0, LZ4_decompress_safe_continue: ", LZ4_decompress_safe_continue)
            local decBytes = lz4lib.LZ4_decompress_safe_continue(lz4StreamDecode, cmpBuf, decPtr, cmpBytes, MESSAGE_MAX_BYTES);

--print("decBytes: ", decBytes)
            if (decBytes <= 0) then
                break;
            end

--print("1.1")  
            decOffset = decOffset + decBytes;
            outFp:write(decPtr, decBytes);

            -- Wraparound the ringbuffer offset
            if (decOffset >= DEC_BUFFER_BYTES - MESSAGE_MAX_BYTES) then
                decOffset = 0;
            end
        --end
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
    --do
        inpFp = StdFile:new(lz4Filename, "rb");
        outFp = StdFile:new(decFilename, "wb");

        test_decompress(outFp, inpFp);
    --end

    return 0;
end

main(#arg, arg)

