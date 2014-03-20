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
require "engine.GameTurnBased"
require "engine.interface.GameTargeting"
require "engine.KeyBind"
local Savefile = require "engine.Savefile"
local DamageType = require "engine.DamageType"
local Zone = require "engine.Zone"
local Map = require "engine.Map"
local Level = require "engine.Level"
local Birther = require "engine.Birther"

local Grid = require "mod.class.Grid"
local Actor = require "mod.class.Actor"
local Player = require "mod.class.Player"
local NPC = require "mod.class.NPC"

local PlayerDisplay = require "mod.class.PlayerDisplay"
local HotkeysDisplay = require "engine.HotkeysDisplay"
local ActorsSeenDisplay = require "engine.ActorsSeenDisplay"
local LogDisplay = require "engine.LogDisplay"
local LogFlasher = require "engine.LogFlasher"
local DebugConsole = require "engine.DebugConsole"
local FlyingText = require "engine.FlyingText"
local Tooltip = require "engine.Tooltip"

local QuitDialog = require "mod.dialogs.Quit"

module(..., package.seeall, class.inherit(engine.GameTurnBased, engine.interface.GameTargeting))

function _M:init()
	engine.GameTurnBased.init(self, engine.KeyBind.new(), 1000, 100)

	-- Pause at birth
	self.paused = true

	-- Same init as when loaded from a savefile
	self:loaded()
end

function _M:run()
	self.flash = LogFlasher.new(0, 0, self.w, 20, nil, nil, nil, {255,255,255}, {0,0,0})
	self.logdisplay = LogDisplay.new(0, self.h * 0.8, self.w * 0.5, self.h * 0.2, nil, nil, nil, {255,255,255}, {30,30,30})
	self.hotkeys_display = HotkeysDisplay.new(nil, self.w * 0.5, self.h * 0.8, self.w * 0.5, self.h * 0.2, {30,30,0})
	self.npcs_display = ActorsSeenDisplay.new(nil, self.w * 0.5, self.h * 0.8, self.w * 0.5, self.h * 0.2, {30,30,0})
	self.tooltip = Tooltip.new(nil, nil, {255,255,255}, {30,30,30})
	self.flyers = FlyingText.new()
	self:setFlyingText(self.flyers)

	self.log = function(style, ...) if type(style) == "number" then self.logdisplay(...) self.flash(style, ...) else self.logdisplay(style, ...) self.flash(self.flash.NEUTRAL, style, ...) end end
	self.logSeen = function(e, style, ...) if e and self.level.map.seens(e.x, e.y) then self.log(style, ...) end end
	self.logPlayer = function(e, style, ...) if e == self.player then self.log(style, ...) end end

	self.log(self.flash.GOOD, "Welcome to #00FF00#the template module!")

	size = ({normal=12, small=10, big=14})["normal"]--[config.settings.tome.fonts.size]
	size_mono = ({normal=12, small=10, big=14})["normal"]--[config.settings.tome.fonts.size]
	font = "/data/font/Vera.ttf"
	font_mono = "/data/font/VeraMono.ttf"

    self.player_display = PlayerDisplay.new(0, 200, 200, game.h - 200, {30,30,0}, font_mono, size_mono)

	-- Setup inputs
	self:setupCommands()
	self:setupMouse()

	-- Starting from here we create a new game
	if not self.player then self:newGame() end

	self.hotkeys_display.actor = self.player
	self.npcs_display.actor = self.player

	-- Setup the targetting system
	engine.interface.GameTargeting.init(self)

	-- Ok everything is good to go, activate the game in the engine!
	self:setCurrent()

	if self.level then self:setupDisplayMode() end
end

function _M:newGame()
	self.player = Player.new{name=self.player_name, game_ender=true}
	Map:setViewerActor(self.player)
	self:setupDisplayMode()

	self.creating_player = true
	local birth = Birther.new(nil, self.player, {"base", "role" }, function()
		self:changeLevel(1, "dungeon")
		print("[PLAYER BIRTH] resolve...")
		self.player:resolve()
		self.player:resolve(nil, true)
		self.player.energy.value = self.energy_to_act
		self.paused = true
		self.creating_player = false
		print("[PLAYER BIRTH] resolved!")
	end)
	self:registerDialog(birth)
end

function _M:loaded()
	engine.GameTurnBased.loaded(self)
	Zone:setup{npc_class="mod.class.NPC", grid_class="mod.class.Grid", }
	Map:setViewerActor(self.player)
	Map:setViewPort(200, 20, self.w - 200, math.floor(self.h * 0.80) - 20, 32, 32, nil, 22, true)
	self.key = engine.KeyBind.new()
end

function _M:setupDisplayMode()
	print("[DISPLAY MODE] 32x32 ASCII/background")
	Map:setViewPort(200, 20, self.w - 200, math.floor(self.h * 0.80) - 20, 32, 32, nil, 22, true)
	Map:resetTiles()
	Map.tiles.use_images = false

	if self.level then
		self.level.map:recreate()
		engine.interface.GameTargeting.init(self)
		self.level.map:moveViewSurround(self.player.x, self.player.y, 8, 8)
	end
end

function _M:save()
	return class.save(self, self:defaultSavedFields{}, true)
end

function _M:getSaveDescription()
	return {
		name = self.player.name,
		description = ([[Exploring level %d of %s.]]):format(self.level.level, self.zone.name),
	}
end

function _M:leaveLevel(level, lev, old_lev)
	if level:hasEntity(self.player) then
		level.exited = level.exited or {}
		if lev > old_lev then
			level.exited.down = {x=self.player.x, y=self.player.y}
		else
			level.exited.up = {x=self.player.x, y=self.player.y}
		end
		level.last_turn = game.turn
		level:removeEntity(self.player)
	end
end

function _M:changeLevel(lev, zone)
	local old_lev = (self.level and not zone) and self.level.level or -1000
	if zone then
		if self.zone then
			self.zone:leaveLevel(false, lev, old_lev)
			self.zone:leave()
		end
		if type(zone) == "string" then
			self.zone = Zone.new(zone)
		else
			self.zone = zone
		end
	end
	self.zone:getLevel(self, lev, old_lev)

	if lev > old_lev then
		self.player:move(self.level.default_up.x, self.level.default_up.y, true)
	else
		self.player:move(self.level.default_down.x, self.level.default_down.y, true)
	end
	self.level:addEntity(self.player)
end

function _M:getPlayer()
	return self.player
end

--- Says if this savefile is usable or not
function _M:isLoadable()
	return not self:getPlayer(true).dead
end

function _M:tick()
	if self.level then
		self:targetOnTick()

		engine.GameTurnBased.tick(self)
		-- Fun stuff: this can make the game realtime, although calling it in display() will make it work better
		-- (since display is on a set FPS while tick() ticks as much as possible
		-- engine.GameEnergyBased.tick(self)
	end
	-- When paused (waiting for player input) we return true: this means we wont be called again until an event wakes us
	if self.paused and not savefile_pipe.saving then return true end
end

--- Called every game turns
-- Does nothing, you can override it
function _M:onTurn()
	-- The following happens only every 10 game turns (once for every turn of 1 mod speed actors)
	if self.turn % 10 ~= 0 then return end

	-- Process overlay effects
	self.level.map:processEffects()
end

function _M:display(nb_keyframe)
	-- If switching resolution, blank everything but the dialog
	if self.change_res_dialog then engine.GameTurnBased.display(self, nb_keyframe) return end

	-- Now the map, if any
	if self.level and self.level.map and self.level.map.finished then
		-- Display the map and compute FOV for the player if needed
		if self.level.map.changed then
			self.player:playerFOV()
		end

		self.level.map:display(nil, nil, nb_keyframe)

		-- Display the targetting system if active
		self.target:display()

		-- And the minimap
		self.level.map:minimapDisplay(self.w - 200, 20, util.bound(self.player.x - 25, 0, self.level.map.w - 50), util.bound(self.player.y - 25, 0, self.level.map.h - 50), 50, 50, 0.6)
	end

	-- We display the player's interface
	self.flash:toScreen(nb_keyframe)
	self.logdisplay:toScreen()
	if self.show_npc_list then
		self.npcs_display:toScreen()
	else
		self.hotkeys_display:toScreen()
	end

    self.player_display:toScreen(nb_keyframes)

	if self.player then self.player.changed = false end

	-- Tooltip is displayed over all else
	self:targetDisplayTooltip()

	engine.GameTurnBased.display(self, nb_keyframe)
end

--- Setup the keybinds
function _M:setupCommands()
	-- Make targeting work
	self.normal_key = self.key
	self:targetSetupKey()

	-- One key handled for normal function
	self.key:unicodeInput(true)
	self.key:addBinds
	{
		-- Movements
		MOVE_LEFT = function() self.player:moveDir(4) end,
		MOVE_RIGHT = function() self.player:moveDir(6) end,
		MOVE_UP = function() self.player:moveDir(8) end,
		MOVE_DOWN = function() self.player:moveDir(2) end,
		MOVE_LEFT_UP = function() self.player:moveDir(7) end,
		MOVE_LEFT_DOWN = function() self.player:moveDir(1) end,
		MOVE_RIGHT_UP = function() self.player:moveDir(9) end,
		MOVE_RIGHT_DOWN = function() self.player:moveDir(3) end,
		MOVE_STAY = function() self.player:useEnergy() end,

		RUN_LEFT = function() self.player:runInit(4) end,
		RUN_RIGHT = function() self.player:runInit(6) end,
		RUN_UP = function() self.player:runInit(8) end,
		RUN_DOWN = function() self.player:runInit(2) end,
		RUN_LEFT_UP = function() self.player:runInit(7) end,
		RUN_LEFT_DOWN = function() self.player:runInit(1) end,
		RUN_RIGHT_UP = function() self.player:runInit(9) end,
		RUN_RIGHT_DOWN = function() self.player:runInit(3) end,

		-- Hotkeys
		HOTKEY_1 = function() self.player:activateHotkey(1) end,
		HOTKEY_2 = function() self.player:activateHotkey(2) end,
		HOTKEY_3 = function() self.player:activateHotkey(3) end,
		HOTKEY_4 = function() self.player:activateHotkey(4) end,
		HOTKEY_5 = function() self.player:activateHotkey(5) end,
		HOTKEY_6 = function() self.player:activateHotkey(6) end,
		HOTKEY_7 = function() self.player:activateHotkey(7) end,
		HOTKEY_8 = function() self.player:activateHotkey(8) end,
		HOTKEY_9 = function() self.player:activateHotkey(9) end,
		HOTKEY_10 = function() self.player:activateHotkey(10) end,
		HOTKEY_11 = function() self.player:activateHotkey(11) end,
		HOTKEY_12 = function() self.player:activateHotkey(12) end,
		HOTKEY_SECOND_1 = function() self.player:activateHotkey(13) end,
		HOTKEY_SECOND_2 = function() self.player:activateHotkey(14) end,
		HOTKEY_SECOND_3 = function() self.player:activateHotkey(15) end,
		HOTKEY_SECOND_4 = function() self.player:activateHotkey(16) end,
		HOTKEY_SECOND_5 = function() self.player:activateHotkey(17) end,
		HOTKEY_SECOND_6 = function() self.player:activateHotkey(18) end,
		HOTKEY_SECOND_7 = function() self.player:activateHotkey(19) end,
		HOTKEY_SECOND_8 = function() self.player:activateHotkey(20) end,
		HOTKEY_SECOND_9 = function() self.player:activateHotkey(21) end,
		HOTKEY_SECOND_10 = function() self.player:activateHotkey(22) end,
		HOTKEY_SECOND_11 = function() self.player:activateHotkey(23) end,
		HOTKEY_SECOND_12 = function() self.player:activateHotkey(24) end,
		HOTKEY_THIRD_1 = function() self.player:activateHotkey(25) end,
		HOTKEY_THIRD_2 = function() self.player:activateHotkey(26) end,
		HOTKEY_THIRD_3 = function() self.player:activateHotkey(27) end,
		HOTKEY_THIRD_4 = function() self.player:activateHotkey(28) end,
		HOTKEY_THIRD_5 = function() self.player:activateHotkey(29) end,
		HOTKEY_THIRD_6 = function() self.player:activateHotkey(30) end,
		HOTKEY_THIRD_7 = function() self.player:activateHotkey(31) end,
		HOTKEY_THIRD_8 = function() self.player:activateHotkey(32) end,
		HOTKEY_THIRD_9 = function() self.player:activateHotkey(33) end,
		HOTKEY_THIRD_10 = function() self.player:activateHotkey(34) end,
		HOTKEY_THIRD_11 = function() self.player:activateHotkey(35) end,
		HOTKEY_THIRD_12 = function() self.player:activateHotkey(36) end,
		HOTKEY_PREV_PAGE = function() self.player:prevHotkeyPage() end,
		HOTKEY_NEXT_PAGE = function() self.player:nextHotkeyPage() end,

		-- Actions
		CHANGE_LEVEL = function()
			local e = self.level.map(self.player.x, self.player.y, Map.TERRAIN)
			if self.player:enoughEnergy() and e.change_level then
				self:changeLevel(e.change_zone and e.change_level or self.level.level + e.change_level, e.change_zone)
			else
				self.log("There is no way out of this level here.")
			end
		end,

		REST = function()
			self.player:restInit()
		end,
		
		PICKUP_FLOOR = function()
			if self.player.no_inventory_access then return end
			self.player:playerPickup()
		end,
		
		DROP_FLOOR = function()
			if self.player.no_inventory_access then return end
			self.player:playerDrop()
		end, 

		USE_TALENTS = function()
			self.player:useTalents()
		end,

		SAVE_GAME = function()
			self:saveGame()
		end,

		SHOW_CHARACTER_SHEET = function()
			self:registerDialog(require("mod.dialogs.CharacterSheet").new(self.player))
		end,
		
		 SHOW_INVENTORY = function()
			if self.player.no_inventory_access then return end
			local d
			d = self.player:showEquipInven("Inventory", nil, function(o, inven, item, button, event)
				if not o then return end
				local ud = require("mod.dialogs.UseItemDialog").new(event == "button", self.player, o, item, inven, function(_, _, _, stop)
					d:generate()
					d:generateList()
					if stop then self:unregisterDialog(d) end
				end)
				self:registerDialog(ud)
			end)
		end, 

		-- Exit the game
		QUIT_GAME = function()
			self:onQuit()
		end,

		SCREENSHOT = function() self:saveScreenshot() end,

		EXIT = function()
			local menu menu = require("engine.dialogs.GameMenu").new{
				"resume",
				"keybinds",
				"video",
				"save",
				"quit"
			}
			self:registerDialog(menu)
		end,

		-- Lua console, you probably want to disable it for releases
		LUA_CONSOLE = function()
			self:registerDialog(DebugConsole.new())
		end,

		-- Toggle monster list
		TOGGLE_NPC_LIST = function()
			self.show_npc_list = not self.show_npc_list
			self.player.changed = true
		end,

		TACTICAL_DISPLAY = function()
			if Map.view_faction then
				self.always_target = nil
				Map:setViewerFaction(nil)
			else
				self.always_target = true
				Map:setViewerFaction("players")
			end
		end,

		LOOK_AROUND = function()
			self.flash:empty(true)
			self.flash(self.flash.GOOD, "Looking around... (direction keys to select interesting things, shift+direction keys to move freely)")
			local co = coroutine.create(function() self.player:getTarget{type="hit", no_restrict=true, range=2000} end)
			local ok, err = coroutine.resume(co)
			if not ok and err then print(debug.traceback(co)) error(err) end
		end,
	}
	self.key:setCurrent()
end

function _M:setupMouse(reset)
	if reset then self.mouse:reset() end
	self.mouse:registerZone(Map.display_x, Map.display_y, Map.viewport.width, Map.viewport.height, function(button, mx, my, xrel, yrel, bx, by, event)
		-- Handle targeting
		if self:targetMouse(button, mx, my, xrel, yrel, event) then return end

		-- Handle the mouse movement/scrolling
		self.player:mouseHandleDefault(self.key, self.key == self.normal_key, button, mx, my, xrel, yrel, event)
	end)
	-- Scroll message log
	self.mouse:registerZone(self.logdisplay.display_x, self.logdisplay.display_y, self.w, self.h, function(button)
		if button == "wheelup" then self.logdisplay:scrollUp(1) end
		if button == "wheeldown" then self.logdisplay:scrollUp(-1) end
	end, {button=true})
	-- Use hotkeys with mouse
	self.mouse:registerZone(self.hotkeys_display.display_x, self.hotkeys_display.display_y, self.w, self.h, function(button, mx, my, xrel, yrel, bx, by, event)
		self.hotkeys_display:onMouse(button, mx, my, event == "button", function(text) self.tooltip:displayAtMap(nil, nil, self.w, self.h, tostring(text)) end)
	end)
	self.mouse:setCurrent()
end

--- Ask if we really want to close, if so, save the game first
function _M:onQuit()
	self.player:restStop()

	if not self.quit_dialog then
		self.quit_dialog = QuitDialog.new()
		self:registerDialog(self.quit_dialog)
	end
end

--- Requests the game to save
function _M:saveGame()
	-- savefile_pipe is created as a global by the engine
	savefile_pipe:push(self.save_name, "game", self)
	self.log("Saving game...")
end


-- Game Log management functions:
-- logVisible to determine if a message should be visible to the player
-- logMessage to add a message to the display
-- delayedLogMessage to queue an actor-specific message for display at the end of the current game tick
-- displayDelayedLogMessages() to display the queued messages (before combat damage messages)
-- delayedLogDamage to queue a combat (damage) message for display at the end of the current game tick
-- displayDelayedLogDamage to display the queued combat messages

-- output a message to the log based on the visibility of an actor to the player
function _M.logSeen(e, style, ...) 
	if e and e.player or (not e.dead and e.x and e.y and game.level and game.level.map.seens(e.x, e.y) and game.player:canSee(e)) then game.log(style, ...) end 
end

-- determine whether an action between 2 actors should produce a message in the log and if the player
-- can identify them
-- output: src, srcSeen: source display?, identify?
-- tgt, tgtSeen: target display?, identify?
-- output: Visible? and srcSeen (source is identified by the player), tgtSeen(target is identified by the player)
function _M:logVisible(source, target)
	-- target should display if it's the player, an actor in a seen tile, or a non-actor without coordinates
	local tgt = target and (target.player or (target.__is_actor and game.level.map.seens(target.x, target.y)) or (not target.__is_actor and not target.x))
	local tgtSeen = tgt and (target.player or game.player:canSee(target)) or false
	local src, srcSeen = false, false
--	local srcSeen = src and (not source.x or (game.player:canSee(source) and game.player:canSee(target)))
	-- Special cases
	if not source.x then -- special case: unpositioned source uses target parameters (for timed effects on target)
		if tgtSeen then
			src, srcSeen = tgt, tgtSeen
		else
			src, tgt = nil, nil
		end
	else -- source should display if it's the player or an actor in a seen tile, or same as target for non-actors
		src = source.player or (source.__is_actor and game.level.map.seens(source.x, source.y)) or (not source.__is_actor and tgt)
		srcSeen = src and game.player:canSee(source) or false
	end	
	
	return src or tgt or false, srcSeen, tgtSeen
end

-- Generate a message (string) for the log with possible source and target,
-- highlighting the player and taking visibility into account
-- srcSeen, tgtSeen = can player see(identify) the source, target?
-- style text message to display, may contain:
-- #source#|#Source# -> <displayString>..self.name|self.name:capitalize()
-- #target#|#Target# -> target.name|target.name:capitalize()
function _M:logMessage(source, srcSeen, target, tgtSeen, style, ...)
	style = style:format(...)
	local srcname = "something"
	local Dstring
		if source.player then
			srcname = "#fbd578#"..source.name.."#LAST#"
		elseif srcSeen then
			srcname = engine.Entity.check(source, "getName") or source.name or "unknown"
		end
		if srcname ~= "something" then Dstring = source.__is_actor and source.getDisplayString and source:getDisplayString() end
	style = style:gsub("#source#", srcname)
	style = style:gsub("#Source#", (Dstring or "")..srcname:capitalize())
	if target then
		local tgtname = "something"
			if target.player then
				tgtname = "#fbd578#"..target.name.."#LAST#"
			elseif tgtSeen then
				tgtname = engine.Entity.check(target, "getName") or target.name or "unknown"
			end
		style = style:gsub("#target#", tgtname)
		style = style:gsub("#Target#", tgtname:capitalize())
	end
	return style
end

-- log an entity-specific message for display later with displayDelayedLogDamage
-- only one message (processed with logMessage) will be logged for each source and label
-- useful to avoid spamming repeated messages
-- target is optional and is used only to resolve the msg
function _M:delayedLogMessage(source, target, label, msg, ...)
	local visible, srcSeen, tgtSeen = self:logVisible(source, target)
	if visible then
		self.delayed_log_messages[source] = self.delayed_log_messages[source] or {}
		local src = self.delayed_log_messages[source]
		src[label] = self:logMessage(source, srcSeen, target, tgtSeen, msg, ...)
	end
end

-- display the delayed log messages
function _M:displayDelayedLogMessages()
	if not self.uiset or not self.uiset.logdisplay then return end
	for src, msgs in pairs(self.delayed_log_messages) do
		for label, msg in pairs(msgs) do
			game.uiset.logdisplay(self:logMessage(src, true, nil, nil, msg))
		end
	end
	self.delayed_log_messages = {}
end

-- Note: There can be up to a 1 tick delay in displaying log information
function _M:displayDelayedLogDamage()
	if not self.uiset or not self.uiset.logdisplay then return end
	for src, tgts in pairs(self.delayed_log_damage) do
		for target, dams in pairs(tgts) do
			if #dams.descs > 1 then
				game.uiset.logdisplay(self:logMessage(src, dams.srcSeen, target, dams.tgtSeen, "#Source# hits #Target# for %s (%0.0f total damage)%s.", table.concat(dams.descs, ", "), dams.total, dams.healing<0 and (" #LIGHT_GREEN#[%0.0f healing]#LAST#"):format(-dams.healing) or ""))
			else
				if dams.healing >= 0 then
					game.uiset.logdisplay(self:logMessage(src, dams.srcSeen, target, dams.tgtSeen, "#Source# hits #Target# for %s damage.", table.concat(dams.descs, ", ")))
				elseif src == target then
					game.uiset.logdisplay(self:logMessage(src, dams.srcSeen, target, dams.tgtSeen, "#Source# receives %s.", table.concat(dams.descs, ", ")))
				else
					game.uiset.logdisplay(self:logMessage(src, dams.srcSeen, target, dams.tgtSeen, "#Target# receives %s from #Source#.", table.concat(dams.descs, ", ")))
				end
			end
			local rsrc = src.resolveSource and src:resolveSource() or src
			local rtarget = target.resolveSource and target:resolveSource() or target
			local x, y = target.x or -1, target.y or -1
			local sx, sy = self.level.map:getTileToScreen(x, y)
			if target.dead then
				if dams.tgtSeen and (rsrc == self.player or rtarget == self.player or self.party:hasMember(rsrc) or self.party:hasMember(rtarget)) then
					self.flyers:add(sx, sy, 30, (rng.range(0,2)-1) * 0.5, rng.float(-2.5, -1.5), ("Kill (%d)!"):format(dams.total), {255,0,255}, true)
					self:delayedLogMessage(target, nil,  "death", self:logMessage(src, dams.srcSeen, target, dams.tgtSeen, "#{bold}##Source# killed #Target#!#{normal}#"))
				end
			elseif dams.total > 0 or dams.healing == 0 then
				if dams.tgtSeen and (rsrc == self.player or self.party:hasMember(rsrc)) then
					self.flyers:add(sx, sy, 30, (rng.range(0,2)-1) * 0.5, rng.float(-3, -2), tostring(-math.ceil(dams.total)), {0,255,dams.is_crit and 200 or 0}, dams.is_crit)
				elseif dams.tgtSeen and (rtarget == self.player or self.party:hasMember(rtarget)) then
					self.flyers:add(sx, sy, 30, (rng.range(0,2)-1) * 0.5, -rng.float(-3, -2), tostring(-math.ceil(dams.total)), {255,dams.is_crit and 200 or 0,0}, dams.is_crit)
				end
			end
		end
	end
	if self.delayed_death_message then game.log(self.delayed_death_message) end
	self.delayed_death_message = nil
	self.delayed_log_damage = {}
end

-- log and collate combat damage for later display with displayDelayedLogDamage
function _M:delayedLogDamage(src, target, dam, desc, crit)
	if not target or not src then return end
	src = src.__project_source or src -- assign message to indirect damage source if available
	local visible, srcSeen, tgtSeen = self:logVisible(src, target)
	if visible then -- only log damage the player is aware of
		self.delayed_log_damage[src] = self.delayed_log_damage[src] or {}
		self.delayed_log_damage[src][target] = self.delayed_log_damage[src][target] or {total=0, healing=0, descs={}}
		local t = self.delayed_log_damage[src][target]
		t.descs[#t.descs+1] = desc
		if dam>=0 then
			t.total = t.total + dam
		else
			t.healing = t.healing + dam
		end
		t.is_crit = t.is_crit or crit
		t.srcSeen = srcSeen
		t.tgtSeen = tgtSeen
	end
end
