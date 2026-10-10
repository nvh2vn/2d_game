@tool
extends SceneTree

func _init() -> void:
	print("==================================================")
	print("--- SCANNING AND BUILDING PLATFORM TILESET ---")
	print("==================================================")

	var platform_files: Array[String] = []
	var include_keywords := ["platform", "ground", "terrain", "floor", "tileset", "block", "environment", "mossy", "rock", "stone", "brick", "land", "cliff"]
	var exclude_keywords := ["player", "enemy", "enemies", "vfx", "particle", "ui", "pickup", "hud", "button", "menu", "character", "bug", "knight", "hornet", "effect", "sound", "audio"]

	# Helper to scan dir recursively
	var scanned_files: Array[String] = []
	_scan_dir("res://assets", scanned_files)

	print("Total asset files found: ", scanned_files.size())

	for file in scanned_files:
		var l_file := file.to_lower()
		if not (l_file.ends_with(".png") or l_file.ends_with(".jpg") or l_file.ends_with(".webp")):
			continue

		var is_excluded := false
		for ex in exclude_keywords:
			if ex in l_file:
				is_excluded = true
				break
		if is_excluded:
			continue

		var is_included := false
		for inc in include_keywords:
			if inc in l_file:
				is_included = true
				break
		if is_included:
			platform_files.append(file)

	print("Filtered Platform Asset Files Count: ", platform_files.size())
	for p in platform_files:
		print(" - ", p)

	# 2. Build / Update TileSet Resource
	var tileset_dir := "res://assets/resources/tilesets"
	DirAccess.make_dir_recursive_absolute(tileset_dir)
	var tileset_path := tileset_dir + "/map_02_tileset.tres"

	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(32, 32)
	tileset.add_physics_layer(0)
	tileset.set_physics_layer_collision_layer(0, 1)
	tileset.set_physics_layer_collision_mask(0, 1)

	var added_sources_count = 0
	for file_path in platform_files:
		var tex: Texture2D = load(file_path)
		if not tex:
			continue

		var atlas_source := TileSetAtlasSource.new()
		atlas_source.texture = tex
		
		# Determine texture tile size
		var tex_w := tex.get_width()
		var tex_h := tex.get_height()
		
		# If texture is small (<= 64x64) or standard, use 32x32 tiles or texture bounds
		var tile_w = 32
		var tile_h = 32
		if tex_w < 32:
			tile_w = tex_w
		if tex_h < 32:
			tile_h = tex_h

		atlas_source.texture_region_size = Vector2i(tile_w, tile_h)
		
		var source_id = tileset.add_source(atlas_source)
		added_sources_count += 1

		# Create tiles in grid
		var cols = tex_w / tile_w
		var rows = tex_h / tile_h
		
		# Limit huge tilesheets to 16x16 tiles max to prevent memory bloat
		if cols > 16: cols = 16
		if rows > 16: rows = 16
		if cols < 1: cols = 1
		if rows < 1: rows = 1

		var is_one_way := false
		var l_path := file_path.to_lower()
		if "floating" in l_path or "thin" in l_path or "one_way" in l_path or "bridge" in l_path:
			is_one_way = true

		var half_w = float(tile_w) * 0.5
		var half_h = float(tile_h) * 0.5
		var rect_poly = PackedVector2Array([
			Vector2(-half_w, -half_h),
			Vector2(half_w, -half_h),
			Vector2(half_w, half_h),
			Vector2(-half_w, half_h)
		])

		for cx in range(cols):
			for cy in range(rows):
				var tile_coord = Vector2i(cx, cy)
				atlas_source.create_tile(tile_coord)
				var tile_data = atlas_source.get_tile_data(tile_coord, 0)
				if tile_data:
					tile_data.add_collision_polygon(0)
					tile_data.set_collision_polygon_points(0, 0, rect_poly)
					if is_one_way:
						tile_data.set_collision_polygon_one_way(0, 0, true)

	ResourceSaver.save(tileset, tileset_path)
	print("✓ Saved TileSet to: ", tileset_path, " with ", added_sources_count, " atlas sources!")

	# 3. Update Scene map_02_tilemap.tscn
	var scene_path := "res://assets/scenes/levels/map_02_tilemap.tscn"
	var packed_scene: PackedScene = load(scene_path)
	var map_root: Node2D = null

	if packed_scene:
		map_root = packed_scene.instantiate()
	else:
		map_root = Node2D.new()
		map_root.name = "Map02"

	# Reload tileset resource
	var saved_tileset: TileSet = load(tileset_path)

	# Find or create TileMapLayer_Platforms
	var platforms_layer: TileMapLayer = map_root.get_node_or_null("TileMapLayer_Platforms")
	if not platforms_layer:
		platforms_layer = TileMapLayer.new()
		platforms_layer.name = "TileMapLayer_Platforms"
		map_root.add_child(platforms_layer)
		platforms_layer.owner = map_root
		# Move platforms layer to top of children
		map_root.move_child(platforms_layer, 0)

	platforms_layer.tile_set = saved_tileset
	print("✓ TileMapLayer_Platforms node configured with TileSet!")

	# Ensure TileMapLayer_Walls also exists and is valid
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

	print("==================================================")
	print("🎉 PLATFORM TILESET AND SCENE INTEGRATION COMPLETE 🎉")
	print("==================================================")
	quit()


func _scan_dir(dir_path: String, out_files: Array[String]) -> void:
	var dir = DirAccess.open(dir_path)
	if not dir:
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
