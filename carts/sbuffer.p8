pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
-- sbuffer
-- @freds72
-- unit test for span buffer
--
#include poly.lua

function tline3d(x0,y,x1,_,u,v,w,du,dv,dw)
    local s=""
    for i=0,x0-1 do
        s..=" "
    end
    for i=x0,x1 do
        s..=tostr(i%10)
    end
    printh(s)
end

function dump_spans(c)
    local span=_spans[0]
    local s=""

    while span do
        s..="["..span.x0.." -> "..span.x1.."] "
        local w=128*span.w
        line(span.x0,w,span.x1,w+128*(span.x1-span.x0)*span.dw,c or 7)
        span=span.next
    end
    printh(s)
end

function _init()
    cls()
    printh("-----------------------------")

walls={
    {78,127,0,0,0,0.5085,0,0,0.0064},
    --{0,-143,0,0,0,-0.0227,0,0,-0.0204},
    --{66,89,0,0,0,0.4346,0,0,-0.0072},
    --{40,65,0,0,0,0.2654,0,0,0.0064},
    --{0,58,0,0,0,0.233,0,0,-0.0018}
    }
doors={
    {75,98,0,0,0,0.5466,0,0,-0.0107},
    --{63,74,0,0,0,0.4538,0,0,0.007}
    }

    for i=1,#walls do
        spanfill(unpack(walls[i]))    
    end

    dump_spans()
    printh("++++++++++++++++++++++++++")

    for i=1,#doors do
        spanfill(unpack(doors[i]))    
    end
    dump_spans(8)
end