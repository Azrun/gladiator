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
local DamageType = require "engine.DamageType"
local Map = require "engine.Map"
local Target = require "engine.Target"
local Talents = require "engine.interface.ActorTalents"

--- Interface to add ToME combat system
module(..., package.seeall, class.make)

--- Checks what to do with the target
-- Talk ? attack ? displace ?
function _M:bumpInto(target)
	local reaction = self:reactionToward(target)
	if reaction < 0 then
		return self:attackTarget(target)
	elseif reaction >= 0 then
		if self.move_others then
			-- Displace
			game.level.map:remove(self.x, self.y, Map.ACTOR)
			game.level.map:remove(target.x, target.y, Map.ACTOR)
			game.level.map(self.x, self.y, Map.ACTOR, target)
			game.level.map(target.x, target.y, Map.ACTOR, self)
			self.x, self.y, target.x, target.y = target.x, target.y, self.x, self.y
		end
	end
end

--- Makes the death happen!
function _M:attackTarget(target, mult)
	local speed, dam, hit, damtype = nil, 0, false, DamageType.PHYSICAL
    
	local mean
	if not speed and not self:attr("disarmed") and not self:isUnarmed() then
		-- All weapons in main hands
		if self:getInven(self.INVEN_MAINHAND) then
			for i, o in ipairs(self:getInven(self.INVEN_MAINHAND)) do
				local combat = self:getObjectCombat(o, "mainhand")
				if combat and not o.archery then
                    dam = combat.dam
					print("[ATTACK] attacking with", o.name)
					--local s, h = self:attackTargetWith(target, combat, damtype, mult)
					--speed = math.max(speed or 0, s)
					--hit = hit or h
					--if hit and not sound then sound = combat.sound
					--elseif not hit and not sound_miss then sound_miss = combat.sound_miss end
					--if not combat.no_stealth_break then break_stealth = true end
				end
			end
		end
		-- All weapons in off hands
		-- Offhand attacks are with a damage penalty, that can be reduced by talents
		if self:getInven(self.INVEN_OFFHAND) then
			for i, o in ipairs(self:getInven(self.INVEN_OFFHAND)) do
				local offmult = self:getOffHandMult(o.combat, mult)
				local combat = self:getObjectCombat(o, "offhand")
				if o.special_combat and o.subtype == "shield" and self:knowTalent(self.T_STONESHIELD) then combat = o.special_combat end
				if combat and not o.archery then
					print("[ATTACK] attacking with", o.name)
                    dam = combat.dam
					--local s, h = self:attackTargetWith(target, combat, damtype, offmult)
					--speed = math.max(speed or 0, s)
					--hit = hit or h
					--if hit and not sound then sound = combat.sound
					--elseif not hit and not sound_miss then sound_miss = combat.sound_miss end
					--if not combat.no_stealth_break then break_stealth = true end
				end
			end
		end
		mean = "weapon"
	end

	if not speed and self.combat and self:isUnarmed() then
		dam = self.combat.dam + self:getStr() - target.combat_armor
		--DamageType:get(DamageType.PHYSICAL).projector(self, target.x, target.y, DamageType.PHYSICAL, math.max(0, dam))
        mean = "unharmed"
	end

    --Apply bonus damage
    dam = dam + ( self.combat_dam or 0 )

   --Reduce by armor
    dam = dam - ( target.combat_armor or 0 )

    --if dam > 0 then
	    DamageType:get(damtype).projector(self, target.x, target.y, damtype, math.max(0, dam))
    --else
    --    print("[ATTACK] attacking with but does nothing", self.name)
    --    --self:logCombat(target, "#Source# misses #Target#.")
    --    game.logPlayer(game.player, "%s hit you but you didn't even feel it.", self.name)
	--end

	-- We use up our own energy
	self:useEnergy(game.energy_to_act)
end

--- Gets the damage
function _M:combatDamage(weapon)
	weapon = weapon or self.combat or {}
    return( weapon.dam )
--	local sub_cun_to_str = false
--	if weapon.talented and weapon.talented == "knife" and self:knowTalent(Talents.T_LETHALITY) then sub_cun_to_str = true end
--
--	local totstat = 0
--	local dammod = weapon.dammod or {str=0.6}
--	for stat, mod in pairs(dammod) do
--		if sub_cun_to_str and stat == "str" then stat = "cun" end
--		if self.use_psi_combat and stat == "str" then stat = "wil" end
--		if self.use_psi_combat and stat == "dex" then stat = "cun" end
--		totstat = totstat + self:getStat(stat) * mod
--	end
--	if self.use_psi_combat then
--		if self:knowTalent(self.T_GREATER_TELEKINETIC_GRASP) then
--			local g = self:getTalentFromId(self.T_GREATER_TELEKINETIC_GRASP)
--			totstat = totstat * g.stat_sub(self, g)
--		else
--			totstat = totstat * 0.6
--		end
--	end
--
--	if self:knowTalent(self.T_SUPERPOWER) then
--		totstat = totstat + self:getStat("wil") * 0.3
--	end
--
--	if self:knowTalent(self.T_ARCANE_MIGHT) then
--		totstat = totstat + self:getStat("mag") * 0.5
--	end
--
--	local talented_mod = math.sqrt(self:combatCheckTraining(weapon) / 5) / 2 + 1
--
--	local power = math.max((weapon.dam or 1), 1)
--	power = (math.sqrt(power / 10) - 1) * 0.5 + 1
--	--print(("[COMBAT DAMAGE] power(%f) totstat(%f) talent_mod(%f)"):format(power, totstat, talented_mod))
--	return self:rescaleDamage(0.3*(self:combatPhysicalpower(nil, weapon) + totstat) * power * talented_mod)
end

--- Determines the combat field to use for this item
function _M:getObjectCombat(o, kind)
	if kind == "barehand" then return self.combat end
	if kind == "mainhand" then return o.combat end
	if kind == "offhand" then return o.combat end
	return nil
end

--- Check if the actor has a two handed weapon
function _M:hasTwoHandedWeapon()
	if self:attr("disarmed") then
		return nil, "disarmed"
	end

	if not self:getInven("MAINHAND") then return end
	local weapon = self:getInven("MAINHAND")[1]
	if not weapon or not weapon.twohanded then
		return nil
	end
	return weapon
end

function _M:hasMainHandedWeapon()
    if self:attr("disarmed") then
		return nil, "disarmed"
	end

	if not self:getInven("MAINHAND") then return end
	local weapon = self:getInven("MAINHAND")[1]
	if not weapon then
		return nil
	end
	return weapon
end


--- Check if the actor has a shield
function _M:hasShield()
	if self:attr("disarmed") then
		return nil, "disarmed"
	end

	if not self:getInven("MAINHAND") or not self:getInven("OFFHAND") then return end
	local shield = self:getInven("OFFHAND")[1]
	if not shield or not shield.special_combat then
		return nil
	end
	return shield
end

-- Check if actor is unarmed
function _M:isUnarmed()
	local unarmed = true
	if not self:getInven("MAINHAND") or not self:getInven("OFFHAND") then return end
	local weapon = self:getInven("MAINHAND")[1]
	local offweapon = self:getInven("OFFHAND")[1]
	if weapon or offweapon then
		unarmed = false
	end
	return unarmed
end


-- Display Combat log messages, highlighting the player and taking LOS and visibility into account
-- #source#|#Source# -> <displayString> self.name|self.name:capitalize()
-- #target#|#Target# -> target.name|target.name:capitalize()
function _M:logCombat(target, style, ...)
	if not game.uiset or not game.uiset.logdisplay then return end
	local visible, srcSeen, tgtSeen = game:logVisible(self, target)  -- should a message be displayed?
	if visible then game.uiset.logdisplay(game:logMessage(self, srcSeen, target, tgtSeen, style, ...)) end 
end
