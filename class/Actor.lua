-- ToME - Tales of Middle-Earth
-- Copyright (C) 2009, 2010, 2011, 2012, 2013 Nicolas Casalini
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
--
-- Nicolas Casalini "DarkGod"
-- darkgod@te4.org

require "engine.class"
require "engine.Actor"
require "engine.interface.ActorInventory"
require "engine.Autolevel"
require "engine.interface.ActorTemporaryEffects"
require "engine.interface.ActorLife"
require "engine.interface.ActorProject"
require "engine.interface.ActorLevel"
require "engine.interface.ActorStats"
require "engine.interface.ActorTalents"
require "engine.interface.ActorResource"
require "engine.interface.ActorFOV"
require "mod.class.interface.Combat"
local Map = require "engine.Map"

module(..., package.seeall, class.inherit(
	engine.Actor,
	engine.interface.ActorInventory,
	engine.interface.ActorTemporaryEffects,
	engine.interface.ActorLife,
	engine.interface.ActorProject,
	engine.interface.ActorLevel,
	engine.interface.ActorStats,
	engine.interface.ActorTalents,
	engine.interface.ActorResource,
	engine.interface.ActorFOV,
	mod.class.interface.Combat
))

function _M:init(t, no_default)
	-- Define some basic combat stats
	self.combat_armor = 0

    self.action_queue = { main_hand = "", off_hand = "", feet = "" }

	-- Default regen
	t.power_regen = t.power_regen or 1
	t.life_regen = t.life_regen or 0.25 -- Life regen real slow
    t.stamina_regen = t.stamina_regen or 0.3 -- Stamina regens slower than mana
	-- Default melee barehanded damage
	self.combat = { dam=1 }

	engine.Actor.init(self, t, no_default)
	engine.interface.ActorTemporaryEffects.init(self, t)
	engine.interface.ActorInventory.init(self, t)
	engine.interface.ActorLife.init(self, t)
	engine.interface.ActorProject.init(self, t)
	engine.interface.ActorTalents.init(self, t)
	engine.interface.ActorResource.init(self, t)
	engine.interface.ActorStats.init(self, t)
	engine.interface.ActorLevel.init(self, t)
	engine.interface.ActorFOV.init(self, t)
end

function _M:act()
	if not engine.Actor.act(self) then return end

	self.changed = true

	-- Cooldown talents
	self:cooldownTalents()
	-- Regen resources
	self:regenLife()
	self:regenResources()
	-- Compute timed effects
	self:timedEffects()

	-- Still enough energy to act ?
	if self.energy.value < game.energy_to_act then return false end

	return true
end

function _M:move(x, y, force)
	local moved = false
	local ox, oy = self.x, self.y
	if force or self:enoughEnergy() then
		moved = engine.Actor.move(self, x, y, force)
		if not force and moved and (self.x ~= ox or self.y ~= oy) and not self.did_energy then self:useEnergy() end
	end
	self.did_energy = nil
	return moved
end

function _M:tooltip()
	return ([[%s%s
#00ffff#Level: %d
#ff0000#HP: %d (%d%%)
ST: %d
Stats: %d /  %d / %d
%s]]):format(
	self:getDisplayString(),
	self.name,
	self.level,
	self.life, self.life * 100 / self.max_life,
    self.stamina,
	self:getStr(),
	self:getDex(),
	self:getCon(),
	self.desc or ""
	)
end

function _M:onTakeHit(value, src)
	return value
end

function _M:die(src)
	engine.interface.ActorLife.die(self, src)

	-- Gives the killer some exp for the kill
	if src and src.gainExp then
		src:gainExp(self:worthExp(src))
	end

	return true
end

function _M:levelup()
	self.max_life = self.max_life + 2

	self:incMaxPower(3)

	-- Heal upon new level
	self.life = self.max_life
    self.stamina = self.max_stamina
	self.power = self.max_power
end

--- Notifies a change of stat value
function _M:onStatChange(stat, v)
	if stat == self.STAT_CON then
		self.max_life = self.max_life + 2
	end
end

function _M:attack(target)
	self:bumpInto(target)
end


--- Called before a talent is used
-- Check the actor can cast it
-- @param ab the talent (not the id, the table)
-- @return true to continue, false to stop
function _M:preUseTalent(ab, silent)
	if not self:enoughEnergy() then print("fail energy") return false end

	if ab.mode == "sustained" then
		if ab.sustain_power and self.max_power < ab.sustain_power and not self:isTalentActive(ab.id) then
			game.logPlayer(self, "You do not have enough power to activate %s.", ab.name)
			return false
		end
	else
		if ab.power and self:getPower() < ab.power then
			game.logPlayer(self, "You do not have enough power to cast %s.", ab.name)
			return false
		end
	end

	if not silent then
		-- Allow for silent talents
		if ab.message ~= nil then
			if ab.message then
				game.logSeen(self, "%s", self:useTalentMessage(ab))
			end
		elseif ab.mode == "sustained" and not self:isTalentActive(ab.id) then
			game.logSeen(self, "%s activates %s.", self.name:capitalize(), ab.name)
		elseif ab.mode == "sustained" and self:isTalentActive(ab.id) then
			game.logSeen(self, "%s deactivates %s.", self.name:capitalize(), ab.name)
		else
			game.logSeen(self, "%s uses %s.", self.name:capitalize(), ab.name)
		end
	end
	return true
end

--- Called before a talent is used
-- Check if it must use a turn, mana, stamina, ...
-- @param ab the talent (not the id, the table)
-- @param ret the return of the talent action
-- @return true to continue, false to stop
function _M:postUseTalent(ab, ret)
	if not ret then return end

	self:useEnergy()

	if ab.mode == "sustained" then
		if not self:isTalentActive(ab.id) then
			if ab.sustain_power then
				self.max_power = self.max_power - ab.sustain_power
			end
            if ab.sustain_stamina then
				self.max_stamina = self.max_stamina - ab.sustain_stamina
			end
		else
			if ab.sustain_power then
				self.max_power = self.max_power + ab.sustain_power
			end
            if ab.sustain_stamina then
				self.max_stamina = self.max_stamina + ab.sustain_stamina
			end
		end
	else
		if ab.power then
			self:incPower(-ab.power)
		end
        if ab.stamina then
			 --self:incStamina(-util.getval(ab.stamina, self, ab) * (100 + self:combatFatigue()) / 100)
             self:incStamina(-ab.stamina)
		end
	end

	return true
end

--- Return the full description of a talent
-- You may overload it to add more data (like power usage, ...)
function _M:getTalentFullDescription(t)
	local d = {}

	if t.mode == "passive" then d[#d+1] = "#6fff83#Use mode: #00FF00#Passive"
	elseif t.mode == "sustained" then d[#d+1] = "#6fff83#Use mode: #00FF00#Sustained"
	else d[#d+1] = "#6fff83#Use mode: #00FF00#Activated"
	end

	if t.power or t.sustain_power then d[#d+1] = "#6fff83#Power cost: #7fffd4#"..(t.power or t.sustain_power) end
	if self:getTalentRange(t) > 1 then d[#d+1] = "#6fff83#Range: #FFFFFF#"..self:getTalentRange(t)
	else d[#d+1] = "#6fff83#Range: #FFFFFF#melee/personal"
	end
	if t.cooldown then d[#d+1] = "#6fff83#Cooldown: #FFFFFF#"..t.cooldown end

	return table.concat(d, "\n").."\n#6fff83#Description: #FFFFFF#"..t.info(self, t)
end

--- How much experience is this actor worth
-- @param target to whom is the exp rewarded
-- @return the experience rewarded
function _M:worthExp(target)
	if not target.level or self.level < target.level - 3 then return 0 end

	local mult = 2
	if self.unique then mult = 6
	elseif self.egoed then mult = 3 end
	return self.level * mult * self.exp_worth
end

--- Can the actor see the target actor
-- This does not check LOS or such, only the actual ability to see it.<br/>
-- Check for telepathy, invisibility, stealth, ...
function _M:canSee(actor, def, def_pct)
	if not actor then return false, 0 end

	-- Check for stealth. Checks against the target cunning and level
	if actor:attr("stealth") and actor ~= self then
		local def = self.level / 2 + self:getCun(25)
		local hit, chance = self:checkHit(def, actor:attr("stealth") + (actor:attr("inc_stealth") or 0), 0, 100)
		if not hit then
			return false, chance
		end
	end

	if def ~= nil then
		return def, def_pct
	else
		return true, 100
	end
end

--- Can the target be applied some effects
-- @param what a string describing what is being tried
function _M:canBe(what)
	if what == "poison" and rng.percent(100 * (self:attr("poison_immune") or 0)) then return false end
	if what == "cut" and rng.percent(100 * (self:attr("cut_immune") or 0)) then return false end
	if what == "confusion" and rng.percent(100 * (self:attr("confusion_immune") or 0)) then return false end
	if what == "blind" and rng.percent(100 * (self:attr("blind_immune") or 0)) then return false end
	if what == "stun" and rng.percent(100 * (self:attr("stun_immune") or 0)) then return false end
	if what == "fear" and rng.percent(100 * (self:attr("fear_immune") or 0)) then return false end
	if what == "knockback" and rng.percent(100 * (self:attr("knockback_immune") or 0)) then return false end
	if what == "instakill" and rng.percent(100 * (self:attr("instakill_immune") or 0)) then return false end
	return true
end

--- Call when an object is worn
-- This doesnt call the base interface onWear, it copies the code because we need some tricky stuff
function _M:onWear(o)

	-- Learn Talent
	if o.wielder and o.wielder.learn_talent then 
		for tid, level in pairs(o.wielder.learn_talent) do
			self:learnItemTalent(o, tid, level)
		end
	end
end

--- Call when an object is taken off
function _M:onTakeoff(o)
	--engine.interface.ActorInventory.onTakeoff(self, o)

	if o.wielder and o.wielder.learn_talent then
		for tid, level in pairs(o.wielder.learn_talent) do
			self:unlearnItemTalent(o, tid, level)
		end
	end
end



-- Learn item talents; right now this code has no sanity checks so use it wisely
-- For example you can give the player talent levels in talents they know, which they can then unlearn for free talent points
-- Freshly learned talents also do not start on cooldown; which is fine for now but should be changed if we start using this code to teach more general talents to prevent swap abuse
-- For now we'll use it to teach talents the player couldn't learn at all otherwise rather then talents that they could possibly know
-- Make sure such talents are always flagged as unlearnable (see Command Staff for an example)
function _M:learnItemTalent(o, tid, level)
	local t = self:getTalentFromId(tid)
	local max = t.hard_cap or (t.points and t.points + 2) or 5
	if not self.item_talent_surplus_levels then self.item_talent_surplus_levels = {} end
	--local item_talent_surplus_levels = self.item_talent_surplus_levels or {}
	if not self.item_talent_surplus_levels[tid] then self.item_talent_surplus_levels[tid] = 0 end
	--item_talent_levels[tid] = item_talent_levels[tid] + level
	for i = 1, level do
		if self:getTalentLevelRaw(t) >= max then
			self.item_talent_surplus_levels[tid] = self.item_talent_surplus_levels[tid] + 1
		else
			self:learnTalent(tid, true, 1, {no_unlearn = true})
		end
	end

	if not self.talents_cd[tid] then
		local cd = math.ceil((self:getTalentCooldown(t) or 6) / 1.5)
		self.talents_cd[tid] = cd
	end
end

function _M:unlearnItemTalent(o, tid, level)
	local t = self:getTalentFromId(tid)
	local max = (t.points and t.points + 2) or 5
	if not self.item_talent_surplus_levels then self.item_talent_surplus_levels = {} end
	--local item_talent_surplus_levels = self.item_talent_surplus_levels or {}
	if not self.item_talent_surplus_levels[tid] then self.item_talent_surplus_levels[tid] = 0 end

	if self:isTalentActive(t) then self:forceUseTalent(t, {ignore_energy=true}) end

	for i = 1, level do
		if self.item_talent_surplus_levels[tid] > 0 then
			self.item_talent_surplus_levels[tid] = self.item_talent_surplus_levels[tid] - 1
		else
			self:unlearnTalent(tid, nil, nil, {no_unlearn = true})
		end
	end
end

function _M:colorStats(stat)
	local score = 0
	if stat == "combatDefense" or stat == "combatPhysicalResist" or stat == "combatSpellResist" or stat == "combatMentalResist" then
		score = math.floor(self[stat](self, true))
	else
		score = math.floor(self[stat](self))
	end

	if score <= 9 then
		return "#B4B4B4# "..score
	elseif score <= 20 then
		return "#B4B4B4#"..score
	elseif score <= 40 then
		return "#FFFFFF#"..score
	elseif score <= 60 then
		return "#00FF80#"..score
	elseif score <= 80 then
		return "#0080FF#"..score
	elseif score <= 99 then
		return "#8d55ff#"..score
	elseif score >= 100 then
		return "#8d55ff#"..score  -- Enable longer numbers
	end
end
