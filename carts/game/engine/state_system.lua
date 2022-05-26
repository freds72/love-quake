local _update_state,_draw_state
return {        
    -- install next state
    -- note: won't be active before next frame
    next=function(self,fn,...)
        local u,d,i=fn(...)
        -- ensure update/draw pair is consistent
        _update_state=function()
            -- init function (if any)
            if i then i() end
            -- 
            _update_state,_draw_state=u,d
            -- actually run the update
            u()
        end
    end,
    update=function()
        if _update_state then _update_state() end
    end,
    draw=function()
        if _draw_state then _draw_state() end
    end
}
