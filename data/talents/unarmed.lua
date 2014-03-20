newTalentType{ type="role/unarmed", name = "unarmed", description = "unarmed techniques" }

newTalent{
	name = "Kick",
	type = {"role/unarmed", 1},
	points = 1,
	cooldown = 6,
	power = 2,
	range = 1,
	action = function(self, t)
		local tg = {type="hit", range=self:getTalentRange(t)}
		local x, y, target = self:getTarget(tg)
		if not x or not y or not target then return nil end
		if core.fov.distance(self.x, self.y, x, y) > 1 then return nil end

		target:knockback(self.x, self.y, 2 + self:getDex())
		return true
	end,
	info = function(self, t)
		return "Kick!"
	end,
}

newTalent{
	name = "Punch",
	type = {"role/unarmed", 1},
	points = 1,
	cooldown = 6,
	stamina = 10,
	range = 1,
	action = function(self, t)
		local tg = {type="hit", range=self:getTalentRange(t)}
		local x, y, target = self:getTarget(tg)
		if not x or not y or not target then return nil end
		if core.fov.distance(self.x, self.y, x, y) > 1 then return nil end

		self:project(target, x, y, DamageType.PHYSICAL, 5 )
        target:knockback(self.x, self.y, 2)


        game.logSeen(self, "POW!!!")

		return true
	end,
	info = function(self, t)
		return "Fist o' Furty!"
	end,
}
