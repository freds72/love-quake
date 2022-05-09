-- https://github.com/dmabrothers/fblove
local function fblove(w,h,disable)
    ---------init-----------------------
    local ffi=require 'ffi'
    local width,heigh=w,h 
    local imagedata= 0--love.image.newImageData(width,heigh)
    local image    = 0--love.graphics.newImage(imagedata,{linear=true, mipmaps=false})
    local ptr      = 0--imagedata:getPointer()
    ffi.cdef[[
    typedef struct { uint8_t r, g, b, a; } rgba_pixel;
    ]]
    local buf={}
    local bufrgba={}
  
    local bgcolorptr8=ffi.new('uint8_t[4]',0x00)
    local bgcolorptr=ffi.cast("uint32_t *",bgcolorptr8)
    local bgcolor=0xFF000000
    local bg=0--ffi.new('uint32_t[?]',width,bgcolor)
    
    ----------fb functions--------------
    local function init (wd,hg)
      width,heigh=wd,hg 
      for i=1,#buf do
        buf[i]=nil
        bufrgba[i]=nil
      end
      imagedata=love.image.newImageData(width,heigh)
      image    = love.graphics.newImage(imagedata,{linear=true, mipmaps=false})  
      image:setFilter('nearest','nearest')
      ptr      = imagedata:getPointer()
      buf[0]=ffi.cast("uint32_t *",ptr)
      bufrgba[0]=ffi.cast('rgba_pixel *',ptr)
      for i=1,heigh-1 do
          buf[i]=buf[0]+width*i
          bufrgba[i]=bufrgba[0]+width*i
      end
      
      bg=ffi.new('uint32_t[?]',width,bgcolor)
      collectgarbage('collect')
    end
    
    
    local function fill(color)
    if color then for i=0,width-1 do bg[i]=color end   end
    for i=0,heigh-1 do ffi.copy(buf[i],bg,width*4) end
    end
  
    local function fill2(color)
    local  c= color or bgcolor  
    for i=0,width*heigh-1 do buf[0][i]=c end
    end
    
    local function refresh()
      image:replacePixels(imagedata)
    end
    
    local function draw(x,y,sc)
      x=x or 0    y=y or 0   sc=sc or 1
      love.graphics.draw(image,x,y,0,sc,sc)
    end
    
    
    -----------love.graphics-----------
  
    local function g_setBackgroundColor(r, g, b, a ) --or table RGBA
      local a=a or 0xFF
      if not g then bgcolorptr[0]=r 
        else bgcolorptr8[0]=r bgcolorptr8[1]=g bgcolorptr8[2]=b bgcolorptr8[3]=a  
      end
    bgcolor =bgcolorptr[0] 
    for i=0,width-1 do bg[i]=bgcolor end
    end
    
  
    --------------------------------
    local function dummy() end
    
     if not disable then init(w,h)
     else init,fill,refresh,draw,g_setBackgroundColor=dummy,dummy,dummy,dummy,dummy
     end
    
    return {buf=buf,bufrgba=bufrgba,
  
            fill=fill,
            reinit=init,
            refresh=refresh,
            draw=draw,
            setbg=g_setBackgroundColor,
           }
  end
  
  return fblove