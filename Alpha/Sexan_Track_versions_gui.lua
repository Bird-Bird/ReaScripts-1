--[[
 * eaScript Name: Sexan_Track_versions_v2_gui.lua
 * About: Protools style playlist, track versions (Cubase)
 * Author: SeXan
 * Licence: GPL v3
 * REAPER: 5.0
 * Extensions: SWS, JS API
 * Version: 0.0.1
 * Provides  
    [nomain] Sexan_Track_versions_core.lua
--]]
--[[
 * Changelog:
 * v0.0.1 (2019-02-22)
  + Initial release of new port code
--]]
package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;" -- GET DIRECTORY FOR REQUIRE
-- Scrip --ct generated by Lokasenna's GUI Builder
local lib_path = reaper.GetExtState("Lokasenna_GUI", "lib_path_v2")
if not lib_path or lib_path == "" then
  reaper.MB(
    "Couldn't load the Lokasenna_GUI library. Please run 'Set Lokasenna_GUI v2 library path.lua' in the Lokasenna_GUI folder.",
    "Whoops!",
    0
  )
  return
end
loadfile(lib_path .. "Core.lua")()

GUI.req("Classes/Class - Options.lua")()
GUI.req("Classes/Class - Listbox.lua")()
GUI.req("Classes/Class - Button.lua")()
GUI.req("Classes/Class - Label.lua")()
GUI.req("Classes/Class - Frame.lua")()
GUI.req("Classes/Class - Tabs.lua")()
GUI.req("Classes/Class - Menubox.lua")()
GUI.req("Classes/Class - Window.lua")()
-- If any of the requested libraries weren't found, abort the script.
if missing_lib then
  return 0
end

require("Sexan_track_versions_core") -- CORE PLAYLIST SCRIPT

local retval, last_project = reaper.EnumProjects(-1, "")
save_path = reaper.GetProjectPath("") .. "/"
save_name = "TrackVersionDATA.txt"
fn = save_path .. save_name

GUI.name = "Track Versions"
GUI.x, GUI.y, GUI.w, GUI.h = 0, 0, 315, 320
GUI.anchor, GUI.corner = "mouse", "C"
GUI.elms_hide[10] = true -- 10 is for hiding
GUI.elms_hide[7] = true -- 10 is for hiding
GUI.elms_hide[6] = true -- 10 is for hiding
--------------------------------------------------
local last_tr, cur_tr
local last_proj_change_count = reaper.GetProjectStateChangeCount(0)
---------------------------------------------------------------------------------
SHOW, COMP, VIEW = 0, 0, 0
---------------------------------------------------
function update_menubox(val)
  for i = 1, #GUI.elms.Menubox1.optarray do
    if val == GUI.elms.Menubox1.optarray[i] then
      GUI.Val("Menubox1", i)
    end
  end
end

function to_number(value)
  return value and 1 or 0
end

function to_bool(value)
  if value == 1 then
    return true
  else
    return false
  end
end

-- THIS IS ABSOLUTELLY NECESSARY BECAUSE GUI.Val RETURNS RANDOM NUMBERS BECAUSE OF INTERNAL "PAIRS"
function update_listbox(num)
  GUI.elms.Listbox1.retval = {}
  GUI.elms.Listbox1.retval[num] = true
  GUI.elms.Listbox1:redraw()
end

function populate_listbox(tbl)
  local tab = GUI.Val("Tabs1")
  if tab == 2 then
    local _, _, env_list = get_envelope_track(cur_tr) -- POPULATE MENU BOX WITH ALL TRACKS ENVELOPES
    if env_list then
      GUI.elms.Menubox1.optarray = env_list
    else
      GUI.elms.Menubox1.optarray = {"Empty"}
    end
    GUI.elms.Menubox1:redraw()
  end
  GUI.elms.Listbox1.guid = nil -- WE ALWAYS MUST RESET THE CHECKBOX (IF NO TRACKS ARE SELECTED)
  GUI.elms.Listbox1.list = {} -- EMPTY THE TABLE FOR NEW ELEMTNTS
  GUI.elms.Menubox2.optarray = {"Empty"}
  if tbl then
    local num, data
    if tab == 1 then
      if not tbl.data then
        GUI.elms.Listbox1:redraw()
        return
      end
      num, data = tbl.data.num, tbl.data
    elseif tab == 2 then
      local last = GUI.elms.Menubox1.optarray[GUI.Val("Menubox1")] -- SELECTED MENUBOX
      if not tbl[last] then
        GUI.elms.Listbox1:redraw()
        return
      end -- NO VERSIONS IN SELECTED MENUBOX
      num, data = tbl[last].num, tbl[last] -- GET ONLY ENVELOPES THAT HAVE SAME NAME AS MENUBOX
    elseif tab == 3 then
      if not tbl.fx then
        GUI.elms.Listbox1:redraw()
        return
      end
      data, num = tbl.fx, tbl.fx.fx_num
    end
    for i = 1, #data do
      GUI.elms.Listbox1.list[i] = data[i].name -- ADD TO TABLE
      GUI.elms.Menubox2.optarray[i] = data[i].name
    end
    update_listbox(num)
  end
  GUI.elms.Menubox2:redraw()
end

function new_version(tab)
  local tab = GUI.Val("Tabs1")
  if GUI.Val("Label1"):find("FOLDER") then
    on_click_function(create_folder, "V", tab) -- CREATE FOLDER
  else
    local name = GUI.elms.Menubox1.optarray[GUI.Val("Menubox1")]
    create_envelope(cur_tr, name, tab, "V", name)
    on_click_function(create_track, "V", tab) -- CREATE TRACK
    create_fx(cur_tr, tab, "V")
  end
  reaper.UpdateArrange()
  populate_listbox(find_guid(cur_tr)) -- MOVE DATA TO CHECKBOX
  save_tracks()
end

function duplicate()
  local tab = GUI.Val("Tabs1")
  local d_name = GUI.elms.Listbox1.list[GUI.Val("Listbox1")]
  if GUI.Val("Label1"):find("FOLDER") then
    on_click_function(create_folder, "D", tab, d_name) -- CREATE FOLDER
  else
    local name = GUI.elms.Menubox1.optarray[GUI.Val("Menubox1")]
    create_envelope(cur_tr, name, tab, "D", d_name)
    on_click_function(create_track, "D", tab, d_name) -- CREATE TRACK
    create_fx(cur_tr, tab, "D", d_name)
  end
  reaper.UpdateArrange()
  populate_listbox(find_guid(cur_tr)) -- MOVE DATA TO CHECKBOX
  save_tracks()
end

function delete()
  local tab = GUI.Val("Tabs1")
  local tbl = find_guid(cur_tr)
  if not tbl then
    return
  end
  reaper.PreventUIRefresh(1)
  if tab == 1 then
    local cur_val = GUI.Val("Listbox1")
    delete_from_table(tbl.data, cur_val, cur_tr, tab)
    if not tbl.data then
      populate_listbox(tbl)
      return
    end
    if SHOW == 1 then
      sort_fipm(tbl.guid)
    end -- MAYBE A BETTER WAY JUST TO DELETE ITEMS WHICH HAS NO NUM CORDINATE
    restoreTrackItems(tbl.guid, tbl.data.num)
    reaper.PreventUIRefresh(-1)
  elseif tab == 2 then
    local cur_env = GUI.elms.Menubox1.optarray[GUI.Val("Menubox1")]
    delete_from_table(tbl[cur_env], cur_val, cur_tr, tab, cur_env)
    if not tbl[cur_env] then
      populate_listbox(tbl)
      return
    end
    restore_envelope(tbl.guid, cur_env, tbl[cur_env].num)
  elseif tab == 3 then
    delete_from_table(tbl.fx, cur_val, cur_tr, tab)
    if not tbl.fx then
      populate_listbox(tbl)
      return
    end
    restore_fx(tbl, tbl.fx.fx_num)
  end
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  populate_listbox(tbl)
end

function rename()
  local tab = GUI.Val("Tabs1")
  local cur_val = GUI.Val("Listbox1") -- GET CURRENT VALUE
  local cur_env = GUI.elms.Menubox1.optarray[GUI.Val("Menubox1")]
  local tbl = find_guid(cur_tr)
  if not tbl then
    return
  end
  local retval, rename = reaper.GetUserInputs("Rename Version ", 1, "Version Name :", "")
  if not retval or version_name == "" then
    return
  end
  if tab == 1 then
    if not tbl.data then
      return
    end
    tbl.data[cur_val].name = rename
  elseif tab == 2 then
    if not tbl[cur_env] then
      return
    end
    tbl[cur_env][cur_val].name = rename
  elseif tab == 3 then
  end
  populate_listbox(tbl)
  save_tracks()
end

local function to(param)
  TO = to_number(param)
  --if COMP == 1 then return end
  if not param then
    TO = nil
  end
  GUI.elms.Copy_To.state = to_number(param)
  GUI.elms.Copy_To.params[1] = not param
end

cur_comp_id = nil
local function comp(param)
  COMP = to_number(param)
  if TO == 1 then
    return
  end
  if param then
    cur_comp_id = reaper.genGuid()
  else
    cur_comp_id = nil
  end
  GUI.elms.Comp.state = to_number(param)
  GUI.elms.Comp.params[1] = not param
end

function merge()
  local tbl = find_guid(cur_tr)
  if tbl.stored_num ~= tbl.num then
    tbl.data[tbl.stored_num].chunk = getTrackItems(reaper.BR_GetMediaTrackByGUID(0, cur_tr))
  end -- PREVENT STORING CURRENT VERSION (CHUNK IS THE SAME)
end

local function view_ts(param)
  VIEW = to_number(param)
  if SHOW == 1 then
    return
  end
  --if GUI.Val("Tabs1") == 2 then return end -- ENVELOPES
  local tracks = get_tracks()
  reaper.PreventUIRefresh(1)
  local cur_menu = GUI.elms.Menubox1.optarray[GUI.Val("Menubox1")]
  for i = 1, #tracks do
    local track = find_guid(tracks[i])
    if not track then
      return
    end
    if param then
      if GUI.Val("Tabs1") == 1 then
        if not track.data then
          return
        end
        track.stored_num, track.stored_version = track.data.num, track.data[track.data.num].ver_id
      elseif GUI.Val("Tabs1") == 2 then
        if not track[cur_menu] then
          return
        end
        track.stored_num, track.stored_version = track[cur_menu].num, track[cur_menu][track[cur_menu].num].ver_id
      elseif GUI.Val("Tabs1") == 3 then
        return
      end
    else
      if GUI.Val("Tabs1") == 1 then
        if track.stored_num ~= track.data.num then
          restoreTrackItems(track.guid, track.stored_num)
        end -- DO NOT RESTORE SAME VERSIONS
        track.data.num = track.stored_num -- RESTORE ORIGINAL VERSION
        track.stored_num, track.stored_version = nil, nil
        update_listbox(track.data.num) -- CHECK ORIGINAL VERSION
      elseif GUI.Val("Tabs1") == 2 then
        if track.stored_num ~= track[cur_menu].num then
          restore_envelope(track.guid, cur_menu, track.stored_num)
        end -- ADD WAY NOT TO TRIGGER SAME VERSION AGAIN
        track[cur_menu].num = track.stored_num -- RESTORE ORIGINAL VERSION
        track.stored_num, track.stored_version = nil, nil
        update_listbox(track[cur_menu].num) -- CHECK ORIGINAL VERSION
      end
    end
  end
  reaper.PreventUIRefresh(-1)
  if param then
    GUI.elms.Merge.z = 11
  else
    GUI.elms.Merge.z = 10
  end
  GUI.elms.View_TS.state = to_number(param)
  GUI.elms.View_TS.params[1] = not param
  reaper.UpdateArrange()
end

function show_all(param)
  SHOW = to_number(param)
  local tracks = get_tracks()
  for i = 1, #tracks do
    set_track_fipm(tracks[i], SHOW)
    if param then
      sort_fipm(tracks[i])
    else
      clear_muted_items(tracks[i])
    end
  end
  GUI.elms.Show_All.state = to_number(param)
  GUI.elms.Show_All.params[1] = not param
  reaper.UpdateTimeline()
end

GUI.New(
  "Listbox1",
  "Listbox",
  {
    z = 9,
    x = 108,
    y = 108,
    w = 195,
    h = 200,
    list = "",
    multi = false,
    caption = "",
    font_a = 3,
    font_b = 4,
    color = "txt",
    col_fill = "elm_fill",
    bg = "elm_bg",
    cap_bg = "wnd_bg",
    shadow = true,
    pad = 4,
    last_num = "",
    last_env_num = ""
  }
)
function GUI.elms.Listbox1:onmouseup()
  GUI.Listbox.onmouseup(self)
  local tab = GUI.Val("Tabs1")
  local cur_val = GUI.Val("Listbox1") -- GET CURRENT VALUE
  local tbl = find_guid(cur_tr)
  if #self.list == 0 then
    return
  end -- IF EMPTY DO NOTHING
  reaper.PreventUIRefresh(1)
  if tab == 1 then -- TRACK MODE
    --restoreTrackItems(self.guid,cur_val)
    do_tracks(restoreTrackItems, cur_val) -- DO FOR ALL SELECTED TRACKS
  elseif tab == 2 then -- ENVELOPE MODE
    local cur_menu = GUI.elms.Menubox1.optarray[GUI.Val("Menubox1")]
    restore_envelope(cur_tr, cur_menu, cur_val)
  elseif tab == 3 then
    restore_fx(tbl, cur_val)
  end
  save_tracks()
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
end

GUI.New(
  "Tabs1",
  "Tabs",
  {
    z = 11,
    x = 108,
    y = 67,
    w = 912.0,
    caption = "Tabs1",
    optarray = {"Lane", "Envelope", "FX"},
    tab_w = 48,
    tab_h = 20,
    pad = 8,
    font_a = 3,
    font_b = 4,
    col_txt = "txt",
    col_tab_a = "wnd_bg",
    col_tab_b = "tab_bg",
    bg = "elm_bg",
    fullwidth = false
  }
)
GUI.elms.Tabs1:update_sets(
  --  Tab   Layers
  {
    [1] = {5},
    [2] = {8},
    [3] = {4}
  }
)

function GUI.elms.Tabs1:onmouseup()
  GUI.Tabs.onmouseup(self)
  populate_listbox(find_guid(cur_tr))
end

GUI.New(
  "Menubox1",
  "Menubox",
  {
    z = 8,
    x = 108,
    y = 88,
    w = 140,
    h = 20,
    caption = "",
    optarray = {"Empty"},
    retval = 1,
    font_a = 3,
    font_b = 4,
    col_txt = "txt",
    col_cap = "txt",
    bg = "wnd_bg",
    pad = 4,
    noarrow = false,
    align = 0
  }
)

GUI.New(
  "Menubox2",
  "Menubox",
  {
    z = 5,
    x = 168,
    y = 88,
    w = 80,
    h = 20,
    caption = "Copy To -",
    optarray = {"Empty"},
    retval = 1,
    font_a = 3,
    font_b = 4,
    col_txt = "txt",
    col_cap = "txt",
    bg = "wnd_bg",
    pad = 4,
    noarrow = false,
    align = 0
  }
)

function GUI.elms.Menubox2:onmouseup()
  GUI.Menubox.onmouseup(self)
  if self.optarray[1] == "Empty" then
    return
  end
  GUI.Val("Menubox2", GUI.Val("Menubox2")) -- SET OPTION
  find_guid(cur_tr).data.dest = GUI.Val("Menubox2")
end

function GUI.elms.Menubox1:onmouseup()
  GUI.Menubox.onmouseup(self)
  if self.optarray[1] == "Empty" then
    return
  end
  GUI.Val("Menubox1", GUI.Val("Menubox1")) -- SET OPTION
  populate_listbox(find_guid(cur_tr)) -- UPDATE LISTBOX
end

function groups(params)
  local group = GUI.Val("GroupList")
  if TrackTB.groups then
    GUI.elms.Listbox2.list = TrackTB.groups[group]
  end
  GUI.elms.Window:open()
  GUI.elms.Listbox2:redraw()
end

function add_to_group()
  if not cur_tr then
    return
  end
  local group = GUI.Val("GroupList")
  if not TrackTB.groups then
    TrackTB.groups = {}
  end
  if TrackTB.groups[group] == nil then
    TrackTB.groups[group] = {}
  end -- create table
  for i = 1, reaper.CountSelectedTracks() do
    local tr = reaper.GetTrackGUID(reaper.GetSelectedTrack(0, i - 1))
    if not has_undo(TrackTB.groups[group], tr) then
      TrackTB.groups[group][#TrackTB.groups[group] + 1] = tr
    end -- DO NOT ADD SAME TRACKS TO TABLE
  end
  save_tracks()
  GUI.elms.Listbox2.list = TrackTB.groups[group]
  GUI.elms.Listbox2:redraw()
end

function remove_from_group()
  local sel_listbox_item = GUI.Val("Listbox2") -- GET GROUP
  local group = GUI.Val("GroupList") -- GET LIST ITEM
  table.remove(TrackTB.groups[group], sel_listbox_item) -- REMOVE ITEM FROM TABLE
  if #TrackTB.groups[group] == 0 then
    TrackTB.groups[group] = nil
  end -- IF TABLE IS EMPTY DELETE TABLE
  if #TrackTB.groups == 0 then
    TrackTB.groups = nil
  end
end

GUI.New(
  "Listbox2",
  "Listbox",
  {
    z = 6,
    x = 100,
    y = 80,
    w = 129,
    h = 205,
    list = {},
    multi = false,
    caption = "",
    font_a = 3,
    font_b = 4,
    color = "txt",
    col_fill = "elm_fill",
    bg = "elm_bg",
    cap_bg = "wnd_bg",
    shadow = true,
    pad = 4,
    last_num = "",
    last_env_num = ""
  }
)
GUI.New(
  "GroupList",
  "Radio",
  {
    z = 6,
    x = 35,
    y = 45,
    w = 50,
    h = 240,
    caption = "GROUP",
    optarray = {"1", "2", "3", "4", "5", "6", "7", "8", "9"},
    dir = "v",
    font_a = 2,
    font_b = 3,
    col_txt = "txt",
    col_fill = "elm_fill",
    bg = "wnd_bg",
    frame = true,
    shadow = true,
    swap = nil,
    opt_size = 20
  }
)
GUI.New(
  "Add",
  "Button",
  {z = 6, x = 100, y = 48, w = 58, h = 24, caption = "Add", font = 3, col_txt = "txt", func = add_to_group}
)
GUI.New(
  "Remove",
  "Button",
  {z = 6, x = 170, y = 48, w = 58, h = 24, caption = "Remove", font = 3, col_txt = "txt", func = remove_from_group}
)
GUI.New(
  "Window",
  "Window",
  {z = 7, x = 15, y = 8, w = 235, h = 300, caption = "Multi Edit Groups", z_set = {6, 7}, center = true}
)
------------------------------------------------------------------------------------------------------------------------------
GUI.New("Label1", "Label", {z = 9, x = 20, y = 11, caption = "", font = 2, color = "txt", bg = "wnd_bg", shadow = true})
GUI.New(
  "Frame1",
  "Frame",
  {
    z = 11,
    x = 15,
    y = 8,
    w = 233,
    h = 26,
    shadow = false,
    fill = false,
    color = "elm_frame",
    bg = "wnd_bg",
    round = 0,
    text = "",
    txt_indent = 0,
    txt_pad = 0,
    pad = 4,
    font = 4,
    col_txt = "txt"
  }
)
GUI.New(
  "Groups",
  "Button",
  {
    z = 11,
    x = 14,
    y = 42,
    w = 78,
    h = 24,
    caption = "Groups",
    font = 3,
    col_txt = "txt",
    func = groups,
    params = {true}
  }
)
GUI.New(
  "NewVersion",
  "Button",
  {
    z = 11,
    x = 14,
    y = 88,
    w = 78,
    h = 24,
    caption = "New Version",
    font = 3,
    col_txt = "txt",
    func = new_version,
    params = {GUI.Val("Tabs1")}
  }
)
GUI.New(
  "Duplicate",
  "Button",
  {z = 11, x = 14, y = 118, w = 78, h = 24, caption = "Duplicate", font = 3, col_txt = "txt", func = duplicate}
)
GUI.New(
  "Delete",
  "Button",
  {z = 11, x = 14, y = 158, w = 78, h = 24, caption = "Delete", font = 3, col_txt = "txt", func = delete}
)
GUI.New(
  "Rename",
  "Button",
  {z = 11, x = 14, y = 188, w = 78, h = 24, caption = "Rename", font = 3, col_txt = "txt", func = rename}
)
GUI.New(
  "Copy_To",
  "Button",
  {z = 11, x = 14, y = 218, w = 78, h = 24, caption = "Copy To", font = 3, col_txt = "txt", func = to, params = {true}}
)
GUI.New(
  "View_TS",
  "Button",
  {
    z = 11,
    x = 14,
    y = 258,
    w = 78,
    h = 24,
    caption = "View TS",
    font = 3,
    col_txt = "txt",
    func = view_ts,
    params = {true}
  }
)
GUI.New(
  "Show_All",
  "Button",
  {
    z = 11,
    x = 108,
    y = 42,
    w = 64,
    h = 20,
    caption = "Show All",
    font = 3,
    col_txt = "txt",
    func = show_all,
    params = {true}
  }
)
GUI.New(
  "Comp",
  "Button",
  {z = 11, x = 184, y = 42, w = 64, h = 20, caption = "Comp", font = 3, col_txt = "txt", func = comp, params = {true}}
)
GUI.New(
  "Merge",
  "Button",
  {z = 10, x = 14, y = 288, w = 78, h = 24, caption = "Merge", font = 3, col_txt = "txt", func = merge}
)

GUI.New(
  "TEST",
  "Button",
  {z = 10, x = 224, y = 42, w = 64, h = 20, caption = "test", font = 3, col_txt = "txt", func = test}
)

function GUI.elms.GroupList:onmouseup()
  GUI.Radio.onmouseup(self)
  local num = GUI.Val("GroupList")
  if TrackTB.groups[num] == nil then
    GUI.elms.Listbox2.list = {}
  else
    GUI.elms.Listbox2.list = TrackTB.groups[num]
  end
  GUI.elms.Listbox2:redraw()
end
------------------------------------------------
---  Function: CHECK IF PROJECT IS THE SAME  ---
------------------------------------------------
function check_project_path()
  local retval, projfn = reaper.EnumProjects(-1, "")
  if last_project ~= projfn then
    save_path = reaper.GetProjectPath("") .. "/"
    fn = save_path .. save_name
    restore()
    last_proj_change_count = reaper.GetProjectStateChangeCount(0)
    last_project = projfn
  end
end

function mouse_click(click, tbl, mouse_ver)
  if click == 1 then
    down = true
    if not hold then
      mute_view(tbl, mouse_ver)
      if mouse_ver then
        tbl.data.num = mouse_ver
      end
      hold = true
    end
  end
  if down then
    if click == 0 then
      down, hold = nil
    end
  end
end
--- FIPM MENU
function menu(tbl, mouse_ver, job, fipm)
  local d_name, cur_name = "", "empty|<|"
  local menu_options = {
    [1] = "Version ",
    [2] = "Create New",
    [3] = "Duplicate",
    [4] = "Delete",
    [5] = "Rename|",
    [6] = "Destination",
    [7] = "Comping|",
    [8] = "Copy To|",
    [9] = "Show All"
  }
  local tmp1, tmp2
  if GUI.elms.Comp.state == 1 then
    tmp1 = "!"
  else
    tmp1 = ""
  end
  if GUI.elms.Copy_To.state == 1 then
    tmp2 = "!"
  else
    tmp2 = ""
  end
  if tbl then
    d_name = GUI.elms.Listbox1.list[tbl.data.dest]
  end
  menu_options[6] = menu_options[6] .. " - " .. d_name .. "|"
  menu_options[6] = tmp1 .. menu_options[6]
  menu_options[7] = tmp2 .. menu_options[7]

  gfx.x, gfx.y = gfx.mouse_x, gfx.mouse_y
  if not job then
    menu_options[1] = "#" .. menu_options[1] .. tbl.data[tbl.data.num].name .. "|"
  else
    local cur_val = GUI.Val("Listbox1") -- GET CURRENT VALUE
    local str = ""
    for i = 1, #GUI.elms.Listbox1.list do
      local tmp_str = GUI.elms.Listbox1.list[i]
      if i == cur_val then
        tmp_str = "!" .. tmp_str
      end
      str = str .. "|" .. tmp_str
    end
    if tbl then
      cur_name = GUI.elms.Listbox1.list[cur_val] .. str .. "|<|"
    end
    menu_options[1] = ">" .. menu_options[1] .. " - " .. cur_name
  end

  if tbl then
    num = tbl.data.num
  else
    num = 0
  end
  if not job then
    num = mouse_ver
  end

  local m_num = gfx.showmenu(table.concat(menu_options, "|"))
  if not tbl then
    m_num = m_num - 1
  end
  if m_num == 0 then
    return
  end -- IF NOTHING IS CLICKED THEN RETURN
  if job then
    m_num = #GUI.elms.Listbox1.list - m_num
  end
  m_num = (m_num * -1) + 1
  if m_num < 2 and tbl then
    sub_num = (m_num + #GUI.elms.Listbox1.list) - 1
    restoreTrackItems(tbl.guid, sub_num)
    reaper.UpdateArrange()
  end

  if m_num == 2 then -- CREATE NEW
    new_version()
  elseif m_num == 3 then -- DUPLICATE
    duplicate()
  elseif m_num == 4 then -- DELETE
    delete()
  elseif m_num == 5 then -- RENAME
    rename()
  elseif m_num == 6 then -- SET DESTINATION
    GUI.Val("Menubox2", num)
    tbl.data.dest = mouse_ver
  elseif m_num == 7 then -- COMP
    local comp_param = GUI.elms.Comp.state
    comp(not to_bool(comp_param))
    GUI.elms.Comp:redraw()
  elseif m_num == 8 then -- COPY
    local copy_param = GUI.elms.Copy_To.state
    to(not to_bool(copy_param))
    GUI.elms.Copy_To:redraw()
  elseif m_num == 9 then -- SHOW ALL
    show_all(not to_bool(fipm))
    GUI.elms.Show_All:redraw()
    reaper.UpdateArrange()
  end
  if tbl then
    populate_listbox(tbl)
  end
end

local function Main()
  check_project_path() -- CHECK IF PROJECT PATH IS CHANGED SO WE CAN CHANGE PATH TO SAVE SHIT (NOT TO OVERWRITE IT)
  local cur_tbl, current
  local x, y = reaper.GetMousePosition()
  local _, scroll, _, _, _ = reaper.JS_Window_GetScrollInfo(track_window, "SB_VERT") -- GET VERTICAL SCROLL
  local _, x_view_start, y_view_start, x_view_end, y_view_end = reaper.JS_Window_GetRect(track_window) -- GET TRACK VIEW COORDINATES
  window, segment, details = reaper.BR_GetMouseCursorContext()
  local mouse_track = reaper.BR_GetMouseCursorContext_Track()
  local sel_item = reaper.GetSelectedMediaItem(0, 0)
  local sel_tr = reaper.GetSelectedTrack(0, 0)
  local m_click = reaper.JS_Mouse_GetState(0x0011) -- INTERCEPT MOUSE CLICK
  local tr_name, tr_number, folder, fipm, Acur_Y
  AMtest = reaper.JS_Mouse_GetState(0x000F) -- CTRL,SHIFT,MOUSE L,R
  --AMtest1 = reaper.Mouse_GetState(2)

  if sel_tr then
    cur_tr = reaper.GetTrackGUID(sel_tr)
    cur_tbl = find_guid(cur_tr)
    get_shortcut(cur_tbl)
    tr_name, tr_number, folder, fipm = get_track_info(cur_tr)
    GUI.elms.Show_All.state = fipm -- SET FIPM BUTTON ON/OFF BASED IF TRACK IS IN FIPM MODE (UPDATE FIPM BUTTON)
  end

  --if cur_tbl and cur_tbl.data and fipm == 1 and AMtest == 2 and window == "arrange" and segment == "track" and details == "empty" and mouse_track == sel_tr then
  --menu(cur_tbl,ver_under_mouse,fipm)
  if AMtest == 10 and window == "arrange" and segment == "track" and mouse_track == sel_tr then
    menu(cur_tbl, nil, true, fipm)
  end
  -----------------------------------------
  -- SHOW SELECTED TRACKS VERSIONS (POPULATE LISTBOX WITH VERSIONS)
  if last_tr ~= cur_tr then
    GUI.elms.Show_All:redraw()
    populate_listbox(cur_tbl) -- MOVE DATA TO LISTBOX
    if cur_tbl then
      GUI.Val("Label1", update_txt_elements(cur_tr))
    else
      GUI.Val("Label1", "")
    end -- UPDATE LABEL ELEMENT TO TRACK NAME
    last_tr = cur_tr
  end
  -- SHOW SELECTED ENVELOPE MENUBOX AUTOMATICALLY (POPULATE LISTBOX WITH ENVELOPES)
  local env_guid, env_name = get_selected_env()
  if env_guid and cur_tbl and env_guid == cur_tr then
    if last_env_name ~= env_name then
      update_menubox(env_name) -- UPDATE MENUBOX TO SELECTED ENVELOPE
      populate_listbox(cur_tbl)
      last_env_name = env_name
    end
  end
  -- WHILE IN FIPM MODE
  if cur_tbl and cur_tbl.data and fipm == 1 then
    local tr_y_start, tr_y_end = get_track_y_range(y_view_start, scroll, sel_tr) -- GET TRACK Y POSITION
    if tr_y_start and x > x_view_start and (y >= tr_y_start and y <= tr_y_end) and window == "arrange" then
      Acur_Y = y - tr_y_start
    else
      Acur_Y = nil
    end
    ver_under_mouse = get_mouse_ver(cur_tbl, Acur_Y) -- GET VERSION WHERE MOUSE IS
    mouse_click(m_click, cur_tbl, ver_under_mouse)
    GUI.Val("Listbox1", ver_under_mouse)
    update_fipm(cur_tbl)
    fipm_gui_lines(cur_tr, tr_y_start, tr_y_end, x_view_start, x_view_end, y_view_start)
  end
  -----------------------------------------------
  local proj_change_count = reaper.GetProjectStateChangeCount(0)
  if proj_change_count > last_proj_change_count then
    --edit_group_track_or_item(sel_item,cur_tr) --test
    --------------------------------------------------
    local last_action = reaper.Undo_CanUndo2(0)
    local last_redo = reaper.Undo_CanRedo2(0)
    if last_action == nil then
      return
    end
    if last_redo == nil then
      last_redo = "AAAAAAA"
    end
    if last_redo:find("RTV") then
      unpack_undo(last_redo)
    end -- UNDO SYSTEM
    last_action = reaper.Undo_CanUndo2(0):lower()
    last_redo = reaper.Undo_CanUndo2(0):lower()
    auto_save(last_action, mouse_track, cur_tr, ver_under_mouse) -- DO NOT AUTOSAVE SHIT AROUND IF WE ARE IN COMP MODE
    if (last_action:find("change media item selection") or last_action:find("change track selection")) then
      --  if cur_tbl and cur_tbl.data.fipm == 1 then if get_num_from_selected_item(sel_item,cur_tbl) then GUI.Val("Listbox1",get_num_from_selected_item(sel_item,cur_tbl)) end end -- SELECT VERSION OF SELECTED ITEM (WE DONT NEED THIS ANYMORE SINCE WE ARE TRACKING MOUSE OUTSIDE SCRIPT)
    elseif last_action:find("time selection change") and not last_redo:find("rtv") and COMP == 1 and fipm == 1 then
      comping({cur_tr}, ver_under_mouse)
    elseif last_action:find("time selection change") and TO == 1 and fipm == 1 then
      -------------------------------------------------------------------------------------------------------------
      get_items_for_destination(cur_tr, ver_under_mouse)
    elseif last_action:find("change track free item positioning mode") then
      show_all(to_bool(fipm))
      GUI.elms.Show_All:redraw() -- UPDATE FIMP IF ENABLED VIA TRACK RIGHT CLICK
    elseif last_redo:find("change track item positioning mode") then
      show_all(to_bool(fipm))
      GUI.elms.Show_All:redraw()
    -------------------------------------------------------------------------------------------------------------
    end
    --------------------------------------------------
    last_proj_change_count = proj_change_count
  end
end
if not is_open then
  GUI.Init()
end
GUI.func = Main
GUI.freq = 0
--GUI.freq = 0.05
read_from_file()
if not is_open then
  GUI.Main()
end
reaper.atexit(save_tracks) -- GUI WINDOW CLOSED
