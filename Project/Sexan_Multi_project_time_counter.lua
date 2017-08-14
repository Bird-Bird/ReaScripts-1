--[[
 * ReaScript Name: Multi project time counter
 * Discription: Script shows 3 timers: Windows time, how long project has been opened and third timer has AFK mode that that counts time only while you work in the project
 * Author: SeXan
 * Licence: GPL v3
 * REAPER: 5.0
 * Extensions: None
 * Version: 1.41
--]]
 
--[[
 * Changelog:
 * v1.41 (2017-08-14)
  + Store dock position, code improvement
--]]
---------------------------------------
local afk = 60 -- set afk treshold HERE
---------------------------------------
local threshold = afk
local last_time = 0
local last_action_time = 0
local last_proj_change_count = reaper.GetProjectStateChangeCount(0)
local dock_pos = reaper.GetExtState("timer", "dock")

local timer,timer2

local function store_time() -- store time values to project
  reaper.SetProjExtState(0, "timer", "timer", timer) -- store seconds
  reaper.SetProjExtState(0, "timer", "timer2", timer2) -- store seconds
end

local function restore_time() -- restore time values from project
  local ret, load_timer = reaper.GetProjExtState(0, "timer", "timer") -- restore seconds
  local ret, load_timer2 = reaper.GetProjExtState(0, "timer", "timer2") -- restore seconds
    if load_timer ~= "" and load_timer2 ~= "" then
      timer = load_timer
      timer2 = load_timer2
    else
      timer = 0
      timer2 = 0
    end
end

local function proj_time()
  if os.time() - last_time > 0 then
    timer2 = timer2 + 1
    last_time = os.time()    
  end
  store_time()
end

local function count_time()
  if os.time() - last_action_time > 0 then -- interval of 1 second      
    afk = afk + 1
    timer = timer + 1
    last_action_time = os.time() 
  end  
  store_time()
end

local function time(x)
  local days = math.floor(x/(60*60*24))
  local hours  = math.floor(x/(60*60)%24)
  local minutes = math.floor(x/60%60)
  local seconds = math.floor(x%60)
      
  local time = string.format("%02d:%02d:%02d:%02d",days,hours,minutes,seconds)
  return time
end

local function main()  
  restore_time()
  proj_time()
  
  local proj_change_count = reaper.GetProjectStateChangeCount(0)
  if proj_change_count > last_proj_change_count or reaper.GetPlayState() ~= 0 then
    afk = 0
    last_proj_change_count = proj_change_count
  end
 
  if afk < threshold then
    count_time()
  end  
  
  local project_time, afk_time = time(timer2), time(timer)
  local w_time = os.date("%X")
  
  gfx.x, gfx.y = 2, 8
  gfx.printf("     ")
  gfx.printf(w_time)
  gfx.printf(" - T")
  gfx.x, gfx.y = 2, 38
  gfx.printf(project_time)
  gfx.printf(" - P")
  gfx.x, gfx.y = 2, 68
  gfx.printf(afk_time)
  gfx.printf(" - A")
  gfx.update()

  if gfx.getchar() > -1 then  -- defer while gfx window is open
     reaper.defer(main)
  end
end

local function store_settings()
  reaper.SetExtState("timer", "dock", gfx.dock(-1), true)
  store_time()
end

local function init()
  dock_pos = dock_pos or 513
  
  gfx.init("", 155, 100, dock_pos)
  gfx.setfont(1,"Arial", 24)
  gfx.clear = 3355443 
  main()   
end
restore_time()
init()
reaper.atexit(store_settings)
