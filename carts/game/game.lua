local t=84

function _init()
    tiles = {width=2,height=2,ptr={
        [0]=19,24,24,19
    }}
end

function _update()
    t = t+1
end

function _draw()
    cls()

    -- printh("pixels!")
    
    local cc,ss=cos(t/32),sin(t/32)
    line(480/2-96*cc,270/2-96*ss,480/2+96*cc,270/2+96*ss,60)

    local y=270/2+64*sin(t/64)
    for i=0,5 do
        line(0,y+i,479,y+i,(t+i)%64)
    end

    local offset=270/2+32*cos(t/128)
    print("HI world!",offset,offset+1,8)
    print("HI world!",offset,offset,1)

    for y=0, do
        tline3d(tiles,x,128,96-1,64+i,
            0,i/8,1,
            1/8,0,0)
    end
end
