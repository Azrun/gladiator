newTalentType{ type="role/axe", name = "axe", description = "axe techniques" }



newTalent{
	name = "Swing",
	type = {"role/axe", 1},
	points = 1,
	cooldown = 6,
	stamina = 10,
	range = 1,
	action = function(self, t)
		local tg = {type="hit", range=self:getTalentRange(t)}
		local x, y, target = self:getTarget(tg)
		if not x or not y or not target then return nil end
		if core.fov.distance(self.x, self.y, x, y) > 1 then return nil end

        local weapon = self:hasMainHandedWeapon()

		self:project(target, x, y, DamageType.PHYSICAL, weapon.combat.dam + 5 )
        --target:knockback(self.x, self.y, 2)
        self.action_queue.main_hand = self.action_queue.main_hand .. "s"
    
		return true
	end,
	info = function(self, t)
		return "Fist o' Furty!"
	end,
}
