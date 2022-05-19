local t=0

function _update()
    t = t+1
end

function _draw()
    cls()

    -- printh("pixels!")
    
    local cc,ss=cos(time()),sin(time())
    line(480/2-96*cc,270/2-96*ss,480/2+96*cc,270/2+96*ss,84651)

    --[[
    for i=1,10 do
        print("this is working:"..i.." @"..t,64,64,16)
        flip()
    end
    ]]
end
