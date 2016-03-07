package.path = package.path..";../?.lua"

local ffi = require("ffi")
local lz4 = require("lz4_ffi")()
local testutils = require("testutils")()
local rand = math.random

local    MESSAGE_MAX_BYTES   = 1024;
local    RING_BUFFER_BYTES   = 1024 * 8 + MESSAGE_MAX_BYTES;
local    DECODE_RING_BUFFER  = RING_BUFFER_BYTES + MESSAGE_MAX_BYTES;   -- Intentionally larger, to test unsynchronized ring buffers


local inpBuf = ffi.new("char[?]", RING_BUFFER_BYTES);

local function test_compress(outFp, inpFp)

    local lz4Stream_body = ffi.new("LZ4_stream_t", { 0 });
    local lz4Stream = lz4Stream_body;

    local inpOffset = 0;

    local cmpBuf = ffi.new("char [?]", LZ4_COMPRESSBOUND(MESSAGE_MAX_BYTES));

    while(true) do
        -- Read random length ([1,MESSAGE_MAX_BYTES]) data to the ring buffer.
        local inpPtr = ffi.cast("char *",inpBuf) + inpOffset;
        local randomLength = rand(1, MESSAGE_MAX_BYTES);
        local inpBytes = read_bin(inpFp, inpPtr, randomLength);
        
        if (0 == inpBytes) then
            break;
        end

        
        local cmpBytes = LZ4_compress_continue(lz4Stream, inpPtr, cmpBuf, inpBytes);
            
        if(cmpBytes <= 0) then
            break;
        end

        write_int32(outFp, cmpBytes);
        write_bin(outFp, cmpBuf, cmpBytes);

        inpOffset = inpOffset + inpBytes;

        -- Wraparound the ringbuffer offset
        if(inpOffset >= RING_BUFFER_BYTES - MESSAGE_MAX_BYTES) then
            inpOffset = 0;
        end
        
    end

    write_int32(outFp, 0);
end


local decBuf = ffi.new("char[?]", DECODE_RING_BUFFER);

local function test_decompress(outFp, inpFp)
    local   decOffset    = 0;

    LZ4_streamDecode_t lz4StreamDecode_body = { 0 };
    LZ4_streamDecode_t* lz4StreamDecode = &lz4StreamDecode_body;
--[[
    for(;;) {
        int cmpBytes = 0;
        char cmpBuf[LZ4_COMPRESSBOUND(MESSAGE_MAX_BYTES)];

        {
            const size_t r0, cmpBytes = read_int32(inpFp, &cmpBytes);
            if(r0 != 1 || cmpBytes <= 0) break;

            const size_t r1 = read_bin(inpFp, cmpBuf, cmpBytes);
            if(r1 != (size_t) cmpBytes) break;
        }

        {
            char* const decPtr = &decBuf[decOffset];
            const int decBytes = LZ4_decompress_safe_continue(
                lz4StreamDecode, cmpBuf, decPtr, cmpBytes, MESSAGE_MAX_BYTES);
            if(decBytes <= 0) break;
            decOffset += decBytes;
            write_bin(outFp, decPtr, decBytes);

            // Wraparound the ringbuffer offset
            if(decOffset >= DECODE_RING_BUFFER - MESSAGE_MAX_BYTES) decOffset = 0;
        }
    }
--]]
end


local function compare(f0, f1)

    local b0 = ffi.new("char[?]", 65536);
    local b1 = ffi.new("char[?]", 65536);
    local result = 0;

    while(0 == result) do
        local r0 = f0:read(b0, ffi.sizeof(b0));
        local r1 = f1:read(b1, ffi.sizeof(b1));

        result = r0 - r1;

        if(0 == r0 or 0 == r1) then
            break;
        end

        if(0 == result) then
            result = memcmp(b0, b1, r0);
        end
    end

    return result;
end

--[[
int main(int argc, char** argv)
{
    char inpFilename[256] = { 0 };
    char lz4Filename[256] = { 0 };
    char decFilename[256] = { 0 };

    if(argc < 2) {
        printf("Please specify input filename\n");
        return 0;
    }

    snprintf(inpFilename, 256, "%s", argv[1]);
    snprintf(lz4Filename, 256, "%s.lz4s-%d", argv[1], 0);
    snprintf(decFilename, 256, "%s.lz4s-%d.dec", argv[1], 0);

    printf("inp = [%s]\n", inpFilename);
    printf("lz4 = [%s]\n", lz4Filename);
    printf("dec = [%s]\n", decFilename);

    // compress
    {
        FILE* inpFp = fopen(inpFilename, "rb");
        FILE* outFp = fopen(lz4Filename, "wb");

        test_compress(outFp, inpFp);

        fclose(outFp);
        fclose(inpFp);
    }

    // decompress
    {
        FILE* inpFp = fopen(lz4Filename, "rb");
        FILE* outFp = fopen(decFilename, "wb");

        test_decompress(outFp, inpFp);

        fclose(outFp);
        fclose(inpFp);
    }

    // verify
    {
        FILE* inpFp = fopen(inpFilename, "rb");
        FILE* decFp = fopen(decFilename, "rb");

        const int cmp = compare(inpFp, decFp);
        if(0 == cmp) {
            printf("Verify : OK\n");
        } else {
            printf("Verify : NG\n");
        }

        fclose(decFp);
        fclose(inpFp);
    }

    return 0;
}
--]]

