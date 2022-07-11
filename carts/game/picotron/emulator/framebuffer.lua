local FrameBuffer={}
local ffi = require("ffi")
local fb = require("lib.fblove_strip")

local display, len = fb(480, 270), 480 * 270
local vid_ptr = display.buf[0]

function FrameBuffer:present(x,y,data,pal,scale)
    for i=0,len-1 do
        --local r=math.min(bit.band(pal[data[i]],0xff)+0x40,0xff)
        -- vid_ptr[i]=bit.bor(r,bit.band(pal[data[i]],0xffffff00))
        vid_ptr[i]=pal[data[i]]
    end

    --ffi.copy(vid_ptr,data,len)
    display.refresh()
    display.draw(x,y,scale)
end

return FrameBuffer