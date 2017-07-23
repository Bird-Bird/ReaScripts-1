--[[
 * ReaScript Name: Select all other items on track.lua
 * Discription: Script select all items on the track except selected one
 * Author: SeXan
 * Licence: GPL v3
 * REAPER: 5.0
 * Extensions: None
 * Version: 1.12
--]]
 
--[[
 * Changelog:
 * v1.12 (2017-07-23)
  + fixed error
--]]

function Main()
  local sel_item = reaper.GetSelectedMediaItem( 0, 0 )
  
  if not sel_item then return 0 end
  
  local tr =  reaper.GetMediaItem_Track( sel_item )
  reaper.SetMediaItemInfo_Value( sel_item, "B_UISEL", 0 )
  
  local cnt_items = reaper.CountTrackMediaItems( tr ) 
  
    for i = 1, cnt_items do
      local item = reaper.GetMediaItem( 0, i-1 )
      if item ~= sel_item then 
        reaper.SetMediaItemInfo_Value( item, "B_UISEL", 1 )
      end
    end 
  reaper.UpdateArrange()
end
Main()
