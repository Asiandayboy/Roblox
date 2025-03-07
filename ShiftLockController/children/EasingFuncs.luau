--!strict
type EasingFuncType = (startPos: Vector3, targetPos: Vector3, t: number) -> Vector3

local EasingFuncs: { [string]: EasingFuncType } = {

	Lerp = function(startPos: Vector3, targetPos: Vector3, t: number)
		return startPos + (targetPos - startPos) * t
	end,
	
	Spring1 = function(startPos: Vector3, targetPos: Vector3, t: number)
		local p0 = startPos
		local p1 = targetPos
		local v0 = Vector3.zero
		local s = 10
		local d = .7
		
		local time = s * t
		local d2 = d * d
		
		local h, si, co
		h = math.sqrt(1 - d2)
		local ep = math.exp(-d * time) / h
		co, si = ep * math.cos(h * time), ep * math.sin(h * time)
		
		local a0 = h * co + d * si
		local a1 = 1 - (h * co + d * si)
		local a2 = si / s

		local position = a0 * p0 + a1 * p1 + a2 * v0
		return position
	end,
	
	Spring2 = function(startPos: Vector3, targetPos: Vector3, t: number)
		local p0 = startPos
		local p1 = targetPos
		local v0 = Vector3.zero
		local s = 15
		local d = .7

		local time = s * t
		local d2 = d * d

		local h, si, co
		h = math.sqrt(1 - d2)
		local ep = math.exp(-d * time) / h
		co, si = ep * math.cos(h * time), ep * math.sin(h * time)

		local a0 = h * co + d * si
		local a1 = 1 - (h * co + d * si)
		local a2 = si / s

		local position = a0 * p0 + a1 * p1 + a2 * v0
		return position
	end,
	
	Spring3 = function(startPos: Vector3, targetPos: Vector3, t: number)
		local p0 = startPos
		local p1 = targetPos
		local v0 = Vector3.zero
		local s = 10
		local d = .7

		local time = s * t
		local d2 = d * d

		local h, si, co
		h = 1
		local ep = math.exp(-d * time) / h
		co, si = ep, ep * time

		local a0 = h * co + d * si
		local a1 = 1 - (h * co + d * si)
		local a2 = si / s

		local position = a0 * p0 + a1 * p1 + a2 * v0
		return position
	end,
}

return EasingFuncs

