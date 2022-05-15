local ffi=require("ffi")
local lt=love.timer

function bench(fn,n,...)
    local t0=lt.getTime()
    for i=1,n do
        fn(i,...)
    end
    local t1=lt.getTime()
    print("Total time: "..(t1-t0).." FPS:"..(1/(t1-t0)))
end

local _pool = ffi.new("float[?]",512)
local _vector = ffi.new("float[3]")

local _pool_lua = {}
local _vector_lua = {1,2,3}
for i=1,512 do
    _pool_lua[i]=0
end

local function ffi_iterate(k)
    local ptr,n=0,k%512
    for i=0,511 do
        _pool[i] = _pool[n]/2
    end
end
local function lua_iterate(k)
    local n=(k%512)+1
    for i=1,512 do
        _pool_lua[i] = _pool_lua[n]/2
    end
end

local function ffi_dot(k)
    return _pool[0]*_vector[0] + _pool[1]*_vector[1] + _pool[2]*_vector[2]
end

local function lua_dot(k)
    return 
        _pool_lua[1]*_vector_lua[1] + 
        _pool_lua[2]*_vector_lua[2] + 
        _pool_lua[3]*_vector_lua[3]
end

print("JIT: "..tostring(jit.status()))
for i=1,10 do
    print("-----------"..i.."---------")
    bench(ffi_dot, 10000000)

    bench(lua_dot, 10000000)
end

