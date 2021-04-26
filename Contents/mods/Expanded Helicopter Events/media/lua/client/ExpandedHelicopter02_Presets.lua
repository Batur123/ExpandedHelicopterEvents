---Preset list, only include variables being changed.
eHelicopter_PRESETS = {
	["increasingly_hostile"] = {
		presetProgression = {["patrol_only"] = 0, ["attack_only_undead"] = 0.15, ["attack_only_all"] = 0.75}
	},

	["jet"] = {
		randomEdgeStart = true,
		frequencyFactor = 0.33,
		speed = 3,
		topSpeedFactor = 2,
		flightVolume = 25,
		flightSound = "eJetFlight",
		hostilePreference = false,
		announcerVoice = false
	},

	["news_chopper"] = {
		hoverOnTargetDuration = ZombRand(1500,2250),
		--eventSoundEffects = {["hoverOverTarget"]="eHeli_newscaster"},
		frequencyFactor = 2,
		speed = 0.2,
		topSpeedFactor = 5,
		hostilePreference = false,
		announcerVoice = false,
		cutOffDay = 15
	},

	["patrol_only"] = {
		hostilePreference = false
	},

	["attack_only_undead"] = {
		announcerVoice = false
	},

	["attack_only_all"] = {
		announcerVoice = false,
		hostilePreference = "IsoGameCharacter"
	},
}


---@param ID string
function eHelicopter:loadPreset(ID)

	if not ID then
		return
	end

	local preset = eHelicopter_PRESETS[ID]

	if not preset then
		return
	end

	local pp = preset.presetProgression
	if pp then
		local DaysSinceApoc = getGameTime():getModData()["DaysBeforeApoc"]+getGameTime():getNightsSurvived()
		local CutOff = preset.cutOffDay or eHelicopter.cutOffDay
		local DaysOverCutOff = DaysSinceApoc/CutOff
		local presetIDTmp
		--run through presetProgression list
		for pID,pCutOff in pairs(pp) do
			--if progression % is less than DaysOverCutOff
			if pCutOff <= DaysOverCutOff then
				--if there is no stored % or progression % > stored %
				if (not presetIDTmp) or (presetIDTmp and (pCutOff > pp[presetIDTmp])) then
					--store qualifying choice
					presetIDTmp = pID
				end
			end
		end
		if presetIDTmp then
			--replace original preset with qualifying preset
			ID = presetIDTmp
			preset = eHelicopter_PRESETS[ID]
		end
	end

	local reportPreset = "loading preset: "..ID.."  vars:"
	
	--use initial list of variables to reset the helicopter object to standard
	for var, value in pairs(self.initial) do
		local newValue

		if preset[var] ~= nil then
			newValue = preset[var]
		else
			newValue = value
		end
		reportPreset = reportPreset.." -"..var.." = "..tostring(newValue).."\n"
		self[var] = newValue
	end
	print(reportPreset)
end
