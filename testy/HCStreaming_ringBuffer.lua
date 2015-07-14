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


local    MESSAGE_MAX_BYTES   = 1024;
local    RING_BUFFER_BYTES   = 1024 * 8 + MESSAGE_MAX_BYTES;
local    DEC_BUFFER_BYTES    = RING_BUFFER_BYTES + MESSAGE_MAX_BYTES;   -- Intentionally larger to test unsynchronized ring buffers
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

    return 1, talias.intValue;
end

local function read_bin(fp, array, arrayBytes)
    return fp:read(array, arrayBytes);
end

local inpBuf = ffi.new("char[?]",RING_BUFFER_BYTES);

local function test_compress(outFp, inpFp)

    local lz4Stream = LZ4_createStreamHC();
    ffi.gc(lz4Stream, LZ4_freeStreamHC);

    local inpOffset = 0;

    while (true) do
    
        -- Read random length ([1,MESSAGE_MAX_BYTES]) data to the ring buffer.
        local inpPtr = ffi.cast("char *", inpBuf) + inpOffset;
        local randomLength = rand(1, MESSAGE_MAX_BYTES);
        local inpBytes = read_bin(inpFp, inpPtr, randomLength);
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
            write_bin(outFp, cmpBuf, cmpBytes);

            inpOffset = inpOffset + inpBytes;

            -- Wraparound the ringbuffer offset
            if (inpOffset >= RING_BUFFER_BYTES - MESSAGE_MAX_BYTES) then
                inpOffset = 0;
            end
        end
    end

    write_int32(outFp, 0);
end


local function test_decompress(outFp, inpFp)

    --local decBuf = ffi.new("char[?]", DEC_BUFFER_BYTES);
    local decBuf = malloc(DEC_BUFFER_BYTES)
    local decOffset = 0;
    local lz4StreamDecode = LZ4_createStreamDecode();

    while(true) do
    
        local cmpBytes = 0;
        local cmpBuf = ffi.new("char[?]", maxDstBytes);
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
print("next section")
        --do
            local decPtr = ffi.cast("char *", decBuf) + decOffset;
print("1.0, offset: ", decOffset, decBuf, decPtr)  
print("1.0, cmpBuf: ", cmpBuf, cmpBytes)
print("1.0, LZ4_decompress_safe_continue: ", LZ4_decompress_safe_continue)
            local decBytes = LZ4_decompress_safe_continue(lz4StreamDecode, cmpBuf, decPtr, cmpBytes, MESSAGE_MAX_BYTES);

print("decBytes: ", decBytes)
            if (decBytes <= 0) then
                break;
            end

print("1.1")  
            decOffset = decOffset + decBytes;
            outFp:write(decPtr, decBytes);

            -- Wraparound the ringbuffer offset
            if (decOffset >= DEC_BUFFER_BYTES - MESSAGE_MAX_BYTES) then
                decOffset = 0;
            end
        --end
    end

end


-- Compare 2 files content
-- return 0 if identical
-- return ByteNb>0 if different
local function compare(f0, f1)

    local result = 1;

    while (true) do
    
        local b0 = ffi.new("char[65536]");
        local b1 = ffi.new("char[65536]");
        local r0 = f0:read(b0, ffi.sizeof(b0));
        local r1 = f1:read(b1, ffi.sizeof(b1));

        if ((r0==0) and (r1==0)) then
            return 0;   -- success
        end

        if (r0 ~= r1) then
            local smallest = r0;
            if (r1<r0) then
                smallest = r1;
            end
            result = result + smallest;
            break
        end

        if (0 ~= memcmp(b0, b1, r0)) then
        
            local errorPos = 0;
            while ((errorPos < r0) and (b0[errorPos]==b1[errorPos])) do
                errorPos = errorPos + 1;
            end

            result = result + errorPos;
            break
        end

        result = result + ffi.sizeof(b0);
    end

    return tonumber(result);
end


local function main(argc, argv)

    local fileID = 1;
    local pause = false;
    local filename = argv[1] or "./dummy.txt";

--[[
    if (argc < 1) then
        printf("Please specify input filename\n");
        return 0;
    end
--]]

    if (argv[1] == "-p") then 
        pause = true
        fileID = 2
    end

    local inpFilename = filename;
    local lz4Filename = string.format("%s.lz4s-%d", filename, 9);
    local decFilename = string.format("%s.lz4s-%d.dec", filename, 9);

    printf("input   = [%s]\n", inpFilename);
    printf("lz4     = [%s]\n", lz4Filename);
    printf("decoded = [%s]\n", decFilename);

    -- compress
    do
        inpFp, errstr = StdFile(inpFilename, "rb");
  print("inpFp, err: ", inpFp, errstr);      
        outFp, errstr = StdFile(lz4Filename, "wb");

        test_compress(outFp, inpFp);

        inpFp:close();
        outFp:close();
    end
    

    -- decompress
    do
        inpFp = StdFile(lz4Filename, "rb");
        outFp = StdFile(decFilename, "wb");

        print(pcall(test_decompress(outFp, inpFp)));

        inpFp:close();
        outFp:close();
    end
    

    -- verify
    
    inpFp = StdFile(inpFilename, "rb");
    decFp = StdFile(decFilename, "rb");

    local cmp = compare(inpFp, decFp);
    if(0 == cmp) then
        printf("Verify : OK\n");
    else
        printf("Verify : NG : error at pos %u\n", cmp-1);
    end
    

    if (pause) then
        printf("Press enter to continue ...\n");
        getchar();
    end

    return 0;
end

main(#arg, arg)

