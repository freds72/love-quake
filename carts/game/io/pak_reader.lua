local ffi=require("ffi")
local nfs = require( "lib.nativefs" )
local logging = require("engine.logging")
ffi.cdef[[
    #pragma pack(1)
    
    // pack file structure
    typedef struct
    {
        char	name[56];
        int		filepos, filelen;
    } dpackfile_t;

    typedef struct
    {
        char	identification[4];
        int		infotableofs;
        int		numlumps;
    } dpackheader_t;
]]


local PakReader=function(conf)    
    local root_path=conf.root_path
    assert(root_path,"Missing root_path key configuration")
    -- optional path
    local mod_path=conf.mod_path

    -- reads the given struct name from the byte array
    local function read_directory(cname, info, mem)
        local res = {}
        local sz,ct = ffi.sizeof(cname), ffi.typeof(cname.."*")
        mem = mem + info.infotableofs
        for i=0,info.numlumps-1 do
            res[i] = ffi.cast(ct, mem)
            mem = mem + sz
        end
        --return ffi.cast(cname.."["..n.."]", mem)
        return res
    end

    -- entries cache
    local cache={}
    local pak_id = 0
    while true do
        local filename = root_path.."/pak"..pak_id..".pak"
        local ok, data = pcall(nfs.newFileData, filename)
        if not data then
            break
        end
        local mem = data:getFFIPointer()
        local ptr = ffi.cast("unsigned char*", mem)

        local info = ffi.cast('dpackheader_t*', ptr)
        logging.debug("Found PAK: "..filename.." version:"..ffi.string(info.identification))

        local entries = read_directory("dpackfile_t", info, ptr)

        for i=0,#entries-1 do
            local entry = entries[i]
            if entry.filelen==0 then
                break
            end
            cache[ffi.string(entry.name)] = {
                _ffi_ = data,
                ptr = ptr + entry.filepos
            }
        end
        pak_id = pak_id + 1
    end

    -- get a resource from a pak file
    return {
        open=function(self,resource)
            -- from native file system?
            if mod_path then
                local filename = mod_path.."/"..resource
                local data, err = nfs.newFileData(filename)
                if data then
                    logging.debug("Loading resource from mod path: "..filename)
                    local mem = data:getFFIPointer()
                    local ptr = ffi.cast("unsigned char*", mem)
                    cache[resource] = {
                        _ffi_ = data,
                        ptr = ptr
                    }
                    return ptr
                end
            end
            local entry=cache[resource]
            assert(entry,"Unknown resource: "..resource)
            return entry.ptr
        end
    }
end
return PakReader
