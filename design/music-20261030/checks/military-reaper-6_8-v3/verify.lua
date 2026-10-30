local project="/home/weathour/programs/desktop-projects/My-game/design/music-20261030/renders-military-v3/army_caochun_warform/army_caochun_warform.rpp"
local out="/home/weathour/programs/desktop-projects/My-game/design/music-20261030/checks/military-reaper-6_8-v3"
local empty="/home/weathour/programs/desktop-projects/My-game/design/music-20261030/checks/military-reaper-6_8-v3/empty.rpp"
local expected_bpm=144
local expected_num=6
local expected_denom=8
local stem_count=7
local seconds=120.0
local expected_notes={290,11,644,576,384,12,288}

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
  reaper.GetSetProjectInfo(0,'RENDER_BOUNDSFLAG',0,true)
  reaper.GetSetProjectInfo(0,'RENDER_STARTPOS',0,true)
  reaper.GetSetProjectInfo(0,'RENDER_ENDPOS',seconds,true)
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
