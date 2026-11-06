extends "res://scripts/tests/chronicle_skill_information_render_smoke.gd"
func run() -> void:
 viewport=SubViewport.new();viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.gui_embed_subwindows=true;root.add_child(viewport)
 for person in JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chronicle/characters.json")):definitions[person.id]=person
 for repeat in 3:
  for dimensions in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
   viewport.size=dimensions
   for layout in [SETTINGS.HUD_LAYOUT_SIMPLE,SETTINGS.HUD_LAYOUT_TEAM_BAND]:
    await mount_battle();view.hud.set_layout(layout);view.refresh();await frames(8)
    await check_hover(layout,dimensions)
    view.queue_free();await frames(4);view=null
 viewport.queue_free();await frames(5);await create_timer(.3).timeout
 print("SKILL_HOVER_STRESS ","PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
