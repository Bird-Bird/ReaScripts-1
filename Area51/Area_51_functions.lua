--[[local function transform_env(tbl, trans_zone, m_time, cur_m_y , mouse_offset, off2)
  local size_offset = size_offset(cur_m_y)
  local pt_fist, pt_last
  for i = 1 ,#tbl do
    local track = tbl[i].track
    if reaper.ValidatePtr(track, "TrackEnvelope*") then
      if tbl[i].points then
        if trans_zone == "L" then
          pt_fist = tbl[i].points[#tbl[i].points].time
          pt_last = tbl[i].points[1].time
        elseif trans_zone == "R" then
          pt_fist = tbl[i].points[1].time
          pt_last = tbl[i].points[#tbl[i].points].time
        elseif trans_zone == "C" then  
          Aef2 = tbl[i].points[1].value
          Ael2 = tbl[i].points[#tbl[i].points].value
        end
        for j = 1, #tbl[i].points do
          local p_t = tbl[i].points[j].time
          local p_v = tbl[i].points[j].value
          if trans_zone == "L" or trans_zone == "R" then
            local off_LR = TranslateRange(p_t, pt_fist, pt_last, pt_fist, pt_last + mouse_offset)
            tbl[i].points[j].time = off_LR
          end
          if trans_zone == "C" then
            --Aef2 = tbl[i].points[1].value
            --Ael2 = tbl[i].points[#tbl[i].points].value
            Atest =  reaper.ScaleToEnvelopeMode( 0, off2 )
            Aoff_C = TranslateRange(p_v, Aef2, Ael2, Aef2, Ael2 - (Atest))
            tbl[i].points[j].value = Aoff_C 
          end
          if trans_zone == "TL" then
            --local warp_offset = get_warp_offset(as_under_mouse.sel_start, as_under_mouse.sel_end, as_under_mouse.tracks[j].points[i].time, off2) * 0.01
            --as_under_mouse.tracks[j].points[i].value = as_under_mouse.tracks[j].points[i].value - warp_offset
          end
          if trans_zone == "TR" then
            local warp_offset = get_warp_offset(as_under_mouse.sel_start, as_under_mouse.sel_end, tbl[i].points[j].time, off2) * 0.01
            tbl[i].points[j].value = tbl[i].points[j].value - warp_offset
          end
          reaper.SetEnvelopePoint( tbl[i].track, tbl[i].points[j].id, tbl[i].points[j].time , tbl[i].points[j].value, tbl[i].points[j].shape, tbl[i].points[j].tension, true, true )
        end
      end
    end
  end

end]]

local function TranslateRange(value, oldMin, oldMax, newMin, newMax)
  local oldRange = oldMax - oldMin;
  local newRange = newMax - newMin;
  local newValue = ((value - oldMin) * newRange / oldRange) + newMin;
  return newValue
end

local function get_warp_offset(as_start,as_end,point_time,offset)
  local lenght = as_end - as_start
  local distance = point_time - as_start
  local x = ( offset * distance) / lenght
  --local x = ( offset * (point_time - as_start)) / lenght
  return x
end

function item_vals(item)
  local item_lenght = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_dur = item_lenght + item_start
  return item_start, item_lenght
end

local function stretch_items(items, as_start, as_end)
   local item_start_1, item_lenght_1 = item_vals(items[1])
   local item_start_2, item_lenght_2 = item_vals(items[#items])
  for i = 1, #items do
    local item = items[i]
    local item_start, item_lenght = item_vals(item)
    local take = reaper.GetMediaItemTake(item, 0)
    local rate = reaper.GetMediaItemTakeInfo_Value( take, "D_PLAYRATE" )
    local new_rate = TranslateRange(item_start, item_start_1, item_start_2, item_start_1, item_start_2 + mouse.rp )
    local new_rate2 = TranslateRange(item_lenght, item_lenght_1, item_lenght_2, item_lenght_1, item_lenght_2 + mouse.rp)
    msg(new_rate)
    --reaper.SetMediaItemTakeInfo_Value( take, "D_PLAYRATE", rate + (mouse.rp * 0.0001) )
    reaper.SetMediaItemInfo_Value( item, "D_LENGTH",new_rate2)
    reaper.SetMediaItemInfo_Value( item, "D_POSITION",new_rate)

  end
end

function move_items_envs(tbl, offset)
  reaper.Undo_BeginBlock()
  for i = 1, #tbl.sel_info do
    if tbl.sel_info[i].items then
      for j = 1, #tbl.sel_info[i].items do
        local as_track = tbl.sel_info[i].track
        local as_item = tbl.sel_info[i].items[j]
        local as_item_pos = reaper.GetMediaItemInfo_Value(as_item, "D_POSITION")
        reaper.SetMediaItemInfo_Value(as_item, "D_POSITION", as_item_pos + offset)
        reaper.MoveMediaItemToTrack(as_item, as_track)
      end
    elseif tbl.sel_info[i].env_points then
      for j = 1, #tbl.sel_info[i].env_points do
        local env = tbl.sel_info[i].env_points[j]
        env.time = env.time + offset
        reaper.SetEnvelopePoint(
          tbl.sel_info[i].track,
          env.id,
          env.time,
          env.val,
          env.shape,
          env.tension,
          env.selected,
          true
        )
      end
    end
  end
  reaper.Undo_EndBlock("AREA51 MOVE", 4)
end

function item_blit(item, as_start, as_end, pos)
  local tsStart, tsEnd = as_start, as_end
  local item_lenght = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_dur = item_lenght + item_start

  if tsStart < item_start and tsEnd > item_start and tsEnd < item_dur then
    ----- IF TS START IS OUT OF ITEM BUT TS END IS IN THEN COPY ONLY PART FROM TS START TO ITEM END
    local new_start, new_item_lenght, offset =
      (pos ~= nil) and ((item_start - tsStart) + pos) or item_start,
      tsEnd - item_start,
      0
    return new_start, new_item_lenght, offset, item
  elseif tsStart < item_dur and tsStart > item_start and tsEnd > item_dur then
    ------ IF START IS IN ITEM AND TS END IS OUTSIDE ITEM COPY PART FROM TS START TO TS END
    local new_start, new_item_lenght, offset =
      (pos ~= nil) and pos or tsStart,
      item_dur - tsStart,
      (tsStart - item_start)
    return new_start, new_item_lenght, offset, item
  elseif tsStart >= item_start and tsEnd <= item_dur then
    ------ IF BOTH TS START AND TS END ARE IN ITEM
    local new_start, new_item_lenght, offset = (pos ~= nil) and pos or tsStart, tsEnd - tsStart, (tsStart - item_start)
    return new_start, new_item_lenght, offset, item
  elseif tsStart <= item_start and tsEnd >= item_dur then -- >= NEW
    ------ IF BOTH TS START AND END ARE OUTSIDE OF THE ITEM
    local new_start, new_item_lenght, offset =
      (pos ~= nil) and ((item_start - tsStart) + pos) or item_start,
      item_lenght,
      0
    return new_start, new_item_lenght, offset, item
  end
end

function as_item_position(item, as_start, as_end, mouse_time_pos, job)
  local cur_pos = mouse_time_pos

  if job == "duplicate" then
    cur_pos = as_end
  end

  local tsStart, tsEnd = as_start, as_end
  local item_lenght = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_dur = item_lenght + item_start

  local new_start, new_item_lenght, offset
  if tsStart < item_start and tsEnd > item_start and tsEnd < item_dur then
    ----- IF TS START IS OUT OF ITEM BUT TS END IS IN THEN COPY ONLY PART FROM TS START TO ITEM END
    local new_start, new_item_lenght, offset = (item_start - tsStart) + cur_pos, tsEnd - item_start, 0
    return new_start, new_item_lenght, offset, item
  elseif tsStart < item_dur and tsStart > item_start and tsEnd > item_dur then
    ------ IF START IS IN ITEM AND TS END IS OUTSIDE ITEM COPY PART FROM TS START TO TS END
    local new_start, new_item_lenght, offset = cur_pos, item_dur - tsStart, (tsStart - item_start)
    return new_start, new_item_lenght, offset, item
  elseif tsStart >= item_start and tsEnd <= item_dur then
    ------ IF BOTH TS START AND TS END ARE IN ITEM
    local new_start, new_item_lenght, offset = cur_pos, tsEnd - tsStart, (tsStart - item_start)
    return new_start, new_item_lenght, offset, item
  elseif tsStart <= item_start and tsEnd >= item_dur then -- >= NEW
    ------ IF BOTH TS START AND END ARE OUTSIDE OF THE ITEM
    local new_start, new_item_lenght, offset = (item_start - tsStart) + cur_pos, item_lenght, 0
    return new_start, new_item_lenght, offset, item
  end
end
--[[

  NEED TO REFACTOR THESE TWO INTO ONLY ONE

]]
function as_item_position2(item_lenght, item_start, item_dur, as_start, as_end, mouse_time_pos)
  local cur_pos = mouse_time_pos
  if job == "duplicate" then
    cur_pos = as_end
  end

  local tsStart, tsEnd = as_start, as_end

  local new_start, new_item_lenght, offset
  if tsStart < item_start and tsEnd > item_start and tsEnd < item_dur then
    ----- IF TS START IS OUT OF ITEM BUT TS END IS IN THEN COPY ONLY PART FROM TS START TO ITEM END
    local new_start, new_item_lenght, offset = (item_start - tsStart) + cur_pos, tsEnd - item_start, 0
    return new_start, new_item_lenght, offset, item
  elseif tsStart < item_dur and tsStart > item_start and tsEnd > item_dur then
    ------ IF START IS IN ITEM AND TS END IS OUTSIDE ITEM COPY PART FROM TS START TO TS END
    local new_start, new_item_lenght, offset = cur_pos, item_dur - tsStart, (tsStart - item_start)
    return new_start, new_item_lenght, offset, item
  elseif tsStart >= item_start and tsEnd <= item_dur then
    ------ IF BOTH TS START AND TS END ARE IN ITEM
    local new_start, new_item_lenght, offset = cur_pos, tsEnd - tsStart, (tsStart - item_start)
    return new_start, new_item_lenght, offset, item
  elseif tsStart <= item_start and tsEnd >= item_dur then -- >= NEW
    ------ IF BOTH TS START AND END ARE OUTSIDE OF THE ITEM
    local new_start, new_item_lenght, offset = (item_start - tsStart) + cur_pos, item_lenght, 0
    return new_start, new_item_lenght, offset, item
  end
end

function env_prop(env)
  br_env = reaper.BR_EnvAlloc(env, false)
  local active, visible, armed, inLane, laneHeight, defaultShape, minValue, maxValue, centerValue, type, faderScaling =
    reaper.BR_EnvGetProperties(br_env, true, true, true, true, 0, 0, 0, 0, 0, 0, true)
end

function insert_edge_points(env, as_time_tbl, offset, src_tr, del)
  if not reaper.ValidatePtr(env, "TrackEnvelope*") then
    return
  end -- DO NOT ALLOW MEDIA TRACK HERE
  local edge_pts = {}

  local retval, value_st, dVdS, ddVdS, dddVdS = reaper.Envelope_Evaluate(env, as_time_tbl[1] + offset, 0, 0) -- DESTINATION START POINT
  reaper.InsertEnvelopePoint(env, as_time_tbl[1] + offset - 0.001, value_st, 0, 0, true, true)
  local retval, value_et, dVdS, ddVdS, dddVdS = reaper.Envelope_Evaluate(env, as_time_tbl[2] + offset, 0, 0) -- DESTINATION END POINT
  reaper.InsertEnvelopePoint(env, as_time_tbl[2] + offset + 0.001, value_et, 0, 0, true, true)

  reaper.DeleteEnvelopePointRange(env, as_time_tbl[1] + offset, as_time_tbl[2] + offset)

  if del then
    return
  end
  local retval, value_s, dVdS, ddVdS, dddVdS = reaper.Envelope_Evaluate(src_tr, as_time_tbl[1], 0, 0) -- SOURCE START POINT
  reaper.InsertEnvelopePoint(env, as_time_tbl[1] + offset + 0.001, value_s, 0, 0, true, false)

  local retval, value_e, dVdS, ddVdS, dddVdS = reaper.Envelope_Evaluate(src_tr, as_time_tbl[2], 0, 0) -- SOURCE END POINT
  reaper.InsertEnvelopePoint(env, as_time_tbl[2] + offset - 0.001, value_e, 0, 0, true, false)
end

function paste(items, item_track, as_start, as_end, pos_offset, first_track, drag_offset, job)
  if not mouse.tr then
    return
  end -- DO NOT PASTE IF MOUSE IS OUT OF ARRANGE WINDOW

  local first_track = drag_offset and mouse.tr or first_track
  local offset_track, under_last_tr = generic_track_offset(item_track, first_track)
  if not job and under_last_tr and under_last_tr > 0 then
    for t = 1, under_last_tr do
      reaper.InsertTrackAtIndex((reaper.GetNumTracks()), true)
    end
     -- IF THE TRACKS ARE BELOW LAST TRACK OF THE PROJECT CREATE HAT TRACKS
    offset_track = reaper.GetTrack(0, reaper.GetNumTracks() - 1)
  end

  if job == "duplicate" then
    offset_track = item_track
  end
  -- for w = 1 , mouse.wheel do
  -- local wheel_offset = (w-1) * (as_end - as_start)
  for i = 1, #items do
    local item = items[i]
    local mouse_offset = drag_offset and drag_offset or pos_offset + mouse.p -- + wheel_offset
    create_item(item, offset_track, as_start, as_end, mouse_offset, job) -- CREATE ITEMS AT NEW POSITION
  end
  --end
end

function paste_env(env_track, env_name, env_data, as_start, as_end, pos_offset, first_env_tr, num, drag_offset, job) -- drag offset is not used, only as a flag for drag move here
  if not mouse.tr or not env_data then
    return
  end -- DO NOT PASTE IF MOUSE IS OUT OF ARRANGE WINDOW

  local first_env_tr = drag_offset and mouse.tr or first_env_tr
  local offset_track, under_last_tr = generic_track_offset(env_track, first_env_tr)

  if job == 'PASTE' and under_last_tr and under_last_tr > 0 then
    for t = 1, under_last_tr do
      reaper.InsertTrackAtIndex((reaper.GetNumTracks()), true)
    end -- IF THE TRACKS ARE BELOW LAST TRACK OF THE PROJECT CREATE HAT TRACKS
    offset_track = reaper.GetTrack(0, reaper.GetNumTracks() - 1)
  end

  local env_offset = GetEnvOffset_MouseOverride(offset_track, env_name, nil, num) --or GetEnvOffset_MatchCriteria(offset_track, env_name)
  local env_paste_offset = mouse.p - as_start -- OFFSET BETWEEN ENVELOPE START AND MOUSE POSITION
  local mouse_offset = drag_offset and mouse.dp or env_paste_offset + pos_offset -- OFFSET BETWEEN MOUSE POSITION AND NEXT AREA SELECTION

  if job == "duplicate" then
    mouse_offset = as_end - as_start
    env_offset = env_track
  end

  if job == 'DRAG-PASTE' then
    env_offset = env_track
  end

  if env_offset and reaper.ValidatePtr(env_offset, "TrackEnvelope*") then -- IF TRACK HAS ENVELOPES PASTE THEM
    insert_edge_points(env_offset, {as_start, as_end}, mouse_offset, env_track) -- INSERT EDGE POINTS AT CURRENT ENVELOE VALUE AND DELETE WHOLE RANGE INSIDE (DO NOT ALLOW MIXING ENVELOPE POINTS AND THAT WEIRD SHIT)
    for i = 1, #env_data do
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
    reaper.Envelope_SortPoints(env_offset, env_track)
  elseif env_offset and reaper.ValidatePtr(env_offset, "MediaTrack*") then
    get_set_envelope_chunk(env_offset, env_track, as_start, as_end, mouse_offset)
  end
end

function del_env(env_track, as_start, as_end, pos_offset, job)
  local as_time_tbl = {as_start, as_end}

  local first_env = reaper.GetEnvelopePointByTime(env_track, as_start)
  local last_env = reaper.GetEnvelopePointByTime(env_track, as_end) + 1

  local retval1, time1, value1, shape1, tension1, selected1 = reaper.GetEnvelopePoint(env_track, first_env)
  local retval2, time2, value2, shape2, tension2, selected2 = reaper.GetEnvelopePoint(env_track, last_env)

  if value1 == 0 or value2 == 0 then
    reaper.DeleteEnvelopePointRange(env_track, as_start, as_end)
  else
    insert_edge_points(env_track, as_time_tbl, 0, nil, job)
  end
  reaper.Envelope_SortPoints(env_track)
end

function AreaDo(tbl, job, off)
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
  for a = 1, #tbl do
    local tbl = tbl[a]

    local pos_offset = 0
    pos_offset = pos_offset + (tbl.time_start - lowest_start()) --  OFFSET AREA SELECTIONS TO MOUSE POSITION
    local as_start, as_end = tbl.time_start, tbl.time_start + tbl.time_dur
    local area_offset = off and off - as_start or as_start -- THIS PREVENTED COPY MODE TO WORK

    local delete_source = false
    local delete_target = false
    local copy_items_and_envelopes = false
    local split_only = false

    --JOBS
    if job == 'move' then
      delete_source = true
      delete_target = true
      copy_items_and_envelopes = true
    elseif job == 'PASTE' or job == 'DRAG-PASTE' then
      delete_target = not copy and true or false -- DO NOT DELETE TARGET IF WE ARE IN COPY PASTE MODE
      copy_items_and_envelopes = true
    elseif job == 'del' then
      delete_source = true
    elseif job == 'split' then
      --delete_source = false
      split_only = true
    elseif job == 'duplicate' then
      delete_target = true
      area_offset = tbl.time_dur
      off = as_end
      copy_items_and_envelopes = true
    end

    if job == "del" or job == "duplicate" and #tbl > 1 then -- NEED TO ALSO UPDATE SELECTION INFO BEFORE THE JOB TO PREVENT BUGS WHEN USING CONSECUTIVE AREAS THAT OVERLAP
      tbl.sel_info = GetSelectionInfo(tbl)
    end
    --FILL ITEM BUFFERS AND CLEANUP AREAS
    for i = 1, #tbl.sel_info do
      local info = tbl.sel_info[i]
      local first_tr = find_highest_tr(info.track)

      if info.items then
        local item_track = info.track
        local item_data = info.items
        local item_buffers = copy_items_and_envelopes and copy_area_items_into_buffer(item_track, item_data, as_start, as_end)

        if delete_source then
          split_or_delete_items(item_track, item_data, as_start, as_end, 'del')
        end
        if delete_target then
          split_or_delete_items(item_track, nil, as_start + area_offset, as_end + area_offset, 'del') -- WE ARE SENDING NIL AS ITEM_TABLE, SO THE FUNCTION WILL SEARCH FOR ITEMS BASED ON TRACK AND TIME (THIS IS TARGET AREA)
        end
        if split_only then
          split_or_delete_items(item_track, item_data, as_start, as_end, 'split')
        end
        if copy_items_and_envelopes then
          paste_item_buffer(item_buffers, item_track, as_start, as_end, pos_offset, first_tr, off, job)
        end
      elseif info.env_points then
        --FILL ENVELOPE BUFFERS HERE
        local env_track = info.track
        local env_name = info.env_name
        local env_data = info.env_points

        if delete_source then
          del_env(env_track, as_start, as_end, pos_offset, job)
        end
        if delete_target then
          del_env(env_track, as_start + area_offset, as_end + area_offset, pos_offset, job)
        end
        if copy_items_and_envelopes then
          paste_env(env_track, env_name, env_data, as_start, as_end, pos_offset, first_tr, #tbl.sel_info, off, job)
        end
      end
    end
    --PASTE ENVELOPE BUFFERS
    if job == 'duplicate' then --OFFSET TABLE ON DUPLICATE
      tbl.time_start = tbl.time_start + tbl.time_dur
      tbl.x, tbl.w = convert_time_to_pixel(tbl.time_start, tbl.time_dur)
    end

    if job == "del" or job == "duplicate" then
      tbl.sel_info = GetSelectionInfo(tbl)
      if job == "duplicate" then
        GetGhosts(tbl.sel_info, tbl.time_start , tbl.time_start + tbl.time_dur, "update", (tbl.time_start - area_offset) + tbl.time_dur) -- UPDATE GHOST POSITION
      end
    end
  end
  reaper.Undo_EndBlock("AREA51 " .. job, 4)
  reaper.PreventUIRefresh(-1)
  reaper.UpdateTimeline()
  reaper.UpdateArrange()
end

--BUFFER RELATED FUNCTIONS
function copy_area_items_into_buffer(track, items, as_start, as_end)
  local item_buffer = {}
  for i = 1, #items do
    local item = items[i]
    local take = reaper.GetMediaItemTake(item, 0)
    local source = reaper.GetMediaItemTake_Source(take)

    local item_obj = {}
    item_obj.m_type = reaper.GetMediaSourceType(source, "")

    local chunk = ({reaper.GetItemStateChunk( item, '', false )})[2]

    local item_is_MIDI = item_obj.m_type:find('MIDI')

    local chunk_lines = split_by_line(chunk)

    for j = 1, #chunk_lines do
      local line = chunk_lines[j]
      if string.match(line, 'IGUID {(%S+)}') then
        local new_guid = reaper.genGuid()
        chunk_lines[j] = 'IGUID ' .. new_guid
      elseif string.match(line, "GUID {(%S+)}") then
        local new_guid = reaper.genGuid()
        chunk_lines[j] = 'GUID ' .. new_guid
      end

      if item_is_MIDI then
        if string.match(line, "POOLEDEVTS {(%S+)}") then
          local new_guid = reaper.genGuid()
          chunk_lines[j] = 'POOLEDEVTS' .. new_guid
        end

        if line == 'TAKE' then
          for k = j+1, #chunk_lines do -- scan chunk ahead to modify take chunk
            local take_line = chunk_lines[k]

            if string.match( take_line, 'POOLEDEVTS' ) then
              local new_guid = reaper.genGuid()
              chunk_lines[k] = 'POOLEDEVTS ' .. new_guid
            elseif string.match( take_line , 'GUID' ) then
              local new_guid = reaper.genGuid()
              chunk_lines[k] = 'GUID ' .. new_guid
            end

            if take_line == '>' then
              j = k
              goto take_chunk_break
            end
          end

          ::take_chunk_break::
        end
      end
    end

    chunk = table.concat(chunk_lines, "\n")

    item_obj.track = track
    item_obj.chunk = chunk
    item_obj.item_lenght = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    item_obj.item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    item_obj.take_offset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
    item_obj.item_dur = item_obj.item_lenght + item_obj.item_start

    item_buffer[i] = item_obj
  end

  return item_buffer
end

function paste_item_buffer(items, item_track, as_start, as_end, pos_offset, first_track, drag_offset, job)
  if not mouse.tr then
    return
  end -- DO NOT PASTE IF MOUSE IS OUT OF ARRANGE WINDOW

  local first_track = drag_offset and mouse.tr or first_track
  local offset_track, under_last_tr = generic_track_offset(item_track, first_track)

  if job == "PASTE" then
    if under_last_tr and under_last_tr > 0 then
      for t = 1, under_last_tr do
        reaper.InsertTrackAtIndex((reaper.GetNumTracks()), true)
      end
      -- IF THE TRACKS ARE BELOW LAST TRACK OF THE PROJECT CREATE HAT TRACKS
      offset_track = reaper.GetTrack(0, reaper.GetNumTracks() - 1)
    end
  end

  if job == "duplicate" then
    offset_track = item_track
  end

  for i = 1, #items do
    local item = items[i]
    local mouse_offset = drag_offset and drag_offset or pos_offset + mouse.p -- + wheel_offset
    create_item_from_buffer_info(item, offset_track, as_start, as_end, mouse_offset) -- CREATE ITEMS AT NEW POSITION
  end
end

function create_item_from_buffer_info(item, offset_track, as_start, as_end, mouse_time_pos)
  local track = offset_track

  local new_Item = reaper.AddMediaItemToTrack(track)
  local new_Take = reaper.AddTakeToMediaItem(new_Item)
  reaper.SetItemStateChunk(new_Item, item.chunk, true)

  local new_item_start, new_item_lenght, offset = as_item_position2(item.item_lenght, item.item_start, item.item_dur, as_start, as_end, mouse_time_pos) 
  reaper.SetMediaItemTakeInfo_Value(new_Take, "D_STARTOFFS", item.take_offset + offset) --Need to calculate offset better for items with different playrates

  reaper.SetMediaItemInfo_Value(new_Item, "D_POSITION", new_item_start) 
  reaper.SetMediaItemInfo_Value(new_Item, "D_LENGTH", new_item_lenght) 
end

--RANGE FUNCTIONS
--[[
function get_items_in_range(track, start_pos, end_pos)
	local items_in_range = {}
  local track_item_count = reaper.CountTrackMediaItems(track)
  local floating_point_threshold = 0.000001

	for i = 0, track_item_count-1 do
    local item = reaper.GetTrackMediaItem(track, i)
		local item_position = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
    local item_length = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')

		local item_end_position = item_position + item_length - floating_point_threshold
		item_position = item_position + floating_point_threshold

		local item_overlaps_start = is_between(start_pos, item_position, item_end_position)
		local item_overlaps_end = is_between(end_pos, item_position, item_end_position)

    if (is_between(start_pos, item_position, item_end_position) or is_between(end_pos, item_position, item_end_position)) or 
      (item_position >= start_pos and item_end_position <= end_pos) then --item is in range

      table.insert(items_in_range, item) 
    end
  end

	return items_in_range
end

function is_between(x, a,b)
	if x >= a and x <=b then
		return true
	else
		return false
	end
end
]]

function get_and_show_take_envelope(take, envelope_name)
  local env = reaper.GetTakeEnvelopeByName(take, envelope_name)

  if env == nil then
    local item = reaper.GetMediaItemTake_Item(take)
    local sel = reaper.IsMediaItemSelected(item)

    if not sel then
      reaper.SetMediaItemSelected(item, true)
    end

    if envelope_name == "Volume" then
      reaper.Main_OnCommand(reaper.NamedCommandLookup("_S&M_TAKEENV1"), 0) -- show take volume envelope
    elseif envelope_name == "Pan" then
      reaper.Main_OnCommand(reaper.NamedCommandLookup("_S&M_TAKEENV2"), 0) -- show take pan envelope
    elseif envelope_name == "Mute" then
      reaper.Main_OnCommand(reaper.NamedCommandLookup("_S&M_TAKEENV3"), 0) -- show take mute envelope
    elseif envelope_name == "Pitch" then
      reaper.Main_OnCommand(reaper.NamedCommandLookup("_S&M_TAKEENV10"), 0) -- show take pitch envelope
    end

    if sel then
      reaper.SetMediaItemSelected(item, true)
    end
    env = reaper.GetTakeEnvelopeByName(take, envelope_name)
  end

  return env
end

function get_take_env(item)
  local source_take = reaper.GetActiveTake(item)
  local source_env = get_and_show_take_envelope(source_take, "Volume")

  for i = 1, reaper.CountTakeEnvelopes(take) do
    local env = reaper.GetTakeEnvelope(take, i)
    retval, str = reaper.GetEnvelopeStateChunk(env, "", true)
  end
end

function get_items_in_as(as_tr, as_start, as_end, as_items)
  local as_items = {}

  for i = 1, reaper.CountTrackMediaItems(as_tr) do
    local item = reaper.GetTrackMediaItem(as_tr, i - 1)
    local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local item_end = item_start + item_len

    if
      (as_start >= item_start and as_start < item_end) and (as_end <= item_end and as_end > item_start) or -- IF SELECTION START & END ARE "IN" OR "ON" ITEM (START AND END ARE IN ITEM OR START IS ON ITEM START,END IS ON ITEM END)
        (as_start < item_start and as_end > item_end)
     then -- IF SELECTION START & END ARE OVER ITEM (SEL STARTS BEFORE ITEM END IS AFTER ITEM
      as_items[#as_items + 1] = item
    elseif (as_start >= item_start and as_start < item_end) and (as_end >= item_end) then -- IF SEL START IS IN THE ITEM
      as_items[#as_items + 1] = item
    elseif (as_end <= item_end and as_end > item_start) and (as_start <= item_start) then -- IF SEL END IS IN THE ITEM
      as_items[#as_items + 1] = item
    end
  end

  if #as_items ~= 0 then
    return as_items
  end
end

function split_or_delete_items(as_tr, as_items_tbl, as_start, as_end, key)
  -- IF FUNCTION DOEST NOT GET ITEM TABLE IT LOOKS FOR ITEMS ON TARGET AREA, ELSE LOOKS FOR ITEMS IN SOURCE AREA
  if not as_items_tbl then
    as_items_tbl = get_items_in_as(as_tr, as_start, as_end)
    if not as_items_tbl then return end -- IF FUNCTION ABOVE DOES NOT RETURN ANY ITEMS THEN EXIT THE FUNCTION SINCE WE HAVE NOT ITEMS TO WORK WITH
  end

  for i = #as_items_tbl, 1, -1 do
    local item = as_items_tbl[i]
    --local as_tr =  reaper.GetMediaItem_Track( as_tr )
    if key == "del" or key == "split" then
      local s_item_first = reaper.SplitMediaItem(item, as_end)
      local s_item_last = reaper.SplitMediaItem(item, as_start)
      -- ITEMS FOR DELETING
      if key == "del" then
        if s_item_first and s_item_last then
          reaper.DeleteTrackMediaItem(reaper.GetMediaItem_Track( s_item_last ), s_item_last) --reaper.DeleteTrackMediaItem(as_tr, s_item_last)
        elseif s_item_last and not s_item_first then
          reaper.DeleteTrackMediaItem(reaper.GetMediaItem_Track( s_item_last ), s_item_last) -- reaper.DeleteTrackMediaItem(as_tr, s_item_last)
        elseif s_item_first and not s_item_last then
          reaper.DeleteTrackMediaItem(reaper.GetMediaItem_Track( item ), item) -- reaper.DeleteTrackMediaItem(as_tr, item)
        elseif not s_item_first and not s_item_last then
          reaper.DeleteTrackMediaItem(reaper.GetMediaItem_Track( item ), item) -- reaper.DeleteTrackMediaItem(as_tr, item)
        end
      end
    end
  end

  if key == "del" then
    return key
  end
end

function get_env(as_tr, as_start, as_end)
  local env_points = {}

  for i = 1, reaper.CountTrackEnvelopes(as_tr) do
    local tr = reaper.GetTrackEnvelope(as_tr, i - 1)

    for j = 1, reaper.CountEnvelopePoints(tr) do
      local retval, time, value, shape, tension, selected = reaper.GetEnvelopePoint(tr, j - 1)

      if time >= as_start and time <= as_end then
        reaper.SetEnvelopePoint(tr, j - 1, _, _, _, _, true, _)

        env_points[#env_points + 1] = {
          id = j - 1,
          retval = retval,
          time = time,
          value = value,
          shape = shape,
          tension = tension,
          selected = true
        }
      end
    end
  end

  if #env_points ~= 0 then
    return env_points
  end
end

function get_as_tr_env_pts(as_tr, as_start, as_end)
  local retval, env_name = reaper.GetEnvelopeName(as_tr)
  local env_points = {}

  for i = 1, reaper.CountEnvelopePoints(as_tr) do
    local retval, time, value, shape, tension, selected = reaper.GetEnvelopePoint(as_tr, i - 1)

    if time >= as_start and time <= as_end then
      reaper.SetEnvelopePoint(as_tr, i - 1, time, value, shape, tension, true, true)

      env_points[#env_points + 1] = {
        id = i - 1,
        retval = retval,
        time = time,
        value = value,
        shape = shape,
        tension = tension,
        selected = true
      }
    elseif (time > as_start and time > as_end) or (time < as_start and time < as_end) then
      reaper.SetEnvelopePoint(as_tr, i - 1, time, value, shape, tension, false, true)
    end
  end

  if #env_points ~= 0 then
    return env_points
  end
end

local AI_info = {
  "D_POOL_ID",
  "D_POSITION",
  "D_LENGTH",
  "D_STARTOFFS",
  "D_PLAYRATE",
  "D_BASELINE",
  "D_AMPLITUDE",
  "D_LOOPSRC",
  "D_UISEL",
  "D_POOL_QNLEN"
}
function get_as_tr_AI(as_tr, as_start, as_end)
  local as_AI = {}

  for i = 1, reaper.CountAutomationItems(as_tr) do
    local AI = reaper.GetSetAutomationItemInfo(as_tr, i - 1, AI_info[2], 0, false) -- GET AI POSITION

    if AI >= as_start and AI <= as_end then
      as_AI[#as_AI + 1] = {} -- MAKE NEW TABLE FOR AI

      for j = 1, #AI_info do
        as_AI[#as_AI][AI_info[j]] = reaper.GetSetAutomationItemInfo(as_tr, i - 1, AI_info[j], 0, false) -- ADD AI INFO TO AI TABLE
      end
    end
  end

  if #as_AI ~= 0 then
    return as_AI
  end
end

function validate_as_items(tbl)
  for i = 1, #tbl.items do
    if not reaper.ValidatePtr(tbl.items[i], "MediaItem*") then
      tbl.items[i] = nil
    end -- IF ITEM DOES NOT EXIST REMOVE IT FROM TABLE
  end

  if #tbl.items == 0 then
    tbl.items = nil
  end -- IF ITEM TABLE IS EMPTY REMOVE TABLE
end