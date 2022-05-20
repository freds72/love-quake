local FrameBuffer={}
local ffi = require("ffi")
local fb = require("lib.fblove_strip")

local display, len = fb(480, 270), 480 * 270 * ffi.sizeof("uint32_t")
local vid_ptr = display.buf[0]

function FrameBuffer:present(x,y,data,pal,scale)
    for i=0,480*270-1 do
        vid_ptr[i]=pal[data[i]]
    end

    --ffi.copy(vid_ptr,data,len)
    display.refresh()
    display.draw(x,y,scale)
end

return FrameBuffer