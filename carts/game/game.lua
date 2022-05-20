local t=84

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
end
