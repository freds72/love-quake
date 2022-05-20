local t=0

function _update()
    t = t+1
end

function _draw()
    cls()

    -- printh("pixels!")
    
    local cc,ss=cos(t/32),sin(t/32)
    line(480/2-96*cc,270/2-96*ss,480/2+96*cc,270/2+96*ss,84651)

    for i=0,64 do
        -- print("this is working:"..i.." @"..t,64,64,16)
        line(0,i,479,i,i*32)
        --flip()
    end
end
