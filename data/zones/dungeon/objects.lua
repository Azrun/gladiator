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

local Talents = require "engine.interface.ActorTalents"

newEntity{
    define_as = "BASE_BATTLEAXE",
    slot = "MAINHAND",
    slot_forbid = "OFFHAND",
    type = "weapon", subtype="battleaxe",
    display = "/", color=colors.SLATE,
    encumber = 3,
    rarity = 5,
    combat = { sound = "actions/melee", sound_miss = "actions/melee_miss", },
    name = "a generic battleaxe",
    desc = [[t4modules massive two-handed battleaxes.]],
}

newEntity{ base = "BASE_BATTLEAXE",
    name = "iron battleaxe",
    level_range = {1, 10},
    --require = { stat = { str=11 }, },
    cost = 5,
    combat = {
        dam = 20,
    },
	wielder = {
		learn_talent = {[Talents.T_SWING] = 1},
	},

}
