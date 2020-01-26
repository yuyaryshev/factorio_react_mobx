-- USAGE: 
-- It's a single file library. Just copy factorio_react_mobx.lua to your projects, require it and use the functions

-- Small documetation here:
-- obsTable1 = newObservableTable()				-- Use this observable tables to store your state
-- useObserver(callback)						-- Call like this so your callback be re-called when any observable values it uses are changed. Usually this is used togather with render, but can also be used separately.
-- render(parent_ui, ui_nodes)					-- render the UI. Shoud be called inside useObserver's callback, so you'll get re-renders when state changes
-- ui_handle_updates()							-- Call in on_tick to handle all the updates


-- Internal functions
-- ui_concat(a1,a2,a3,...)						-- Concatenates and flattens UI items or array of UI items into one array, it also skips nil values. Can work with any depth in arrays


-- Implementation from stackoverflow: answered Sep 22 '14 at 14:32 Hisham H M
function ui_deep_equal(a, b)
   local avoid_loops = {}
   local function recurse(t1, t2)
      -- compare value types
      if type(t1) ~= type(t2) then return false end
      -- Base case: compare simple values
      if type(t1) ~= "table" then return t1 == t2 end
      -- Now, on to tables.
      -- First, let's avoid looping forever.
      if avoid_loops[t1] then return avoid_loops[t1] == t2 end
      avoid_loops[t1] = t2
      -- Copy keys from t2
      local t2keys = {}
      local t2tablekeys = {}
      for k, _ in pairs(t2) do
         if type(k) == "table" then table.insert(t2tablekeys, k) end
         t2keys[k] = true
      end
      -- Let's iterate keys from t1
      for k1, v1 in pairs(t1) do
         local v2 = t2[k1]
         if type(k1) == "table" then
            -- if key is a table, we need to find an equivalent one.
            local ok = false
            for i, tk in ipairs(t2tablekeys) do
               if table_eq(k1, tk) and recurse(v1, t2[tk]) then
                  table.remove(t2tablekeys, i)
                  t2keys[tk] = nil
                  ok = true
                  break
               end
            end
            if not ok then return false end
         else
            -- t1 has a key which t2 doesn't have, fail.
            if v2 == nil then return false end
            t2keys[k1] = nil
            if not recurse(v1, v2) then return false end
         end
      end
      -- if t2 has a key which t1 doesn't have, fail.
      if next(t2keys) then return false end
      return true
   end
   return recurse(a, b)
end

require("update_ui_funcs");

function get_ui_full_path(ui, suffix)
	return (ui and ui.parent and get_ui_full_path(ui.parent).."." or "") .. (ui and ui.name or "") .. (suffix and "."..suffix or "")
end

local function ui_concat_internal(r, v)
	if v then 
--		if game and game.players and game.players[1] then game.players[1].print("UIC0001 "..serpent.line(v)) end	
		
		local arg_type = type(v)
		if arg_type ~= "table" then
			error("ui_concat expects all args to be UI items or arrays of UI items or nil values, but got '"..arg_type.."'")
		else
			if v.type then 
				-- It's a single UI items
--				if game and game.players and game.players[1] then game.players[1].print("UIC0002 "..serpent.line(v)) end	
				table.insert(r, v)
			else
--				if game and game.players and game.players[1] then game.players[1].print("UIC0003 "..serpent.line(v)) end	
			
				-- It's an array of UI items - flatted it
				for _, vv in ipairs(v) do
--					if game and game.players and game.players[1] then game.players[1].print("UIC0004 "..serpent.line(vv)) end	
					ui_concat_internal(r, vv)
				end
			end
		end		
	end
end

function ui_concat(...)
	local args = {...}
	local r = {}
	ui_concat_internal(r, args)
	return r
end

local current_observer = nil

function useObserver(callback)
	local observedCallback 
	observedCallback = function() 
		local old_observer = current_observer
		current_observer = observedCallback
		callback()
		current_observer = old_observer
	end
	observedCallback()
end

function render_one(ui_parent, new_node, old_node)
--	if game then
--		game.players[1].print("render_one " .. get_ui_full_path(ui_parent, new_node.name))
--	end
	
	if not new_node.type then
		if old_node and old_node.ui then
			old_node.ui.destroy()
		end
	else
		if not new_node.name then
			error("factorio_react_mobx requires each UI node to have a non-empty name. The name should be unique on it's tree level")
		end
		update_ui_funcs[new_node.type](ui_parent, new_node, old_node)
		
		-- Recurse to children
		if new_node.children then
			render_array(new_node.ui, ui_concat(new_node.children), old_node and old_node.children or {})
		else
			if old_node and old_node.children and #old_node.children then
				for k,v in old_node.children do
					v.ui.destroy()
				end
			end
		end		
	end
end

function render_array(ui_parent, new_nodes, old_nodes)
	-- Delete old_nodes and their UI 
	--		If the node doesn't exist anymore
	-- 		If new node isn't compartible with old one
	
	for k,old_node in pairs(old_nodes) do
		local new_node = new_nodes[k]
		if old_node and not (new_node or new_node.type ~= old_node.type) then
			old_nodes[k].ui.destroy()
			old_nodes[k].ui = nil
			old_nodes[k] = nil
		end
	end
	
	-- Walk all new_nodes
	for k,new_node in pairs(new_nodes) do
		-- Set new properties
		render_one(ui_parent, new_node, old_nodes[k])
	end
end

local all_old_nodes = {}


function render(ui_parent, new_node)
	if not new_node.name then
		error("Can't render without root name. If you need to hide ui - please set type = nil instead. Root name should never change.")
	end
	local ui_full_path = get_ui_full_path(ui_parent, new_node.name)
	local old_node = all_old_nodes[ui_full_path]
	all_old_nodes[ui_full_path] = new_node
	
	render_one(ui_parent, new_node, old_node)
end

--============================= Mobx implementation ====================================================

local recall_array = {}
local prv = {}
local bindings_prv = {}

-- create metatable
local mt = {
  __index = function (proxy,k)
	if k~=prv and k~=bindings_prv and current_observer then
		if not proxy[bindings_prv][k] then
			proxy[bindings_prv][k] = {}
		end
		table.insert(proxy[bindings_prv][k], current_observer)
	end
	return proxy[prv][k]   -- access the original table
  end,

  __newindex = function (proxy,k,v)
	proxy[prv][k] = v   -- update original table
	if proxy[bindings_prv][k] then
		local tmp = proxy[bindings_prv][k]
		proxy[bindings_prv][k] = nil
		for _, refresh_func in ipairs(tmp) do
			table.insert(recall_array, refresh_func)  -- Can't call refresh_func directly because this will create infinity stack in Lua
		end
	end
  end
}

function newObservableTable()
  local proxy = {}
  proxy[prv] = {}
  proxy[bindings_prv] = {}
  setmetatable(proxy, mt)
  return proxy
end


function ui_handle_updates()
	if #recall_array then
		--if game and game.players and game.players[1] then game.players[1].print("factorio_react_mobx.ui_handle_updates - updated!") end	
		
		local tmp = recall_array
		recall_array = {}
		for _, refresh_func in ipairs(tmp) do
			refresh_func()
		end
	end
end

