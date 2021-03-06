function move_items_envs(tbl,offset)
  for i = 1, #tbl.info do
    if tbl.info[i].items then
      for j = 1, #tbl.info[i].items do
        local as_track = tbl.info[i].track
        local as_item = tbl.info[i].items[j]
        local as_item_pos = reaper.GetMediaItemInfo_Value( as_item, "D_POSITION" )
        reaper.SetMediaItemInfo_Value( as_item, "D_POSITION", as_item_pos + offset)
        reaper.MoveMediaItemToTrack( as_item, as_track )
      end
    elseif tbl.info[i].env_points then
      for j = 1, #tbl.info[i].env_points do
        local env = tbl.info[i].env_points[j]
        env.time = env.time + offset
        reaper.SetEnvelopePoint( tbl.info[i].track, env.id, env.time, env.val, env.shape, env.tension, env.selected, true )
      end  
    end
  end
end

local function add_info_to_edge(tbl)
  local tracks = {}
  for i = 1, #tbl.info do
    tracks[#tracks+1] = {track = tbl.info[i].track} 
  end


  local info   = GetRangeInfo(tracks, tbl.time_start,  tbl.time_end)
  tbl.info = info  
end

function item_blit(item, as_start, as_end , pos)
  local tsStart, tsEnd = as_start, as_end
  local item_lenght = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local item_start  = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_dur    = item_lenght + item_start
  
  if tsStart < item_start and tsEnd > item_start and tsEnd < item_dur then
    ----- IF TS START IS OUT OF ITEM BUT TS END IS IN THEN COPY ONLY PART FROM TS START TO ITEM END
    local new_start, new_item_lenght, offset = (pos ~= nil) and ((item_start-tsStart) + pos) or item_start, tsEnd - item_start, 0
    return new_start, new_item_lenght, offset, item
  elseif tsStart < item_dur and tsStart > item_start and tsEnd > item_dur then
    ------ IF START IS IN ITEM AND TS END IS OUTSIDE ITEM COPY PART FROM TS START TO TS END
    local new_start, new_item_lenght, offset = (pos ~= nil) and pos or tsStart , item_dur - tsStart, (tsStart - item_start)
    return new_start, new_item_lenght, offset, item
  elseif tsStart >= item_start and tsEnd <= item_dur then
    ------ IF BOTH TS START AND TS END ARE IN ITEM
    local new_start, new_item_lenght, offset = (pos ~= nil) and pos or tsStart , tsEnd - tsStart, (tsStart - item_start)
    return new_start, new_item_lenght, offset, item
  elseif tsStart <= item_start and tsEnd >= item_dur then -- >= NEW
    ------ IF BOTH TS START AND END ARE OUTSIDE OF THE ITEM
    local new_start, new_item_lenght, offset = (pos ~= nil) and ((item_start-tsStart) + pos) or item_start, item_lenght, 0
    return new_start, new_item_lenght, offset, item
  end
  
end

function as_item_position(item, as_start, as_end, mouse_time_pos)
  local cur_pos = mouse_time_pos
  
  if job == "duplicate" then cur_pos = as_end end
  
  local tsStart, tsEnd = as_start, as_end
  local item_lenght = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_dur = item_lenght + item_start
  
  local new_start, new_item_lenght, offset
  if tsStart < item_start and tsEnd > item_start and tsEnd < item_dur then
    ----- IF TS START IS OUT OF ITEM BUT TS END IS IN THEN COPY ONLY PART FROM TS START TO ITEM END
    local new_start, new_item_lenght, offset = (item_start-tsStart) + cur_pos, tsEnd - item_start, 0
    return new_start, new_item_lenght, offset, item
  elseif tsStart < item_dur and tsStart > item_start and tsEnd > item_dur then
    ------ IF START IS IN ITEM AND TS END IS OUTSIDE ITEM COPY PART FROM TS START TO TS END
    local new_start, new_item_lenght, offset = cur_pos, item_dur - tsStart, (tsStart - item_start)
    return new_start, new_item_lenght, offset, item
  elseif tsStart >= item_start and tsEnd <= item_dur then
    ------ IF BOTH TS START AND TS END ARE IN ITEM
    local new_start, new_item_lenght, offset = cur_pos , tsEnd - tsStart, (tsStart - item_start)
    return new_start, new_item_lenght, offset, item
  elseif tsStart <= item_start and tsEnd >= item_dur then -- >= NEW
    ------ IF BOTH TS START AND END ARE OUTSIDE OF THE ITEM
    local new_start, new_item_lenght, offset = (item_start-tsStart) + cur_pos, item_lenght, 0
    return new_start, new_item_lenght, offset, item
  end
  
end

function env_prop(env)
  br_env = reaper.BR_EnvAlloc(env, false)
  local active, visible, armed, inLane, laneHeight, defaultShape, minValue, maxValue, centerValue, type, faderScaling = reaper.BR_EnvGetProperties(br_env, true, true, true, true, 0, 0, 0, 0, 0, 0, true)
end

function insert_edge_points(env, as_time_tbl, offset, src_tr, del)
  if not reaper.ValidatePtr(env, "TrackEnvelope*") then return end -- DO NOT ALLOW MEDIA TRACK HERE
  local edge_pts = {}
  
    local retval, value_st, dVdS, ddVdS, dddVdS = reaper.Envelope_Evaluate( env, as_time_tbl[1] + offset, 0, 0 )  -- DESTINATION START POINT
    reaper.InsertEnvelopePoint(env, as_time_tbl[1] + offset - 0.001, value_st, 0, 0, true, true)
    local retval, value_et, dVdS, ddVdS, dddVdS = reaper.Envelope_Evaluate( env, as_time_tbl[2] + offset, 0, 0 )  -- DESTINATION END POINT
    reaper.InsertEnvelopePoint(env, as_time_tbl[2] + offset + 0.001, value_et, 0, 0, true, true)
    
    reaper.DeleteEnvelopePointRange( env, as_time_tbl[1] + offset, as_time_tbl[2]+ offset )
    
    if del then return end
    local retval, value_s, dVdS, ddVdS, dddVdS = reaper.Envelope_Evaluate( src_tr, as_time_tbl[1], 0, 0 )         -- SOURCE START POINT
    reaper.InsertEnvelopePoint(env, as_time_tbl[1] + offset + 0.001, value_s, 0, 0, true, false)
    
    local retval, value_e, dVdS, ddVdS, dddVdS = reaper.Envelope_Evaluate( src_tr, as_time_tbl[2], 0, 0 )         -- SOURCE END POINT
    reaper.InsertEnvelopePoint(env, as_time_tbl[2] + offset - 0.001, value_e, 0, 0, true, false)
   
end

local function create_item(item, tr, as_start, as_end, mouse_time_pos)
  local filename, clonedsource
  local take = reaper.GetMediaItemTake(item, 0)
  local source = reaper.GetMediaItemTake_Source(take)
  local m_type = reaper.GetMediaSourceType(source, "")
  local item_volume = reaper.GetMediaItemInfo_Value(item, "D_VOL")
  local new_Item = reaper.AddMediaItemToTrack(tr)---
  local new_Take = reaper.AddTakeToMediaItem(new_Item)
  
  if m_type:find("MIDI") then -- MIDI COPIES GET INTO SAME POOL IF JUST SETTING CHUNK SO WE NEED TO SET NEW POOL ID TO NEW COPY
    local _, chunk = reaper.GetItemStateChunk(item, "")
    local pool_guid = string.match(chunk, "POOLEDEVTS {(%S+)}"):gsub("%-", "%%-")
    local new_pool_guid = reaper.genGuid():sub(2, -2) -- MIDI ITEM
    chunk = string.gsub(chunk, pool_guid, new_pool_guid)
    reaper.SetItemStateChunk(new_Item, chunk, false)
  else -- NORMAL TRACK ITEMS
    filename = reaper.GetMediaSourceFileName(source, "")
    clonedsource = reaper.PCM_Source_CreateFromFile(filename)
  end
  
  local new_item_start, new_item_lenght, offset = as_item_position(item, as_start, as_end, mouse_time_pos)
  reaper.SetMediaItemInfo_Value(new_Item, "D_POSITION", new_item_start)
  reaper.SetMediaItemInfo_Value(new_Item, "D_LENGTH", new_item_lenght)
  local newTakeOffset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
  reaper.SetMediaItemTakeInfo_Value(new_Take, "D_STARTOFFS", newTakeOffset + offset)

  if m_type:find("MIDI") == nil then reaper.SetMediaItemTake_Source(new_Take, clonedsource) end

  reaper.SetMediaItemInfo_Value(new_Item, "D_VOL", item_volume)
end

function paste(items, item_track, as_start, as_end, pos_offset, first_track)
  if not mouse.tr then return end -- DO NOT PASTE IF MOUSE IS OUT OF ARRANGE WINDOW
  
  local offset_track, under_last_tr = generic_track_offset(item_track, first_track)
  if under_last_tr and under_last_tr > 0 then 
    for t = 1, under_last_tr do reaper.InsertTrackAtIndex(( reaper.GetNumTracks() ), true ) end-- IF THE TRACKS ARE BELOW LAST TRACK OF THE PROJECT CREATE HAT TRACKS
    offset_track = reaper.GetTrack(0,reaper.GetNumTracks()-1)
  end
  
 -- for w = 1 , mouse.wheel do
   -- local wheel_offset = (w-1) * (as_end - as_start)
    for i = 1, #items do
      local item = items[i]
      local mouse_offset = pos_offset + mouse.p -- + wheel_offset
      create_item(item, offset_track, as_start, as_end, mouse_offset) -- CREATE ITEMS AT NEW POSITION
    end
  --end
end

function paste_env(env_track, env_name, env_data, as_start, as_end, pos_offset, first_env_tr)
  if not mouse.tr or not env_data then return end                                                                                 -- DO NOT PASTE IF MOUSE IS OUT OF ARRANGE WINDOW
  
  local offset_track, under_last_tr = generic_track_offset(env_track, first_env_tr)
  
  if under_last_tr and under_last_tr > 0 then 
    for t = 1, under_last_tr do reaper.InsertTrackAtIndex(( reaper.GetNumTracks() ), true ) end                   -- IF THE TRACKS ARE BELOW LAST TRACK OF THE PROJECT CREATE HAT TRACKS
    offset_track = reaper.GetTrack(0,reaper.GetNumTracks()-1)
  end
  
  local env_offset                  = GetEnvOffset_MatchCriteria(offset_track, env_name)
  
  local env_paste_offset  = mouse.p - as_start                                                                    -- OFFSET BETWEEN ENVELOPE START AND MOUSE POSITION
  local mouse_offset      = env_paste_offset + pos_offset                                                         -- OFFSET BETWEEN MOUSE POSITION AND NEXT AREA SELECTION
  
  if env_offset and reaper.ValidatePtr(env_offset, "TrackEnvelope*") then                                         -- IF TRACK HAS ENVELOPES PASTE THEM 
    insert_edge_points(env_offset, {as_start, as_end}, mouse_offset, env_track)                                   -- INSERT EDGE POINTS AT CURRENT ENVELOE VALUE AND DELETE WHOLE RANGE INSIDE (DO NOT ALLOW MIXING ENVELOPE POINTS AND THAT WEIRD SHIT)
    for i = 1 ,#env_data do
      local env = env_data[i]
      reaper.InsertEnvelopePoint( 
                                  env_offset, 
                                  env.time + mouse_offset, 
                                  env.value, 
                                  env.shape, 
                                  env.tension, 
                                  env.selected, 
                                  true
                                )
    end
    reaper.Envelope_SortPoints( env_offset, env_track )
  elseif env_offset and reaper.ValidatePtr(env_offset, "MediaTrack*") then
    get_set_envelope_chunk(env_offset, env_track, as_start, as_end, mouse_offset)
  end
end

function del_env(env_track, as_start, as_end, pos_offset, job)
  local as_time_tbl = {as_start, as_end}
 
  local first_env = reaper.GetEnvelopePointByTime( env_track, as_start)
  local last_env  = reaper.GetEnvelopePointByTime( env_track, as_end )+1
  
  local retval1, time1, value1, shape1, tension1, selected1 = reaper.GetEnvelopePoint( env_track, first_env )
  local retval2, time2, value2, shape2, tension2, selected2 = reaper.GetEnvelopePoint( env_track, last_env )
  
  if value1 == 0 or value2 == 0  then
    reaper.DeleteEnvelopePointRange( env_track, as_start , as_end )
  else
    insert_edge_points(env_track, as_time_tbl, 0, nil, job)
  end
end
   
function AreaDo(tbl,job)
  reaper.PreventUIRefresh(1)
  for a = 1, #tbl do
    local tbl = tbl[a]
    
    local pos_offset        = 0
          pos_offset        = pos_offset + (tbl.time_start - lowest_start()) --  OFFSET AREA SELECTIONS TO MOUSE POSITION
    local as_start, as_end  = tbl.time_start, tbl.time_end
    
    for i = 1, #tbl.info do
      local info = tbl.info[i]
      local first_tr = find_highest_tr(info.track)
      
      if info.items then
        local item_track    = info.track
        local item_data     = info.items
        if job == "PASTE" then paste(info.items, item_track, as_start, as_end, pos_offset, first_tr) end
        if job == "del" or job == "split" then split_or_delete_items(item_track, item_data, as_start, as_end, job) end
        
      elseif info.env_name then
        local env_track     = info.track
        local env_name      = info.env_name
        local env_data      = info.env_points
        
        if job == "PASTE" then paste_env(env_track, env_name, env_data, as_start, as_end, pos_offset, first_tr) end
        if job == "del"   then del_env(env_track, as_start, as_end, pos_offset, job) reaper.Envelope_SortPoints( env_track ) end
      end
    end
    if job == "del" then tbl.info = GetAreaInfo(tbl) end
  end
  reaper.PreventUIRefresh(-1)
  reaper.UpdateTimeline()
end

function get_and_show_take_envelope(take, envelope_name)
  local env = reaper.GetTakeEnvelopeByName(take, envelope_name)
  
  if env == nil then
    local item = reaper.GetMediaItemTake_Item(take)
    local sel = reaper.IsMediaItemSelected(item)
    
    if not sel then reaper.SetMediaItemSelected(item, true) end
    
    if     envelope_name == "Volume" then reaper.Main_OnCommand(reaper.NamedCommandLookup("_S&M_TAKEENV1"), 0) -- show take volume envelope
    elseif envelope_name == "Pan" then reaper.Main_OnCommand(reaper.NamedCommandLookup("_S&M_TAKEENV2"), 0)    -- show take pan envelope
    elseif envelope_name == "Mute" then reaper.Main_OnCommand(reaper.NamedCommandLookup("_S&M_TAKEENV3"), 0)   -- show take mute envelope
    elseif envelope_name == "Pitch" then reaper.Main_OnCommand(reaper.NamedCommandLookup("_S&M_TAKEENV10"), 0) -- show take pitch envelope
    end
    
    if sel then reaper.SetMediaItemSelected(item, true) end
    env = reaper.GetTakeEnvelopeByName(take, envelope_name)
  end
  
  return env
end

function get_take_env(item)
  local source_take = reaper.GetActiveTake(item)
  local source_env = get_and_show_take_envelope(source_take, "Volume")
  
  for i = 1 , reaper.CountTakeEnvelopes( take ) do
    local env = reaper.GetTakeEnvelope( take, i )
    retval, str = reaper.GetEnvelopeStateChunk( env, "", true )
  end
  
end

function get_items_in_as(as_tr, as_start, as_end, as_items)
  local as_items = {}
  
  for i = 1, reaper.CountTrackMediaItems(as_tr) do
    local item = reaper.GetTrackMediaItem(as_tr, i-1)
    local item_start = reaper.GetMediaItemInfo_Value(item,"D_POSITION")
    local item_len = reaper.GetMediaItemInfo_Value(item,"D_LENGTH")
    local item_end = item_start + item_len
    
    if (as_start >= item_start and as_start < item_end) and (as_end <= item_end and as_end > item_start) or -- IF SELECTION START & END ARE "IN" OR "ON" ITEM (START AND END ARE IN ITEM OR START IS ON ITEM START,END IS ON ITEM END) 
      (as_start < item_start and as_end > item_end ) then -- IF SELECTION START & END ARE OVER ITEM (SEL STARTS BEFORE ITEM END IS AFTER ITEM 
      as_items[#as_items+1] = item
    elseif (as_start >= item_start and as_start < item_end) and (as_end >= item_end) then -- IF SEL START IS IN THE ITEM
      as_items[#as_items+1] = item
    elseif (as_end <= item_end and as_end > item_start) and (as_start <= item_start) then -- IF SEL END IS IN THE ITEM
      as_items[#as_items+1] = item
    end
  end
  
  if #as_items ~= 0 then return as_items end
end

function split_or_delete_items(as_tr, as_items_tbl, as_start, as_end, key)
  if not as_items_tbl then return end
  
  for i = #as_items_tbl, 1, -1 do
    local item = as_items_tbl[i]
    
    if key == "del" or key == "split" then
      local s_item_first = reaper.SplitMediaItem(item, as_end)
      local s_item_last = reaper.SplitMediaItem(item, as_start)
      
      -- ITEMS FOR DELETING
      if key == "del" then
        if s_item_first and s_item_last then
          reaper.DeleteTrackMediaItem(as_tr, s_item_last)
        elseif s_item_last and not s_item_first then
          reaper.DeleteTrackMediaItem(as_tr, s_item_last)
        elseif s_item_first and not s_item_last then
          reaper.DeleteTrackMediaItem(as_tr, item)
        elseif not s_item_first and not s_item_last then
          reaper.DeleteTrackMediaItem(as_tr, item)
        end
        
      end
    end
  end
  
  if key == "del" then return key end
end

function get_env(as_tr, as_start, as_end)
  local env_points = {}
  
  for i = 1 , reaper.CountTrackEnvelopes( as_tr ) do
    local tr = reaper.GetTrackEnvelope( as_tr, i-1 )
    
    for i = 1, reaper.CountEnvelopePoints(tr) do
      local retval, time, value, shape, tension, selected = reaper.GetEnvelopePoint(tr, i-1)
      
      if time >= as_start and time <= as_end then
        reaper.SetEnvelopePoint( tr, i-1, _, _, _, _, true,_ )
      
        env_points[#env_points + 1] = 
        {
          id = i-1,
          retval    = retval,
          time      = time,
          value     = value,
          shape     = shape,
          tension   = tension,
          selected  = true
        }
      end
    end
  end
  
  if #env_points ~= 0 then return env_points end
end

function get_as_tr_env_pts(as_tr, as_start, as_end)
  local retval, env_name = reaper.GetEnvelopeName(as_tr)
  local env_points = {}
  
  for i = 1, reaper.CountEnvelopePoints(as_tr) do
    local retval, time, value, shape, tension, selected = reaper.GetEnvelopePoint(as_tr, i-1)
    
    if time >= as_start and time <= as_end then
      reaper.SetEnvelopePoint( as_tr, i-1, _, _, _, _, true,_ )
    
      env_points[#env_points + 1] = 
      {
        id = i-1,
        retval    = retval,
        time      = time,
        value     = value,
        shape     = shape,
        tension   = tension,
        selected  = true
      }
    elseif (time > as_start and time > as_end) or (time < as_start and time < as_end) then
      reaper.SetEnvelopePoint( as_tr, i-1, _, _, _, _, false,_ )
    end
  end
  
  if #env_points ~= 0 then return env_points end
end

local AI_info = {"D_POOL_ID", "D_POSITION", "D_LENGTH", "D_STARTOFFS", "D_PLAYRATE", "D_BASELINE", "D_AMPLITUDE", "D_LOOPSRC", "D_UISEL", "D_POOL_QNLEN"}
function get_as_tr_AI(as_tr, as_start, as_end)
  local as_AI = {}
  
  for i = 1, reaper.CountAutomationItems(as_tr) do
    local AI = reaper.GetSetAutomationItemInfo( as_tr, i-1, AI_info[2], 0, false ) -- GET AI POSITION
    
    if AI >= as_start and AI <= as_end then
      as_AI[#as_AI+1] = {} -- MAKE NEW TABLE FOR AI
      
      for j = 1, #AI_info do
        as_AI[#as_AI][AI_info[j]] = reaper.GetSetAutomationItemInfo( as_tr, i-1, AI_info[j], 0, false ) -- ADD AI INFO TO AI TABLE
      end
    end
  end
  
  if #as_AI ~= 0 then return as_AI end
end

function validate_as_items(tbl)
  for i = 1 ,#tbl.items do
    if not reaper.ValidatePtr(tbl.items[i], "MediaItem*") then tbl.items[i] = nil end -- IF ITEM DOES NOT EXIST REMOVE IT FROM TABLE
  end
  
  if #tbl.items == 0 then tbl.items = nil end -- IF ITEM TABLE IS EMPTY REMOVE TABLE
end
