-- This is free and unencumbered software released into the public domain.
-- 
-- Anyone is free to copy, modify, publish, use, compile, sell, or
-- distribute this software, either in source code form or as a compiled
-- binary, for any purpose, commercial or non-commercial, and by any
-- means.
-- 
-- In jurisdictions that recognize copyright laws, the author or authors
-- of this software dedicate any and all copyright interest in the
-- software to the public domain. We make this dedication for the benefit
-- of the public at large and to the detriment of our heirs and
-- successors. We intend this dedication to be an overt act of
-- relinquishment in perpetuity of all present and future rights to this
-- software under copyright law.
-- 
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
-- OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
-- ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
-- OTHER DEALINGS IN THE SOFTWARE.
-- 
-- For more information, please refer to <http://unlicense.org/>

require("factorio_react_mobx");

-- newObservableTable() - creates a table which monitors it's fields for changes.
-- use this tables to store data which you want to render in UI
obsTable1 = newObservableTable()

-- Initial values for UI's data
obsTable1.ui_visible = true
obsTable1.items_count = 3

function safePrint(s)
	if game and game.players and game.players[1] then
		game.players[1].print(s)
	end
end

function declarative_ui() 
	-- This function describes your UI.
	
	-- This function should be called just once.
	-- Futher refreshes of UI are triggered by observable tables when their fields are changed.
	-- UI elements properties can be changed or triggered "on" and off with conditional operations (if or inline-if: (XXX and YYY or ZZZ) )
	-- You can also create UI elements with loops
	-- All the UI state should depend solely on observable tables
	
	-- "useObserver" callback will be called again every time when any observable table which was used inside it is changed
	-- "render" function is kind of "smart": it builds so called "shadow-DOM" - a tree of lua-tables which reassembles UI structure and than it tracks for changes
	--		so "render" won't actually recreate you UI every time, it will try to recreate it only when it's unavoidable.
	--		all the other times "render" would just set some props to existing UI.

	safePrint("factorio_react_mobx.declarative_ui - started")
	
	useObserver(function() 
		safePrint("factorio_react_mobx.useObserver - called")

		-- conditional ui example
		local conditional_ui = obsTable1.cond1 and { -- <== note the brace here - should be array of ui items!
			{type="flow", direction="horizontal", children={
				{ type="label", caption="looses value because of update" },
				{ type="text-box", text="abc "..(obsTable1.tick or "none") },
			}},		
		} or nil;
		
		-- loop example
		local loop_items = {}
	    for i=1,obsTable1.items_count do 
			loop_items[i] = {type="flow", name="fitem"..i, direction="horizontal", children={
				{ type="label", name="item1", caption="item "..tostring(i).." text" },
				{ type="text-box", name="item2", text="item "..tostring(i).." text" },
			}}
		end
		
		local player = game.players[1]
		local parent = player.gui.center
				render(player.gui.center, {
				name="combinissimo_entity_ui",
				type=(obsTable1.ui_visible and "frame" or nil), -- Use this condition to hide and show root element
				caption="An example UI", 
				children={
						{type="flow", name="f1", direction="vertical", children={
							{type="flow", name="f1", direction="horizontal", children={
								{ type="label", name="i1", caption="looses value because of update" },
								{ type="text-box", name="i2", text="abc "..(obsTable1.tick or "none") },
							}},
							{type="flow", name="f3", direction="horizontal", children={
								{ type="label", name="item1", caption="Isn't updated. Will store its value" },
								{ type="text-box", name="item2", text="123" },
							}},						
							{type="flow", name="f4", direction="horizontal", children={
								{ type="button",  name="i1", caption="Open" },
								{ type="button",  name="i2", caption="Close" },
							}},
							{type="slider", name="f5"},							
							loop_items,
						}}
				},				
			})
		end)
	
	safePrint("factorio_react_mobx.declarative_ui - finished")
end

function change_the_data() 
	-- This function changes data in observable table - to emulate some action
	-- Normally you should save all the state you want to display in UI to such table
	-- If you want to store some tables inside this table - consider using newObservableTable() to organize nested observable tables
	safePrint("factorio_react_mobx.change_the_data - called")
	
	-- Change textbox value every once a while
	if ((game.tick+2*60) % (60 * 2))<1 then
		obsTable1.tick = game and game.tick or 0
	end
	
	if ((game.tick+2*60) % (60 * 10))<1 then
		-- restore UI every 10 seconds
		obsTable1.ui_visible = true
	end
end

local on_tick_handler_once = false


script.on_event(defines.events.on_tick, function(event)
	if not on_tick_handler_once then
		on_tick_handler_once = true
		safePrint("factorio_react_mobx.on_tick_handler_once - begin")
		declarative_ui()
		safePrint("factorio_react_mobx.on_tick_handler_once - end")
	end
	
	change_the_data() 	
	ui_handle_updates()
end) 
