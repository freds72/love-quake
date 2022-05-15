local t=0
function _update()
    t = t+1
end

function _draw()
    cls()

    -- printh("pixels!")

    for i=1,256 do
        pset(rnd(480),rnd(270),rnd(65535))
    end
    
    --[[
    for i=1,10 do
        print("this is working:"..i.." @"..t,64,64,16)
        flip()
    end
    ]]
end
