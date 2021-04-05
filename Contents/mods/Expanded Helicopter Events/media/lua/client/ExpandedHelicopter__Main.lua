--GLOBAL_VARIABLES
MAX_XY = 15000
MIN_XY = 2500
ALL_HELICOPTERS = {}

---@class eHelicopter
---@field preflightDistance number
---@field target IsoObject
---@field targetPosition Vector3 @Vector3 "position" of target
---@field state boolean
---@field lastMovement Vector3 @consider this to be velocity (direction/angle and speed/stepsize)
---@field currentPosition Vector3 @consider this a pair of coordinates
---@field lastAnnouncedTime number
---@field announcerVoice string
---@field emitter FMODSoundEmitter | BaseSoundEmitter
---@field ID number
---@field height number
---@field speed number
---@field topSpeedFactor number speed x this = top "speed"
---@field fireSound table sounds for firing
---@field fireImpacts table sounds for fire impact

eHelicopter = {}
eHelicopter.preflightDistance = nil
eHelicopter.target = nil
eHelicopter.targetPosition = nil
eHelicopter.state = nil
eHelicopter.lastMovement = nil
eHelicopter.currentPosition = nil
eHelicopter.lastAnnouncedTime = nil
eHelicopter.announcerVoice = nil
eHelicopter.emitter = nil
eHelicopter.ID = 0
eHelicopter.height = 20
eHelicopter.speed = 0.25
eHelicopter.topSpeedFactor = 3
eHelicopter.fireSound = {"eHeli_fire_single","eHeli_fire_loop"}
eHelicopter.fireImpacts = {"eHeli_fire_impact1", "eHeli_fire_impact2", "eHeli_fire_impact3",  "eHeli_fire_impact4", "eHeli_fire_impact5"}


---Do not call this function directly for new helicopters
---@see getFreeHelicopter instead
function eHelicopter:new()

	local o = {}
	setmetatable(o, self)
	self.__index = self
	table.insert(ALL_HELICOPTERS, o)
	o.ID = #ALL_HELICOPTERS
	
	return o
end


---returns first "unlaunched" helicopter found in ALL_HELICOPTERS -OR- creates a new instance
function getFreeHelicopter()
	for key,_ in ipairs(ALL_HELICOPTERS) do
		---@type eHelicopter heli
		local heli = ALL_HELICOPTERS[key]
		if heli.state == "unlaunched" then
			return heli
		end
	end
	return eHelicopter:new()
end


---These is the equivalent of getters for Vector3
--tostring output of a Vector3: "Vector2 (X: %f, Y: %f) (L: %f, D:%f)"
---@param ShmectorTree Vector3
---@return float x of ShmectorTree
function Vector3GetX(ShmectorTree)
	return string.match(tostring(ShmectorTree), "%(X%: (.-)%, Y%: ")
end


---@param ShmectorTree Vector3
---@return float y of ShmectorTree
function Vector3GetY(ShmectorTree)
	return string.match(tostring(ShmectorTree), "%, Y%: (.-)%) %(")
end


---Initialize Position
---@param targetedPlayer IsoMovingObject | IsoPlayer | IsoGameCharacter
---@param randomEdge boolean true = uses random edge, false = prefers closer edge
function eHelicopter:initPos(targetedPlayer, randomEdge)

	--player's location
	local tpX = targetedPlayer:getX()
	local tpY = targetedPlayer:getY()

	--assign a random spawn point for the helicopter within a radius from the player
	--these values are being clamped to not go passed MIN_XY/MAX edges
	local offset = 500
	local initX = ZombRand(math.max(MIN_XY, tpX-offset), math.min(MAX_XY, tpX+offset))
	local initY = ZombRand(math.max(MIN_XY, tpY-offset), math.min(MAX_XY, tpY+offset))

	if not self.currentPosition then
		self.currentPosition = Vector3.new()
	end

	if randomEdge then
		
		local initPosXY = {initX, initY}
		local randEdge = {MIN_XY, MAX_XY}
		
		--randEdge stops being a list and becomes a random part of itself
		randEdge = randEdge[ZombRand(1,#randEdge)]
		
		--this takes either initX/initY (within initPosXY) and makes it either MIN_XY/MAX (randEdge)
		initPosXY[ZombRand(1, #initPosXY)] = randEdge
		
		self.currentPosition:set(initPosXY[1], initPosXY[2], self.height)
		
		return
	end
	
	--Looks for the closest edge to initX and initY to modify it to be along either MIN_XY/MAX_XY
	--differences between initX and MIN_XY/MAX_XY edge values
	local xDiffToMin = math.abs(initX-MIN_XY)
	local xDiffToMax = math.abs(initX-MAX_XY)
	local yDiffToMin = math.abs(initY-MIN_XY)
	local yDiffToMax = math.abs(initY-MAX_XY)
	--this list uses x/yDifftoMin/Max's values as keys storing their respective corresponding edges
	local xyDiffCorrespondingEdge = {[xDiffToMin]=MIN_XY, [xDiffToMax]=MAX_XY, [yDiffToMin]=MIN_XY, [yDiffToMax]=MAX_XY}
	--get the smallest of the four differences
	local smallestDiff = math.min(xDiffToMin,xDiffToMax,yDiffToMin,yDiffToMax)
	
	--if the smallest is a X local var then set initX to the closer edge
	if (smallestDiff == xDiffToMin) or (smallestDiff == xDiffToMax) then
		initX = xyDiffCorrespondingEdge[smallestDiff]
	else
		--otherwise, set initY to the closer edge
		initY = xyDiffCorrespondingEdge[smallestDiff]
	end

	self.currentPosition:set(initX, initY, self.height)

end


function eHelicopter:isInBounds()

	local h_x = tonumber(Vector3GetX(self.currentPosition))
	local h_y = tonumber(Vector3GetY(self.currentPosition))

	if h_x <= MAX_XY and h_x >= MIN_XY and h_y <= MAX_XY and h_y >= MIN_XY then
		return true
	end

	return false
end

function eHelicopter:getDistanceToTarget()

	local a = Vector3GetX(self.targetPosition) - Vector3GetX(self.currentPosition)
	local b = Vector3GetY(self.targetPosition) - Vector3GetY(self.currentPosition)

	return math.sqrt((a*a)+(b*b))
end


---@param movement Vector3
function eHelicopter:dampen(movement)
	--finds the fraction of distance to target and preflight distance to target
	local distanceCompare = self:getDistanceToTarget() / self.preflightDistance
	--clamp with a max of self.topSpeedFactor and min of 0.1 (10%) is applied to the fraction 
	local dampenFactor = math.max(self.topSpeedFactor, math.min(0.1, distanceCompare))
	--this will slow-down/speed-up eHelicopter the closer/farther it is to the target
	local x_movement = Vector3GetX(movement) * dampenFactor
	local y_movement = Vector3GetY(movement) * dampenFactor

	return movement:set(x_movement,y_movement,self.height)
end

---Sets targetPosition (Vector3) to match target (IsoObject)
function eHelicopter:setTargetPos()
	if not self.target then
		return
	end
	local tx, ty, tz = self.target:getX(), self.target:getY(), self.height

	if not self.targetPosition then
		self.targetPosition = Vector3.new(tx, ty, tz)
	else
		self.targetPosition:set(tx, ty, tz)
	end
	
end


---Aim eHelicopter at it's defined target
---@return Vector3
function eHelicopter:aimAtTarget()

	self:setTargetPos()

	local movement_x = Vector3GetX(self.targetPosition) - Vector3GetX(self.currentPosition)
	local movement_y = Vector3GetY(self.targetPosition) - Vector3GetY(self.currentPosition)

	--difference between target's and current's x/y
	---@type Vector3 local_movement
	local local_movement = Vector3.new(movement_x,movement_y,0)
	--normalize (shrink) the difference
	local_movement:normalize()
	--multiply the difference based on speed
	local_movement:setLength(self.speed)

	return local_movement
end


---@param re_aim boolean recalculate angle to target
---@param dampen boolean adjust speed based on distance to target
function eHelicopter:move(re_aim, dampen)

	---@type Vector3
	local velocity
	
	if re_aim then
		velocity = self:aimAtTarget()

		if not self.lastMovement then
			self.lastMovement = Vector3.new(velocity)
		else
			self.lastMovement:set(velocity)
		end

	else
		velocity = self.lastMovement:clone()
	end

	if dampen then
		velocity = self:dampen(velocity)
	end

	--account for sped up time
	local timeSpeed = getGameSpeed()
	local v_x = Vector3GetX(self.currentPosition)+(Vector3GetX(velocity)*timeSpeed)
	local v_y = Vector3GetY(self.currentPosition)+(Vector3GetY(velocity)*timeSpeed)

	--The actual movement occurs here when the modified `velocity` is added to `self.currentPosition`
	self.currentPosition:set(v_x, v_y, self.height)
	--Move emitter to position - note toNumber is needed for Vector3GetX/Y due to setPos not behaving with lua's pseudo "float"
	self.emitter:setPos(tonumber(v_x),tonumber(v_y),self.height)

	local heliVolume = 50

	if not self.lastAnnouncedTime or self.lastAnnouncedTime <= getTimestamp() then
		heliVolume = heliVolume+20
		self:announce()--"PleaseReturnToYourHomes")
	end


	--virtual sound event to attract zombies
	addSound(nil, v_x, v_y, 0, 250, heliVolume)
	
	self:Report(re_aim, dampen)
end


---@return number, number, number x, y, z of eHelicopter
function eHelicopter:getIsoCoords()
	local ehX, ehY, ehZ = tonumber(Vector3GetX(self.currentPosition)), tonumber(Vector3GetY(self.currentPosition)), self.height
	return ehX, ehY, ehZ
end


---@param targetedPlayer IsoMovingObject | IsoPlayer | IsoGameCharacter random player if blank
function eHelicopter:launch(targetedPlayer)

	if not targetedPlayer then
		--the -1 is to offset playerIDs starting at 0
		local numActivePlayers = getNumActivePlayers()-1
		local randNumFromActivePlayers = ZombRand(numActivePlayers)
		targetedPlayer = getSpecificPlayer(randNumFromActivePlayers)
	end
	
	self.target = targetedPlayer
	self:setTargetPos()
	self:initPos(self.target)
	self.preflightDistance = self:getDistanceToTarget()

	local e_x, e_y, e_z = self:getIsoCoords()

	self.emitter = getWorld():getFreeEmitter(e_x, e_y, e_z)
	self.emitter:playSound("eHelicopter", e_x, e_y, e_z)
	self:chooseVoice()
	self.state = "gotoTarget"
end


---Sets eHelicopter's announcer voice
---@param specificVoice string
function eHelicopter:chooseVoice(specificVoice)

	if not specificVoice then
		local randAnn = ZombRand(1, eHelicopter_announcerCount)
		for k,_ in pairs(eHelicopter_announcers) do
			randAnn = randAnn-1
			if randAnn <= 0 then
				specificVoice = k
				break
			end
		end
	end

	self.announcerVoice = eHelicopter_announcers[specificVoice]
end

---Announces random line if none is provided
---@param specificLine string
function eHelicopter:announce(specificLine)

	if not specificLine then

		local ann_num = ZombRand(1,self.announcerVoice["LineCount"])

		for k,_ in pairs(self.announcerVoice["Lines"]) do
			ann_num = ann_num-1
			if ann_num <= 0 then
				specificLine = k
				break
			end
		end
	end

	local line = self.announcerVoice["Lines"][specificLine]
	local announcePick = line[ZombRand(2,#line)]
	local lineDelay = line[1]

	self.lastAnnouncedTime = getTimestamp()+lineDelay
	self.emitter:playSound(announcePick, tonumber(Vector3GetX(self.currentPosition)), tonumber(Vector3GetY(self.currentPosition)), self.height)
end


function eHelicopter:update()

	--threshold for reaching player should be self.speed * getGameSpeed
	if (self.state == "gotoTarget") and (self:getDistanceToTarget() <= ((self.topSpeedFactor*self.speed)*tonumber(getGameSpeed()))) then
		print("HELI: "..self.ID.." FLEW OVER TARGET".." (x:"..Vector3GetX(self.currentPosition)..", y:"..Vector3GetY(self.currentPosition)..")")
		self.state = "goHome"
		self.target = getSquare(self.target:getX(),self.target:getY(),0)
		self:setTargetPos()
	end

	local lockOn = true
	if self.state == "goHome" then
		lockOn = false
	end

	self:move(lockOn, true)

	if not self:isInBounds() then
		self:unlaunch()
	end
end


function updateAllHelicopters()
	for key,_ in ipairs(ALL_HELICOPTERS) do
		---@type eHelicopter heli
		local heli = ALL_HELICOPTERS[key]

		if heli.state ~= "unlaunched" then
			heli:update()
		end
	end
end


function eHelicopter:unlaunch()
	print("HELI: "..self.ID.." UN-LAUNCH".." (x:"..Vector3GetX(self.currentPosition)..", y:"..Vector3GetY(self.currentPosition)..")")
	self.state = "unlaunched"
	self.emitter:stopAll()
end

Events.OnTick.Add(updateAllHelicopters)




--- Debug: Reports helicopter's useful variables -- note: this will flood your output
function eHelicopter:Report(aiming, dampen)
	---@type eHelicopter heli
	local heli = self
	local report = " a:"..tostring(aiming).." d:"..tostring(dampen).." "
	print("HELI: "..heli.ID.." (x:"..Vector3GetX(heli.currentPosition)..", y:"..Vector3GetY(heli.currentPosition)..")")
	print("TARGET: (x:"..Vector3GetX(heli.targetPosition)..", y:"..Vector3GetY(heli.targetPosition)..")")
	print("(dist: "..heli:getDistanceToTarget().."  "..report)
	print("-----------------------------------------------------------------")
end


--TODO:
-- gather range of squares
-- gather list of zombies OR players in squares
--- option a: create vector from leader to farthest zombie within members?
------ identify members with in a range of 1 along the vector
------ This will be the firing trajectory
-- option b: create a fractalIsoRange (ex: 3x3 of 3x3 (81 squares))
------ kill zombies with in the most populated square?
------ OR implement option a at this point?
--- look into creating dust-ups from bullet impacts

function eHelicopter:attack()
end





Events.OnCustomUIKey.Add(function(key)
	if key == Keyboard.KEY_7 then
		local player = getSpecificPlayer(0)
		local fractalObjectsFound = getHumanoidsInFractalRange(player, 1, "IsoZombie")
		---debug: list type found
		print("-----------------------------------------")
		for fractalIndex=1, #fractalObjectsFound do
			local fractal = fractalObjectsFound[fractalIndex]
			print("fractalIndex: "..fractalIndex.." count:"..#fractal)
			--for i=1, #fractal do
			--	---@type IsoMovingObject foundObj
			--	local foundObj = fractal[i]
			--	print(i..": "..foundObj:getClass():getSimpleName()) -- "IsoZombie" or "IsoPlayer"
			--end

		end
		print("-----------------------------------------")
	end
end)


Events.OnCustomUIKey.Add(function(key)
	if key == Keyboard.KEY_6 then
		local player = getSpecificPlayer(0)
		local objectsFound = getHumanoidsInRange(player, 1, "IsoZombie")
		---debug: list type found
		print("-----------------------------------------")
		print("objectsFound: ".." count: "..#objectsFound)
		for i=1, #objectsFound do
			---@type IsoMovingObject foundObj
			local foundObj = objectsFound[i]
			print(i..": "..foundObj:getClass():getSimpleName()) -- "IsoZombie" or "IsoPlayer"
		end
		print("-----------------------------------------")
	end
end)


---@param center IsoObject
---@param range number tiles to scan from center, not including center. ex: range of 1 = 3x3
---@param lookForType table strings, compared to getClass():getSimpleName()
function getHumanoidsInFractalRange(center, range, lookForType)

	--FractalRange = 3*3 made up of (9) range*range
	--example: range of 1, e is center
	--[a][b][c]  --[a] = [-1, 1][0, 1][1, 1]
	--[d][e][f]          [-1, 0][0, 0][1, 0]
	--[g][h][i]          [-1,-1][0,-1][1,-1]

	--get distance from 1 center to the next using range*2 + 1 for the other center
	local fractalFactor = (range*2)+1
	--list of center's
	local fractalIsoRangeIndex = {
		--a's center
		getSquare(center:getX()-fractalFactor,center:getY()+fractalFactor,0),
		--b's center
		getSquare(center:getX(),center:getY()+fractalFactor,0),
		--c's center
		getSquare(center:getX()+fractalFactor,center:getY()+fractalFactor,0),
		--d's center
		getSquare(center:getX()-fractalFactor,center:getY(),0),
		--e's center, true center
		getSquare(center:getX(),center:getY(),0),
		--f's center
		getSquare(center:getX()+fractalFactor,center:getY(),0),
		--g's center
		getSquare(center:getX()-fractalFactor,center:getY()-fractalFactor,0),
		--h's center
		getSquare(center:getX(),center:getY()-fractalFactor,0),
		--i's center
		getSquare(center:getX()+fractalFactor,center:getY()-fractalFactor,0),
	}

	local fractalObjectsFound = {}

	for fractalIndex=1, #fractalIsoRangeIndex do
		local objectsFound = getHumanoidsInRange(fractalIsoRangeIndex[fractalIndex], range, lookForType)
		table.insert(fractalObjectsFound, objectsFound)
	end

	return fractalObjectsFound
end


---@param center IsoObject
---@param range number tiles to scan from center, not including center. ex: range of 1 = 3x3
---@param lookForType table strings, compared to getClass():getSimpleName()
function getHumanoidsInRange(center, range, lookForType)

	local squaresInRange = getIsoRange(center, range)
	local objectsFound = {}

	for sq=1, #squaresInRange do

		---@type IsoGridSquare
		local square = squaresInRange[sq]
		local squareContents = square:getLuaMovingObjectList()

		for i=1, #squareContents do
			---@type IsoMovingObject foundObject
			local foundObj = squareContents[i]

			if (not lookForType) or (lookForType==foundObj:getClass():getSimpleName()) then
				table.insert(objectsFound, foundObj)
			end
		end
	end

	return objectsFound
end


---@param center IsoObject | IsoGridSquare
---@param range number tiles to scan from center, not including center. ex: range of 1 = 3x3
---@return table of IsoGridSquare
function getIsoRange(center, range)

	--if center is not an IsoGridSquare then call center's getSquare

	if center:getClass():getSimpleName() ~= "IsoGridSquare" then
		center = center:getSquare()
	end

	local centerX, centerY = center:getX(), center:getY()
	--add center to squares at the start
	local squares = {center}

	--no point in running everything below, return squares
	if range < 1 then return squares end

	--create a ring of IsoGridSquare around center, i=1 skips center
	for i=1, range do

		--currentX and currentY have to pushed off center for the logic below to kick in
		local currentX, currentY = centerX+i, centerY+i
		-- ring refers to the path going around center, -1 to skip center
		local expectedRingLength = (8*i)-1

		for _=0, expectedRingLength do
			--if on top-row and not at the upper-right
			if (currentY == centerY+i) and (currentX < centerX+i) then
				--move-right
				currentX = currentX+1
			--if on right-column and not the bottom-right
			elseif (currentX == centerX+i) and (currentY > centerY-i) then
				--move down
				currentY = currentY-1
			--if on bottom-row and not on far-left
			elseif (currentY == centerY-i) and (currentX > centerX-i) then
				--move left
				currentX = currentX-1
			--if on left-column and not on top-left
			elseif (currentX == centerX-i) and (currentY < centerY+i) then
				--move up
				currentY = currentY+1
			end

			---@type IsoGridSquare square
			local square = getSquare(currentX, currentY, 0)
			table.insert(squares, square)
		end
	end

	--[[---DEBUG
	print("IsoRange: total "..#squares.."/"..((range*2)+1)^2)
	for k,v in pairs(squares) do
		---@type IsoGridSquare vSquare
		local vSquare = v
		print(k..": "..centerX-vSquare:getX()..", "..centerY-vSquare:getY())
	end
	--]]

	return squares
end




--- Used only for testing heli launches
Events.OnCustomUIKey.Add(function(key)
	if key == Keyboard.KEY_0 then
		---@type eHelicopter heli
		local heli = getFreeHelicopter()
		heli:launch()
		print("HELI: "..heli.ID.." LAUNCHED".." (x:"..Vector3GetX(heli.currentPosition)..", y:"..Vector3GetY(heli.currentPosition)..")")
	end
end)


--- Used to test all announcements
Events.OnCustomUIKey.Add(function(key)
	if key == Keyboard.KEY_9 then--- test all announcements
	testAllLines()
	end
end)

--GLOBAL DEBUG VARS
testAllLines__ALL_LINES = {}
testAllLines__DELAYS = {}
testAllLines__lastDemoTime = 0

function testAllLines()
	if #testAllLines__ALL_LINES > 0 then
		testAllLines__ALL_LINES = {}
		testAllLines__DELAYS = {}
		testAllLines__lastDemoTime = 0
		return
	end

	for k,_ in pairs(eHelicopter_announcers) do
		for _,v2 in pairs(eHelicopter_announcers[k]["Lines"]) do
			for k3,_ in pairs(v2) do
				if k3 ~= 1 then
					table.insert(testAllLines__ALL_LINES, v2[k3])
					table.insert(testAllLines__DELAYS, v2[1])
				end
			end
		end
	end
	table.insert(testAllLines__ALL_LINES, "heli_fire_single")
	table.insert(testAllLines__DELAYS, 1)
end

function testAllLinesLOOP()
	if #testAllLines__ALL_LINES > 0 then
		if (testAllLines__lastDemoTime <= getTimestamp()) then
			local line = testAllLines__ALL_LINES[1]
			local delay = testAllLines__DELAYS[1]
			testAllLines__lastDemoTime = getTimestamp()+delay
			---@type IsoPlayer | IsoGameCharacter player
			local player = getSpecificPlayer(0)
			player:playSound(line)
			table.remove(testAllLines__ALL_LINES, 1)
			table.remove(testAllLines__DELAYS, 1)
		end
	end
end

Events.OnTick.Add(testAllLinesLOOP)
