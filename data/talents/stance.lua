newTalentType{ type="role/stance", name = "stance", description = "unarmed techniques" }

cancelStances = function(self)
	if self.cancelling_stances then return end
	local stances = {self.T_OFFENSIVE_STANCE, self.T_DEFENSIVE_STANCE}
	self.cancelling_stances = true
	for i, t in ipairs(stances) do
		if self:isTalentActive(t) then
			self:forceUseTalent(t, {ignore_energy=true, ignore_cd=true})
		end
	end
	self.cancelling_stances = nil
end

newTalent{
	name = "Offensive Stance",
	type = {"role/stance", 1},
	mode = "sustained",
	points = 1,
	cooldown = 6,
	--getDamage = function(self, t) return self:getStr(10, true) end,
    getDamage = function(self, t) return 5 end,
	activate = function(self, t)
		cancelStances(self)
		local ret = {
			power = self:addTemporaryValue("combat_dam", t.getDamage(self, t)),
		}
		return ret
        --return true
	end,
	deactivate = function(self, t, p)
		self:removeTemporaryValue("combat_dam", p.power)
		return true
	end,
--	info = function(self, t)
--		local save = 0 --t.getSave(self, t)
--		local damage = t.getDamage(self, t)
--		return ([[Increases your Physical Save by %d and your Physical Power by %d.
--		The bonuses will scale with your Strength.]])
--		:format(save, damage)
--	end
    info = function(self, t)
        return "O Stance!"
    end,
}

newTalent{
	name = "Defensive Stance",
	type = {"role/stance", 1},
	mode = "sustained",
	points = 1,
	cooldown = 6,
	--getDamage = function(self, t) return self:getStr(10, true) end,
    getArmor = function(self, t) return 5 end,
	activate = function(self, t)
		cancelStances(self)
		local ret = {
			power = self:addTemporaryValue("combat_armor", t.getArmor(self, t)),
		}
		return ret
        --return true
	end,
	deactivate = function(self, t, p)
		self:removeTemporaryValue("combat_armor", p.power)
		return true
	end,
--	info = function(self, t)
--		local save = 0 --t.getSave(self, t)
--		local damage = t.getDamage(self, t)
--		return ([[Increases your Physical Save by %d and your Physical Power by %d.
--		The bonuses will scale with your Strength.]])
--		:format(save, damage)
--	end
    info = function(self, t)
        return "D Stance!"
    end,
}


