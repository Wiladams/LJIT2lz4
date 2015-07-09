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
FILE *fopen(const char *filename, const char *mode);
size_t fwrite(const void *ptr, size_t size, size_t nmemb, FILE *stream);
int ferror(FILE *stream);
size_t fread(void *ptr, size_t size, size_t nmemb, FILE *stream);

]]

local exports = {
	free = ffi.C.free;
	malloc = ffi.C.malloc;

	-- file handling
	fclose = ffi.C.fclose;
	fopen = ffi.C.fopen;
	fread = ffi.C.fread;
	fwrite = ffi.C.fwrite;
	ferror = ffi.C.ferror;

	-- string handling
	strcpy = ffi.C.strcpy;
	strlen = ffi.C.strlen;	
}

setmetatable(exports, {
	__call = function(self, ...)
		for k,v in pairs(exports) do
			_G[k] = v;
		end
	end,
})

return exports
