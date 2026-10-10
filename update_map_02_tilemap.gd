@tool
extends SceneTree

func _init() -> void:
	print("--- ATTACHING TILESET TO MAP_02_TILEMAP.TSCN ---")
	var scene_path := "res://assets/scenes/levels/map_02_tilemap.tscn"
	var tileset_path := "res://assets/resources/tilesets/map_02_tileset.tres"

	var packed_scene: PackedScene = load(scene_path)
	var map_root: Node2D = null

	if packed_scene:
		map_root = packed_scene.instantiate()
	else:
		map_root = Node2D.new()
		map_root.name = "Map02"

	var saved_tileset: TileSet = load(tileset_path)
	assert(saved_tileset != null, "TileSet resource must load!")

	var platforms_layer: TileMapLayer = map_root.get_node_or_null("TileMapLayer_Platforms")
	if not platforms_layer:
		platforms_layer = TileMapLayer.new()
		platforms_layer.name = "TileMapLayer_Platforms"
		map_root.add_child(platforms_layer)
		platforms_layer.owner = map_root
		map_root.move_child(platforms_layer, 0)

	platforms_layer.tile_set = saved_tileset
	print("✓ TileMapLayer_Platforms node assigned with map_02_tileset.tres")

	var new_packed := PackedScene.new()
	var pack_res = new_packed.pack(map_root)
	if pack_res == OK:
		var save_res = ResourceSaver.save(new_packed, scene_path)
		if save_res == OK:
			print("✓ SUCCESS: Saved map_02_tilemap.tscn without errors!")
		else:
			printerr("ERROR saving scene: ", save_res)
	else:
		printerr("ERROR packing scene: ", pack_res)

	quit()
