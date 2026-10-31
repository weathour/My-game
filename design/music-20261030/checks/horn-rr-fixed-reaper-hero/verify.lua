local project="/home/weathour/programs/desktop-projects/My-game/design/music-20261030/renders-horn-rr-fixed/hero_main/hero_main.rpp"
local out="/home/weathour/programs/desktop-projects/My-game/design/music-20261030/checks/horn-rr-fixed-reaper-hero"
local empty="/home/weathour/programs/desktop-projects/My-game/design/music-20261030/checks/horn-rr-fixed-reaper-hero/empty.rpp"
local expected_bpm=112
local expected_num=4
local expected_denom=4
local stem_count=6
local expected_frames=4937143
local seconds=expected_frames/48000
local expected_notes={146,14,255,184,9,104}

local log=assert(io.open(out..'/verify.log','w'))
local function run()
  reaper.Main_openProject('noprompt:'..project)
  assert(reaper.CountTracks(0)==stem_count*2,'track count mismatch')
  local num,denom,bpm=reaper.TimeMap_GetTimeSigAtTime(0,0)
  log:write('tempo='..bpm..' meter='..num..'/'..denom..'\n')
  assert(math.abs(bpm-expected_bpm)<0.0001,'tempo mismatch')
  assert(num==expected_num and denom==expected_denom,'meter mismatch')
  for i=0,reaper.CountTracks(0)-1 do
    local tr=reaper.GetTrack(0,i)
    local item=reaper.GetTrackMediaItem(tr,0)
    local take=reaper.GetActiveTake(item)
    if i<stem_count then
      local source=reaper.GetMediaItemTake_Source(take)
      assert(reaper.GetMediaSourceSampleRate(source)==48000,'source sample rate')
      assert(reaper.GetMediaSourceNumChannels(source)==2,'source channel count')
    else
      local _,notes,cc=reaper.MIDI_CountEvts(take)
      assert(notes==expected_notes[i-stem_count+1],'MIDI note count mismatch')
      assert(reaper.GetMediaTrackInfo_Value(tr,'B_MUTE')==1,'MIDI safety mute missing')
      log:write('midi_track='..(i-stem_count+1)..' notes='..notes..' cc='..cc..'\n')
    end
  end
  log:flush()
  -- Custom render bounds go through REAPER's render dialog time fields and
  -- lose sub-millisecond precision in 7.83. The API's time selection retains
  -- the exact integer-sample endpoint; do not pad/trim or relax length checks.
  reaper.GetSet_LoopTimeRange2(0,true,false,0,seconds,false)
  local selection_start,selection_end=reaper.GetSet_LoopTimeRange2(0,false,false,0,0,false)
  assert(math.abs(selection_start)<0.25/48000,'time selection start changed')
  assert(math.abs(selection_end-seconds)<0.25/48000,'time selection end changed')
  log:write('exact_time_selection_frames='..expected_frames..' end_seconds='..string.format('%.15f',selection_end)..'\n')
  log:flush()
  reaper.GetSetProjectInfo(0,'RENDER_BOUNDSFLAG',2,true)
  reaper.GetSetProjectInfo(0,'RENDER_SRATE',48000,true)
  reaper.GetSetProjectInfo(0,'RENDER_CHANNELS',2,true)
  reaper.GetSetProjectInfo(0,'RENDER_SETTINGS',0,true)
  reaper.GetSetProjectInfo(0,'RENDER_TAILFLAG',0,true)
  reaper.GetSetProjectInfo_String(0,'RENDER_FORMAT','evaw',true)
  reaper.GetSetProjectInfo_String(0,'RENDER_FILE',out,true)
  reaper.GetSetProjectInfo_String(0,'RENDER_PATTERN','reaper_mix',true)
  reaper.Main_OnCommand(42230,0)
  log:write('COMPLETE\n')
end
local ok,err=xpcall(run,debug.traceback)
if not ok then log:write('ERROR '..tostring(err)..'\n') end
log:close()
reaper.defer(function() reaper.Main_openProject('noprompt:'..empty);reaper.Main_OnCommand(40004,0) end)
