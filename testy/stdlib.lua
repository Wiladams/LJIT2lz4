local ffi = require("ffi")

ffi.cdef[[
struct _IO_FILE;

typedef struct _IO_FILE FILE;
]]



ffi.cdef[[
void * malloc(const size_t size);
void free(void *);

char *strcpy(char *dest, const char *src);
size_t strlen(const char *);

// file operations
int fclose(FILE *stream);
int fflush(FILE *stream);
FILE *fopen(const char *filename, const char *mode);
size_t fwrite(const void *ptr, size_t size, size_t nmemb, FILE *stream);
int ferror(FILE *stream);
size_t fread(void *ptr, size_t size, size_t nmemb, FILE *stream);

char *strerror(int  errnum );
]]

--[[
	Standard file stream interface
--]]
local StdFile = {}
setmetatable(StdFile, {
	__call = function(self, ...)
		return self:new(...);
	end,
})

local StdFile_mt = {
	__index = StdFile;
}

function StdFile.init(self, handle)
	local obj = {
		Handle = handle;
	}
	setmetatable(obj, StdFile_mt);

	return obj;
end

function StdFile.new(self, filename, mode)
	mode = mode or "rb";
	local handle = ffi.C.fopen(filename, mode);
	if nil == handle then
		local str = ffi.C.strerror(ffi.errno());
		if nil == str then
			return nil;
		end

		return nil, ffi.string(str);
	end
	ffi.gc(handle, ffi.C.fclose);

	return self:init(handle);
end

function StdFile.flush(self)
	ffi.C.fflush(self.Handle)
end

function StdFile.write(self, buff, size)
	local res = ffi.C.fwrite(buff, 1, size, self.Handle);
	if res == size then
		return size;
	end

	-- error occured
	return false, tostring(ffi.C.ferror(self.Handle));
end

function StdFile.read(self, buff, size)
	local res = ffi.C.fread(buff, 1, size, self.Handle);
print("StdFile.read: ", size, res)

	if res > 0 then
		return res;
	end

	-- error occured
	return false, tostring(ffi.C.ferror(self.Handle));
end


local exports = {
	free = ffi.C.free;
	malloc = ffi.C.malloc;

	-- file handling
	fclose = ffi.C.fclose;
	fflush = ffi.C.fflush;
	fopen = ffi.C.fopen;
	fread = ffi.C.fread;
	fwrite = ffi.C.fwrite;
	ferror = ffi.C.ferror;

	-- string handling
	strcpy = ffi.C.strcpy;
	strlen = ffi.C.strlen;	

	-- Classes
	StdFile = StdFile;
}

setmetatable(exports, {
	__call = function(self, ...)
		for k,v in pairs(exports) do
			_G[k] = v;
		end
	end,
})

return exports
