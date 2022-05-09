local _pool=require("pool")("spans",5,50)
local _spans={}
local function spanfill(x0,x1,y,u,v,w,du,dv,dw,fn)	
	local _pool=_pool
	if x1<0 or x0>480 or x1-x0<0 then
		return
	end

	-- fn = overdrawfill

	local span,old=_spans[y]
	-- empty scanline?
	if not span then
		fn(x0,y,x1,y,u,v,w,du,dv,dw)
		_spans[y]=_pool:pop5(x0,x1,w,dw,-1)
		return
	end

	while span>0 do		
		local s0,s1=_pool[span],_pool[span+1]

		if s0>x0 then
			if s0>x1 then
				-- nnnn
				--       xxxxxx	
				-- fully visible
				fn(x0,y,x1,y,u,v,w,du,dv,dw)
				local n=_pool:pop5(x0,x1,w,dw,span)
				if old then
					-- chain to previous
					_pool[old+4]=n
				else
					-- new first
					_spans[y]=n
				end
				return
			end

			-- nnnn?????????
			--     xxxxxxx
			-- clip + display left
			local x2=s0-1
			local dx=x2-x0
			fn(x0,y,x2,y,u,v,w,du,dv,dw)
			local n=_pool:pop5(x0,x2,w,dw,span)
			if old then 
				_pool[old+4]=n				
			else
				_spans[y]=n
			end
			x0=s0
			--assert(x1-x0>=0,"empty right seg")
			u=u+dx*du
			v=v+dx*dv
			w=w+dx*dw
			-- check remaining segment
			old=n
			goto continue
		elseif s1>=x0 then
			--     ??nnnn????
			--     xxxxxxx	

			--     ??nnnn?
			--     xxxxxxx	
			-- totally hidden (or not!)
			local dx,sdw=x0-s0,_pool[span+3]
			local sw=_pool[span+2]+dx*sdw		
			
			if sw-w<-1e-6 or (sw-w<0.00001 and dw>sdw) then
				--printh(sw.."("..dx..") "..w.." w:"..span.dw.."<="..dw)	
				-- insert (left) clipped existing span as a "new" span
				if dx>0 then
					local n=_pool:pop5(
						s0,
						x0-1,
						_pool[span+2],
						sdw,
						span)
					if old then
						_pool[old+4]=n
					else
						-- new first
						_spans[y]=n
					end
					old=n
				end
				-- middle ("new")
				--     ??nnnnn???
				--     xxxxxxx			
				-- draw only up to s1
				local x2=s1<x1 and s1 or x1
				fn(x0,y,x2,y,u,v,w,du,dv,dw)					
				local n=_pool:pop5(x0,x2,w,dw,span)
				if old then 
					_pool[old+4]=n	
				else
					-- new first
					_spans[y]=n
				end
				
				-- any remaining "right" from current span?
				local dx=s1-x1-1
				if dx>0 then
					-- "shrink" current span
					_pool[span]=x1+1
					_pool[span+2]=_pool[span+2]+(x1+1-s0)*sdw
				else
					-- drop current span
					_pool[n+4]=_pool[span+4]
					span=n
				end					
			end

			if s1>=x1 then
				--     ///////
				--     xxxxxxx	
				return
			end
			--         ///nnn
			--     xxxxxxx
			-- clip incomping segment
			--assert(dx>=0,"empty right (incoming) seg")
			-- 
			local dx=s1+1-x0
			x0=s1+1
			u=u+dx*du
			v=v+dx*dv
			w=w+dx*dw

			--            nnnn
			--     xxxxxxx	
			-- continue + test against other spans
		end
		old=span	
		span=_pool[span+4]
::continue::
	end
	-- new last?
	if x1-x0>=0 then
		fn(x0,y,x1,y,u,v,w,du,dv,dw)
		-- end of spans
		_pool[old+4]=_pool:pop5(x0,x1,w,dw,-1)
	end
end

-- unit tests
local function nop() end
spanfill(32,64,0, 0,0,0, 0,0,0,nop)
spanfill(33,56,0,  0,0,1, 0,0,0,nop)
--spanfill(0,76,0,  0,0,2, 0,0,0,nop)
local span=_spans[0]
while span>0 do
    local s0,s1=_pool[span],_pool[span+1]
    print(s0.." -> "..s1.." (".._pool[span+2]..")")
    span=_pool[span + 4]
end
