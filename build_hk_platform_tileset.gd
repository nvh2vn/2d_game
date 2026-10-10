@tool
extends SceneTree

func _init() -> void:
	print("==========================================================")
	print("--- SCANNING HOLLOW KNIGHT ARCHITECTURE & ENVIRONMENT ---")
	print("==========================================================")

	var target_dir := "res://assets/art/2d/new_assets/Hollow Knight sprites 1.5.12459 (Nintendo Switch 2 edition)/Architecture & Environment"
	
	var scanned_files: Array[String] = []
	_scan_dir(target_dir, scanned_files)

	print("Total files found in target folder: ", scanned_files.size())

	var platform_keywords := ["platform", "ground", "terrain", "floor", "rock", "stone", "ledge", "brick", "plat", "wall", "roof", "pillar", "bridge", "structure"]
	var ignore_keywords := ["vfx", "particle", "bg_far", "glow", "light", "dust", "smoke", "overlay", "fog"]

	var platform_files: Array[String] = []
	for file in scanned_files:
		var l_file := file.to_lower()
		if not (l_file.ends_with(".png") or l_file.ends_with(".jpg") or l_file.ends_with(".webp")):
			continue

		var is_ignored := false
		for ig in ignore_keywords:
			if ig in l_file:
				is_ignored = true
				break
		if is_ignored:
			continue

		var is_platform := false
		for kw in platform_keywords:
			if kw in l_file:
				is_platform = true
				break

		if is_platform:
			platform_files.append(file)

	print("Filtered Platform & Environment Props Count: ", platform_files.size())

	# 2. Build TileSet Resource
	var tileset_dir := "res://assets/resources/tilesets"
	DirAccess.make_dir_recursive_absolute(tileset_dir)
	var tileset_path := tileset_dir + "/map_02_tileset.tres"

	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(32, 32)
	tileset.add_physics_layer(0)
	tileset.set_physics_layer_collision_layer(0, 1)
	tileset.set_physics_layer_collision_mask(0, 1)

	var added_count = 0
	for file_path in platform_files:
		var global_path := ProjectSettings.globalize_path(file_path)
		var img := Image.load_from_file(global_path)
		if not img or img.is_empty():
			continue

		var tex := ImageTexture.create_from_image(img)
		if not tex:
			continue

		var tex_w := img.get_width()
		var tex_h := img.get_height()
		if tex_w <= 0 or tex_h <= 0:
			continue

		var atlas_source := TileSetAtlasSource.new()
		atlas_source.texture = tex
		# Set texture_region_size to exact image dimensions so 1 tile covers 100% of the prop!
		atlas_source.texture_region_size = Vector2i(tex_w, tex_h)

		var source_id = tileset.add_source(atlas_source)

		# Check if thin/floating platform (one way)
		var l_path := file_path.to_lower()
		var is_one_way := false
		if "float" in l_path or "thin" in l_path or "bridge" in l_path or "ledge" in l_path or "one_way" in l_path:
			is_one_way = true

		# Create tile at (0,0) covering 100% of texture
		atlas_source.create_tile(Vector2i(0, 0))
		var tile_data = atlas_source.get_tile_data(Vector2i(0, 0), 0)
		if tile_data:
			var half_w = float(tex_w) * 0.5
			var half_h = float(tex_h) * 0.5
			
			var poly = PackedVector2Array([
				Vector2(-half_w, -half_h),
				Vector2(half_w, -half_h),
				Vector2(half_w, half_h),
				Vector2(-half_w, half_h)
			])
			tile_data.add_collision_polygon(0)
			tile_data.set_collision_polygon_points(0, 0, poly)
			if is_one_way:
				tile_data.set_collision_polygon_one_way(0, 0, true)
			added_count += 1

	ResourceSaver.save(tileset, tileset_path)
	print("✓ Saved TileSet to: ", tileset_path, " with ", added_count, " single prop atlas sources!")

	# 3. Update Scene map_02_tilemap.tscn
	var scene_path := "res://assets/scenes/levels/map_02_tilemap.tscn"
	var packed_scene: PackedScene = load(scene_path)
	var map_root: Node2D = null

	if packed_scene:
		map_root = packed_scene.instantiate()
	else:
		map_root = Node2D.new()
		map_root.name = "Map02"

	var saved_tileset: TileSet = load(tileset_path)

	var platforms_layer: TileMapLayer = map_root.get_node_or_null("TileMapLayer_Platforms")
	if not platforms_layer:
		platforms_layer = TileMapLayer.new()
		platforms_layer.name = "TileMapLayer_Platforms"
		map_root.add_child(platforms_layer)
		platforms_layer.owner = map_root
		map_root.move_child(platforms_layer, 0)

	platforms_layer.tile_set = saved_tileset
	print("✓ TileMapLayer_Platforms assigned with updated TileSet!")

	var walls_layer: TileMapLayer = map_root.get_node_or_null("TileMapLayer_Walls")
	if walls_layer:
		walls_layer.tile_set = saved_tileset

	var new_packed := PackedScene.new()
	var pack_res = new_packed.pack(map_root)
	if pack_res == OK:
		var save_res = ResourceSaver.save(new_packed, scene_path)
		if save_res == OK:
			print("✓ SUCCESS: Saved updated scene to: ", scene_path)
		else:
			printerr("ERROR saving scene: ", save_res)
	else:
		printerr("ERROR packing scene: ", pack_res)

	print("==========================================================")
	print("🎉 HOLLOW KNIGHT PLATFORM TILESET INTEGRATION COMPLETE 🎉")
	print("==========================================================")
	quit()


func _scan_dir(dir_path: String, out_files: Array[String]) -> void:
	var dir = DirAccess.open(dir_path)
	if not dir:
		printerr("Cannot open dir: ", dir_path)
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name != "." and file_name != "..":
			var full_path = dir_path + "/" + file_name
			if dir.current_is_dir():
				_scan_dir(full_path, out_files)
			else:
				out_files.append(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()
