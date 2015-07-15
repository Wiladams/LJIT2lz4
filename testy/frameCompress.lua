-- LZ4frame API example : compress a file
package.path = package.path..";../?.lua"

local ffi = require("ffi")

local lz4frame =  require("lz4frame_ffi")()
local stdlib = require("stdlib")()



local BUF_SIZE = (16*1024);
local LZ4_HEADER_SIZE = 19;
local LZ4_FOOTER_SIZE = 4;

local lz4_preferences = LZ4F_preferences_t( 
	{ LZ4F_max256KB, LZ4F_blockLinked, LZ4F_noContentChecksum, LZ4F_frame, 0, { 0, 0 } },
	0,   -- compression level
	0,   -- autoflush
	{ 0, 0, 0, 0 }  -- reserved, must be set to 0
)

local function compress_file(infile, outfile)
	local size_in = 0;
	local size_out = 0;

	local ctx = ffi.new("struct LZ4F_cctx_s *[1]");

	local r = LZ4F_createCompressionContext(ctx, LZ4F_VERSION);
	if (LZ4F_isError(r) ~= 0) then
		printf("Failed to create context: error %u\n", tonumber(r));
		return 1, size_in, size_out;
	end
	
	ffi.gc(ctx[0], LZ4F_freeCompressionContext);

	local size, n, k; 
	local count_in = 0 
	local count_out; 
	local offset = 0; 
	local frame_size;
	local err = nil;
		r = 1;

	local src = ffi.new("char [?]", BUF_SIZE);
	if (nil == src) then
		printf("Not enough memory\n");
		return r, size_in, size_out;
	end

	frame_size = LZ4F_compressBound(BUF_SIZE, lz4_preferences);
	size =  frame_size + LZ4_HEADER_SIZE + LZ4_FOOTER_SIZE;
	local buf = ffi.new("char [?]", size);
	if (buf == nil) then
		printf("Not enough memory");
		return r, size_in, size_out;
	end

	 
	n = LZ4F_compressBegin(ctx[0], buf, size, lz4_preferences);
	count_out = n
	offset = n

	if (LZ4F_isError(n) ~= 0) then
		printf("Failed to start compression: error %u\n", tonumber(n));
		return r, size_in, size_out;
	end

	printf("Buffer size is %u bytes, header size %u bytes\n", tonumber(size), tonumber(n));

	while (true) do
		k, err = infile:read(src, BUF_SIZE);
		print("k, err: ", k, err)
		if (not k) then
			break;
		end

		count_in = count_in + k;

		n = LZ4F_compressUpdate(ctx[0], ffi.cast("void *", ffi.cast("intptr_t",buf) + offset), size - offset, src, k, nil);
		if (LZ4F_isError(n) ~= 0) then
			printf("Compression failed: error %u\n", tonumber(n));
			return r, size_in, size_out;
		end

		offset = offset + n;
		count_out = count_out + n;
		if (size - offset < frame_size + LZ4_FOOTER_SIZE) then
			printf("Writing %u bytes\n", tonumber(offset));

			k = outfile:write(buf, offset);
			if (k < offset) then
				if (ferror(out) ~= 0) then
					printf("Write failed\n");
				else
					printf("Short write\n");
				end

				return r, size_in, size_out;
			end

			offset = 0;
		end
	end

	n = LZ4F_compressEnd(ctx[0], ffi.cast("void *", ffi.cast("intptr_t",buf) + offset), size - offset, nil);
	if (LZ4F_isError(n) ~= 0) then
		printf("Failed to end compression: error %u", tonumber(n));
		return r, size_in, size_out;
	end

	offset = offset + n;
	count_out = count_out + n;
	printf("Writing %u bytes\n", tonumber(offset));

	k = outfile:write(buf, offset);
	if (k < offset) then
		if (ferror(out) ~= 0) then
			printf("Write failed");
		else
			printf("Short write");
		end

		return r, size_in, size_out;
	end

	size_in = count_in;
	size_out = count_out;
	r = 0;
 
	return r, size_in, size_out;
end

local function compress(input, output)

	local r = 1;

	if (output == nil) then
		output = input..".lz4"
	end

	local infile, err = StdFile(input, "rb");
	if err then
		fprintf(io.stderr, "Failed to open input file %s: %s\n", input, err);
		return r;
	end

	local outfile, err = StdFile(output, "wb")
	if err then
		fprintf(io.stderr, "Failed to open output file %s: %s\n", output, err);
		return r;
	end

	local size_in = 0
	local size_out = 0
	r, size_in, size_out = compress_file(infile, outfile);
	if (r == 0) then
		printf("%s: %d => %d bytes, %3.2f\n",
		       input, tonumber(size_in), tonumber(size_out),
		       tonumber((tonumber(size_out) / tonumber(size_in)) * 100));
	end

	return r;
end


local function main(argc, argv)
	print("#arg: ", argc)
	if (argc < 1 or argc > 2) then
		fprintf(io.stderr, "Syntax: %s <input> <output>\n", argv[0]);
		return -1;
	end

	return compress(argv[1], argv[2]);
end

main(#arg, arg)
