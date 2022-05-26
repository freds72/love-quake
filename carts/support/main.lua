local graphics	= love.graphics
local mouse		= love.mouse
--local lume		= require 'lume'

local playerX		= 128
local playerY		= 128
local playerAngle	= 0
local playerSpeed	= 64

local FOV			= math.pi / 2
local cameraDist	= math.cos(FOV / 2)

local cell_size		= 32
local mapSizeX		= 32
local mapSizeY		= 32

local w, h			= graphics.getWidth(), graphics.getHeight()

local map =
{
1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
1,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
1,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
1,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1,
1,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
}


local keystate = { x = 0, y = 0, a = 0 }

function love.load()
	graphics.setPointSize(4)

end

function love.update(dt)
	playerX		= playerX + (keystate.y * math.cos(playerAngle) + keystate.x * math.cos(playerAngle +  math.pi / 2)) * dt * playerSpeed
	playerY		= playerY + (keystate.y * math.sin(playerAngle) + keystate.x * math.sin(playerAngle +  math.pi / 2)) * dt * playerSpeed

--	playerAngle	= lume.angle(playerX, playerY, mouse.getX(), mouse.getY())
	playerAngle	= playerAngle + keystate.a * dt * 4
	if(playerAngle < 0) then playerAngle = 2 * math.pi end
	if(playerAngle > 2 * math.pi) then playerAngle = 0 end

end

function love.keypressed(k)
	keystate.x = keystate.x + (int(k == 'd') - int(k == 'a'))
	keystate.y = keystate.y + (int(k == 'w') - int(k == 's'))
	keystate.a = keystate.a + (int(k == 'e') - int(k == 'q'))

	if k == 'escape' then love.event.quit() end
end

function love.keyreleased(k)
	keystate.x = keystate.x - (int(k == 'd') - int(k == 'a'))
	keystate.y = keystate.y - (int(k == 'w') - int(k == 's'))
	keystate.a = keystate.a - (int(k == 'e') - int(k == 'q'))

end

function love.draw()
	for x = 0, w-1 do
		local rayAngle		= playerAngle + math.atan2(x - w/2,w/2)		
		local d = math.sqrt((x - w/2)*(x - w/2)+(w/2)*(w/2))/128
		local lineHeight	= d*h / dda(playerX / cell_size, playerY / cell_size, rayAngle, map)

		local drawStart, drawEnd = (-lineHeight / 2 + h / 2), (lineHeight / 2 + h / 2)
		if(drawStart < 0) then drawStart = 0 end
		if(drawEnd >= h) then drawEnd = h - 1 end

		graphics.line(x, drawStart, x, drawEnd)
	end

end

function dda(posX, posY, angle, map)
 	local distDeltaX	= math.abs(1 / math.cos(angle))
	local distDeltaY	= math.abs(1 / math.sin(angle))
	-- local distDeltaX	= math.sqrt(1 + math.pow(math.sin(angle), 2) / math.pow(math.cos(angle), 2))
	-- local distDeltaY	= math.sqrt(1 + math.pow(math.cos(angle), 2) / math.pow(math.sin(angle), 2))
--	if math.cos(angle) == 0 then distDeltaX = math.pow(2, 63) end
--	if math.sin(angle) == 0 then distDeltaY = math.pow(2, 63) end
	local mapX, mapY	= math.floor(posX), math.floor(posY)
	local side

	local stepX, stepY
	local sideDistX, sideDistY

	if(math.cos(angle) < 0) then
		stepX		= -1
		sideDistX	= (posX - mapX) * distDeltaX

	else
		stepX		= 1
		sideDistX	= ((mapX + 1) - posX) * distDeltaX

	end

	if(math.sin(angle) < 0) then
		stepY		= -1
		sideDistY	= (posY - mapY) * distDeltaY

	else
		stepY		= 1
		sideDistY	= ((mapY + 1) - posY) * distDeltaY

	end

	local maxDistance	= 2000
	local curDistance	= 0
	while curDistance < maxDistance do
		if(sideDistX < sideDistY) then
			sideDistX	= sideDistX + distDeltaX
			curDistance = sideDistX
			mapX		= mapX + stepX
			side		= 0

		else
			sideDistY	= sideDistY + distDeltaY
			curDistance = sideDistY
			mapY		= mapY + stepY
			side		= 1

		end

		if map[mapX + mapY * mapSizeX] then
			if map[mapX + mapY * mapSizeX] > 0 then
				if(side == 0) then
					graphics.setColor(1,1,1)
					--return curDistance
					return sideDistX - distDeltaX

				else
					graphics.setColor(0.8,0.8,0.8)
					--return curDistance
					return sideDistY - distDeltaY

				end

--				return {posX + math.cos(angle) * curDistance, posY + math.sin(angle) * curDistance}
			end
		end
	end

	return curDistance
end

function int(b) return b and 1 or 0 end
