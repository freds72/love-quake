## How to launch

- configure game_conf.lua to reflect Quake install
```
    root_path="<path to ID1 folder or local root for custom maps",
```
> install contains player.mdl and v_shot.mdl (copyright ID) to support standalone tests

- launch with the selected map:
```
    &love.exe game q8k e1m3
```

- Game keys:
  - Escape : exit game
  - F11: switch full screen on/off
  - WASD/ZQSD: move
  - space bar: action (open)
  - left mouse button: fire

## How to add custom configuration

Create user_conf.lua in ~/LOVE/picotron. Example

```
return {
  mouse_speed = 0.5
}
```

Supported overrides:

| Property    | Description |
| ----------- | ----------- |
| mouse_speed | mouse acceleration factor |
| root_path   | Path to ID1 Quake folder |
| mod_path | Extra path to load mod assets (takes precedence) |
| progs | list of active game programs |
| gravity_z | Gravity factor (default: 800) |

## How to debug

- Install VSCode extension: https://marketplace.visualstudio.com/items?itemName=tomblind.local-lua-debugger-vscode
- Configure .vscode/launch.json to match local path

```
{
    "version": "0.2.0",
    "configurations": [
      {
        "name": "Debug Love",
        "type": "lua-local",
        "request": "launch",
        "program": {
          "command": "<path to love>/love.exe"
        },
        "args": [
          "game",
          "q8k",
          "start"
        ],
        "cwd": "${workspaceFolder}\\carts",
        "scriptRoots": [
          "${workspaceFolder}\\carts\\game",
          "${workspaceFolder}\\carts\\game\\progs",
          "${workspaceFolder}\\carts\\game\\engine",
          "${workspaceFolder}\\carts\\game\\lib",
          "${workspaceFolder}\\carts\\game\\systems",
          "${workspaceFolder}\\carts\\game\\picotron\\emulator"
        ]
      }
    ]
  }
```

- setup break point in game (note: setting breakpoints in main.lua is not supported)
- Hit F5 to start a session (or debug icon)


