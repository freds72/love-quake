function love.conf(t)
    t.identity = "bsp"                -- The name of the save directory (string)
    t.appendidentity = false            -- Search files in source directory before save directory (boolean)
    t.version = "11.3"                  -- The LÖVE version this game was made for (string)
    t.console = false                    -- Attach a console (boolean, Windows only)
    t.window.title = "Löve Quake"     -- The window title (string)
    t.window.vsync = 1                  -- Vertical sync mode (number)
    t.window.msaa = 0                   -- The number of samples to use with multi-sampled antialiasing (number)
    t.window.display = 1                -- Index of the monitor to show the window in (number)

    -- game key bindings
    t.keys = {
        up = {'w','up'},
        down = {'s','down'},
        left = {'a','left'},
        right = {'d','right'},
        action = {'space'}
    }

    -- alias to global for further use
    _conf = t
end
