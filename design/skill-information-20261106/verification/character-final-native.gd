extends "res://scripts/tests/chronicle_skill_information_render_smoke.gd"
func run() -> void:
 SETTINGS.save_comfort("reduced_motion",true)
 viewport=SubViewport.new();viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 shell=SHELL.instantiate();shell.session.directory="user://character-final";viewport.add_child(shell);await frames(8)
 shell.open_page("preparation");await frames(8)
 for dimensions in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
  viewport.size=dimensions;await frames(8)
  for id in ["JIA","F11","N07"]:
   shell.inspect_character(id,"abilities");await frames(12)
   var summary: Label=shell.character_sheet.find_child("character_playstyle_summary",true,false)
   expect(summary.text==INFO.character(id).overview,"final overview "+id)
   await capture("character-info-%s-%d"%[id,dimensions.x])
   shell.close_character_sheet(false);await frames(5)
 shell.queue_free();await frames(5);viewport.queue_free();await frames(5);await create_timer(.3).timeout
 print("SKILL_CHARACTER_FINAL_RENDER ","PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
