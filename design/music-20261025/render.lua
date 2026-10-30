-- Run in REAPER 7.83 with the bundled Synthy McSynthface and Major General MIDI.
-- The second cycle is the export region: the first establishes instrument/reverb tails.
-- The launcher owns this instance and supplies fresh output/project directories.
local config = assert(MYGAME_RENDER_CONFIG, 'Run through render_batch.py')
local out = config.output
local cues = dofile(config.score)
local log = assert(io.open(out .. '/render.log', 'w'))
local function checked(ok, message)
  if not ok then log:write('ERROR '..message..'\n'); log:flush(); error(message) end
end
local function render_all()
for _, cue in ipairs(cues) do
  -- Opening our own blank project avoids the normal New Project save dialog.
  reaper.Main_openProject('noprompt:' .. config.empty_project)
  reaper.SetCurrentBPM(0, cue.bpm, true)
  local duration = cue.beats * 60 / cue.bpm
  local repeats = cue.loop and 2 or 1
  local render_end = duration * repeats + 3
  for index, part in ipairs(cue.tracks) do
    reaper.InsertTrackAtIndex(index - 1, false)
    local tr = reaper.GetTrack(0, index - 1)
    reaper.GetSetMediaTrackInfo_String(tr, 'P_NAME', part.name, true)
    reaper.SetMediaTrackInfo_Value(tr, 'D_VOL', 10^(part.db/20))
    reaper.SetMediaTrackInfo_Value(tr, 'D_PAN', part.pan)
    local piano = part.instrument == 'piano'
    local fx = reaper.TrackFX_AddByName(tr, piano and 'JS: chmaha-inst/SynthyMcSynthface.jsfx' or 'JS: chmaha-inst/MajorGeneralMIDI.jsfx', false, -1)
    checked(fx >= 0, cue.id .. ': missing bundled instrument')
    if piano then
      reaper.TrackFX_SetParam(tr, fx, 0, 3) -- acoustic piano
      reaper.TrackFX_SetParam(tr, fx, 7, cue.id == 'camp_signal' and 5 or 4)
    else
      reaper.TrackFX_SetParam(tr, fx, part.channel, part.channel == 9 and 128 or part.program)
      reaper.TrackFX_SetParam(tr, fx, 19, 0) -- no bank reverb: one coherent room below
      reaper.TrackFX_SetParam(tr, fx, 22, 0) -- chorus off
    end
    for repetition = 0, repeats - 1 do
      local offset = repetition * duration
      local item = reaper.CreateNewMIDIItemInProj(tr, offset, offset + duration, false)
      local take = reaper.GetActiveTake(item)
      reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', cue.title .. (repetition == 0 and ' / theme' or ' / loop master'), true)
      for _, n in ipairs(part.notes) do
        local p1 = reaper.MIDI_GetPPQPosFromProjTime(take, offset + n[1] * 60 / cue.bpm)
        local p2 = reaper.MIDI_GetPPQPosFromProjTime(take, offset + (n[1] + n[2]) * 60 / cue.bpm)
        reaper.MIDI_InsertNote(take, false, false, p1, p2, part.channel, n[3], n[4], true)
      end
      reaper.MIDI_Sort(take)
    end
  end
  local master = reaper.GetMasterTrack(0)
  reaper.SetMediaTrackInfo_Value(master, 'D_VOL', .52)
  local verb = reaper.TrackFX_AddByName(master, 'JS: chmaha-fx/Reverb.jsfx', false, -1)
  checked(verb >= 0, 'missing room reverb')
  reaper.TrackFX_SetParam(master, verb, 0, 18)
  reaper.TrackFX_SetParam(master, verb, 2, 1.0)
  reaper.TrackFX_SetParam(master, verb, 3, cue.id == 'camp_signal' and 1.65 or .95)
  reaper.TrackFX_SetParam(master, verb, 4, 6500)
  reaper.TrackFX_SetParam(master, verb, 9, cue.id == 'camp_signal' and .16 or .075)
  reaper.AddProjectMarker2(0, true, cue.loop and duration or 0, cue.loop and 2 * duration or render_end, 'GAME EXPORT / ' .. cue.id, -1, 0)
  reaper.GetSetProjectInfo(0, 'RENDER_BOUNDSFLAG', 0, true)
  reaper.GetSetProjectInfo(0, 'RENDER_STARTPOS', 0, true)
  reaper.GetSetProjectInfo(0, 'RENDER_ENDPOS', render_end, true)
  reaper.GetSetProjectInfo(0, 'RENDER_SRATE', 48000, true)
  reaper.GetSetProjectInfo(0, 'RENDER_CHANNELS', 2, true)
  reaper.GetSetProjectInfo(0, 'RENDER_SETTINGS', 0, true)
  reaper.GetSetProjectInfo(0, 'RENDER_TAILFLAG', 0, true)
  reaper.GetSetProjectInfo_String(0, 'RENDER_FORMAT', 'evaw', true)
  reaper.GetSetProjectInfo_String(0, 'RENDER_FILE', out, true)
  reaper.GetSetProjectInfo_String(0, 'RENDER_PATTERN', cue.id, true)
  local project_path = config.projects .. '/' .. cue.id .. '.rpp'
  reaper.Main_SaveProjectEx(0, project_path, 8)
  log:write('START ' .. cue.id .. '\n'); log:flush()
  reaper.Main_OnCommand(42230, 0) -- Render current settings, auto-close render dialog.
  -- Rendering can change saved render settings; persist those before switching.
  reaper.Main_SaveProjectEx(0, project_path, 8)
  local output = io.open(out .. '/' .. cue.id .. '.wav', 'rb')
  checked(output ~= nil, cue.id .. ': render produced no WAV')
  local size = output:seek('end'); output:close()
  checked(size > 44, cue.id .. ': render produced an empty WAV')
  log:write('DONE ' .. cue.id .. '\n'); log:flush()
end
log:write('COMPLETE\n')
end

-- A Lua error must become a failed job, not a modal REAPER error dialog.
local ok, err = xpcall(render_all, debug.traceback)
if not ok then log:write('ERROR ' .. tostring(err) .. '\n') end
log:close()
reaper.defer(function()
  reaper.Main_openProject('noprompt:' .. config.empty_project)
  reaper.Main_OnCommand(40004, 0)
end)
