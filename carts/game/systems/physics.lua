-- needed
-- SV_ClipToLinks : closest hit using collision map
-- SV_ClipMoveToEntity
-- SV_MoveBounds: create enclosing move (with an offset!!)
-- SV_Move: returns 
-- SV_RecursiveHullCheck = bsp.ray_bsp_intersect

-- SV_PushEntity
-- Does not change the entities velocity at all

local maths = require("engine.maths3d")
local conf = require("game_conf")

return function(world, vm, collisionMap)

	local function ent_tostring(ent)
		return "ent: "..ent.classname.."\n origin: "..v_tostring(ent.origin).."\n"..v_tostring(ent.absmins).." x "..v_tostring(ent.absmaxs)
	end

	local function testEntityPosition(ent)
		-- 
		local mins,maxs=
			v_add(ent.origin,ent.mins),
			v_add(ent.origin,ent.maxs)
		local touches = collisionMap:touches(v_add(mins,{1,1,1},-8), v_add(maxs,{1,1,1},8), ent)
		local trace = collisionMap:hitscan(ent.mins,ent.maxs,ent.origin,ent.origin,{},touches,ent)

		if trace and (trace.start_solid or trace.all_solid) then
			-- printh("invalid position: "..ent_tostring(trace.ent))
			return true
		end
		return false
	end


	-- SV_Push
	local function push(pusher, move)
		-- collect touching entities (with some buffer)
		local mins=v_add(v_add(pusher.absmins, move),{1,1,1},-8)
		local maxs=v_add(v_add(pusher.absmaxs, move),{1,1,1},8)

		local pushorig = v_clone(pusher.origin)

		-- move the pusher to it's final position
		pusher.origin = v_add(pusher.origin, move) 

		--SV_LinkEdict (pusher, false)
		collisionMap:register(pusher)
		
		-- see if any solid entities are inside the final position
		local moved={}
		local touches = collisionMap:touches(mins, maxs, pusher, true)		
		for i=1,#touches do
			local check=touches[i]
			
			if check.free or check.MOVETYPE_PUSH or check.MOVETYPE_NONE or check.MOVETYPE_NOCLIP then
				goto continue
			end

			-- printh("checking: "..check.classname.." ground: "..tostring(check.on_ground==pusher))

			--[[
			pusher.SOLID_BSP = nil
			local block = testEntityPosition(check)
			pusher.SOLID_BSP = true
			if not block then
				goto continue
			end
			]]
			
			-- if the entity is standing on the pusher, it will definately be moved
			if check.on_ground ~= pusher then
				-- outside of move box?
				if check.absmins[1] >= maxs[1]
				or check.absmins[2] >= maxs[2]
				or check.absmins[3] >= maxs[3]
				or check.absmaxs[1] <= mins[1]
				or check.absmaxs[2] <= mins[2]
				or check.absmaxs[3] <= mins[3] then
					--printh(check.classname.." off path")
					goto continue
				end

				-- see if the ent's bbox is inside the pusher's final position
				if not testEntityPosition(check) then
					--printh(check.classname.." in path but clear")
					goto continue
				end
			end

			-- record start position			
			moved[check] = v_clone(check.origin)

			-- try moving the contacted entity 
			check.origin = v_add(check.origin, move)
			--printh("moving "..check.classname.." from: "..v_tostring(moved[check]).." to: "..v_tostring(check.origin))
			
			if not testEntityPosition(check) then
				-- printh(">>pushed")
				-- pushed ok
				collisionMap:register(check)
				goto continue
			end

			-- if it is ok to leave in the old position, do it
			-- occurs when entity blocked by something else
			check.origin = moved[check]
			if not testEntityPosition(check) then
				-- printh("**blocked")
				-- moved back
				moved[check] = nil
				collisionMap:register(check)
				goto continue
			end

			-- if it is still inside the pusher, block
			-- todo: wtf???
			if check.mins[1] == check.maxs[1] then
				collisionMap:register(check)
				goto continue
			end

			-- solid trigger???
			if check.SOLID_NOT or check.SOLID_TRIGGER then
				-- corpse						
				check.mins[1] = 0
				check.mins[2] = 0
				check.maxs = v_clone(check.mins)
				collisionMap:register(check)
				goto continue
			end
			
			-- failed move
			-- printh("!!!! rollback move !!!")
			pusher.origin = pushorig
			collisionMap:register(pusher)

			-- if the pusher has a "blocked" function, call it
			--  otherwise, just stay in place until the obstacle is gone
			vm:call(pusher,"blocked", check)
			
			-- move back any entities we already moved
			for ent,orig in pairs(moved) do
				ent.origin = orig
				collisionMap:register(ent)

				-- assert(not testEntityPosition(ent),"stuck @"..ent_tostring(ent))
			end

			if true then return false end
::continue::
		end

		return true
	end

	-- SV_PushMove
	local function pushMove(pusher, dt)
		-- nothing to do?
		if pusher.velocity[1]==0 and
			pusher.velocity[2]==0 and
			pusher.velocity[3]==0 then
			pusher.ltime = pusher.ltime + dt
			return
		end

		local move=v_scale(pusher.velocity, dt)

		if push(pusher, move) then
			pusher.ltime = pusher.ltime + dt
		end
	end

	-- SV_Physics_Pusher
	return {
		pusher=function(ent, dt)
			local oldltime = ent.ltime
			local movetime = 0
			local thinktime = ent.nextthink or 0
			-- 
			if thinktime < ent.ltime + dt then
				-- how much time elapsed since
				movetime = thinktime - ent.ltime
				if movetime < 0 then
					movetime = 0
				end
				-- printh("movetime: "..movetime)
			else
				movetime = dt
			end

			if movetime>0 then
				pushMove(ent, movetime) -- advances ent.ltime if not blocked
			end
				
			if thinktime > oldltime and thinktime <= ent.ltime then	
				local oldorg = v_clone(ent.origin)
				ent.nextthink = 0
				vm:call(ent,"think")
				if ent.free then
					return
				end
			
				-- handle snapping of doors/plat to their target position
				local move=make_v(ent.origin, oldorg)
				local l = v_len(move)
				-- printh("Snapping?: "..ent.classname.." by: "..l)
				if l > 1.0/64 then
					printh("Snapping: "..ent.classname.." by: "..l)
					ent.origin = oldorg
					push(ent, move)
				end
			end
		end,
		toss=function(ent, velocity, dt)
			-- gravity
			velocity[3] = velocity[3] - conf.gravity_z*dt
			local move = collisionMap:fly(ent,ent.origin,velocity)
			ent.origin = move.pos
			-- hit other entity?
			if move.ent then
				vm:call(ent,"touch",move.ent)
			end
			-- use corrected velocity
			ent.velocity = v_scale(velocity, 1/dt)
		end,
		bounce=function(ent, velocity, dt)
			local orig = v_clone(ent.origin)
			-- gravity
			velocity[3] = velocity[3] - conf.gravity_z*dt
			local move = collisionMap:fly(ent,ent.origin,velocity)
			ent.origin = move.pos
			-- valid pos?
			if testEntityPosition(ent) then
				-- rollback
				ent.origin = orig
			end

			-- hit other entity?
			if move.ent then
				vm:call(ent,"touch",move.ent)
				-- handle bounce
				velocity=v_scale(v_add(velocity,v_scale(move.n,-2*v_dot(velocity,move.n))),0.8)				
			end
				
			-- use corrected velocity
			ent.velocity = v_scale(velocity, 1/dt)
		end,
		walk=function(ent, velocity, dt)
			-- gravity
			-- todo: less friction not on ground
			velocity[1] = velocity[1] * 0.8
			velocity[2] = velocity[2] * 0.8
			velocity[3] = velocity[3] - 1 
			-- check next position 
			local vn,vl=v_normz(velocity)      
			local on_ground = ent.on_ground
			if vl>0.1 then
				local move = collisionMap:slide(ent,ent.origin,velocity)   
				on_ground = move.on_ground
				if on_ground and move.on_wall and move.fraction<1 then
					local up_move = collisionMap:slide(ent,v_add(ent.origin,{0,0,18}),velocity) 
					-- largest distance?
					if not up_move.invalid and up_move.fraction>move.fraction then
						move = up_move
					end
				end
				ent.origin = move.pos
				velocity = move.velocity                        

				-- trigger touched items
				for other_ent in pairs(move.touched) do
					vm:call(other_ent,"touch",ent)
				end                               
			else
				velocity = {0,0,0}
			end
			-- "debug"
			ent.on_ground = on_ground                    

			-- use corrected velocity
			ent.velocity = v_scale(velocity, 1/dt)
		end,
		unstuck=function(ent)
			return not testEntityPosition(ent)
		end
	}
end