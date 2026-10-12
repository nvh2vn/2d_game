extends SceneTree

func _init() -> void:
	print("==================================================")
	print("--- TEST TASK 1: CLEAN INVENTORY & SHOP TUK ---")
	print("==================================================")

	# 1. Khởi tạo SaveManager
	var sm_script = load("res://assets/scripts/core/save_manager.gd")
	var sm = sm_script.new()
	root.add_child(sm)
	sm._enter_tree()
	sm._ready()

	# 2. Reset New Game
	print("[1] Testing reset_and_start_new_game()...")
	sm.reset_and_start_new_game()
	var initial_items = sm.get_inventory_items()
	print("Initial items count: ", initial_items.size())
	assert(initial_items.size() == 0, "Inventory must be empty on New Game!")
	print("-> SUCCESS: Inventory is 100% EMPTY on New Game.")

	# 3. Test InventoryScreen với Túi đồ trống
	print("[2] Testing InventoryScreen with empty inventory...")
	var inv_scene = load("res://assets/scenes/menu/inventory_screen.tscn")
	var inv_inst = inv_scene.instantiate()
	root.add_child(inv_inst)
	inv_inst._refresh_inventory_tab()

	var items_container: Control = inv_inst.items_container
	print("Items container child count: ", items_container.get_child_count())
	assert(items_container.get_child_count() == 0, "No items slots should be created when empty!")
	print("Preview name text: ", inv_inst.item_preview_name.text)
	assert(inv_inst.item_preview_name.text == "TÚI ĐỒ TRỐNG", "Preview must show TÚI ĐỒ TRỐNG!")
	assert(inv_inst.item_preview_icon.texture == null, "Preview icon must be null when empty!")
	print("-> SUCCESS: InventoryScreen properly renders empty inventory state.")

	# 4. Tạo Mock Player với đủ Geo
	print("[3] Creating Mock Player with 1000 Geo and max_health 5...")
	var player = CharacterBody2D.new()
	player.add_to_group("player")
	player.set("geo_amount", 1000)
	player.set("max_health", 5)
	player.set("current_health", 5)
	player.set("inventory", [])
	root.add_child(player)

	# 5. Mở Shop Tuk và mua 4 món
	print("[4] Opening Shop Tuk and purchasing items...")
	var shop_script = load("res://assets/scripts/ui/shop_menu.gd")
	var shop = shop_script.new()
	root.add_child(shop)
	shop._ready()
	shop.open_shop(player, "Tuk (Nhà Thu Gom)")

	# Mua Simple Key (150 Geo)
	var key_item = shop.shop_items[0]
	print("Buying item 1: ", key_item["name"])
	shop._on_item_buy_pressed(key_item)

	# Mua Map Tuk (100 Geo)
	var map_item = shop.shop_items[1]
	print("Buying item 2: ", map_item["name"])
	shop._on_item_buy_pressed(map_item)

	# Mua Rancid Egg lần 1 (80 Geo)
	var egg_item = shop.shop_items[2]
	print("Buying item 3: ", egg_item["name"])
	shop._on_item_buy_pressed(egg_item)

	# Mua Mask Shard (250 Geo)
	var mask_item = shop.shop_items[3]
	print("Buying item 4: ", mask_item["name"])
	shop._on_item_buy_pressed(mask_item)

	# Mua Rancid Egg lần 2 (80 Geo) - test stack
	print("Buying item 5: Rancid Egg again (stack test)...")
	shop._on_item_buy_pressed(egg_item)

	print("Remaining player Geo: ", player.get("geo_amount"))
	assert(player.get("geo_amount") == 1000 - 150 - 100 - 80 - 250 - 80, "Geo deduction calculation incorrect!")
	print("Player Max Health: ", player.get("max_health"))
	assert(player.get("max_health") == 6, "Mask Shard should increase max_health to 6!")

	# 6. Kiểm tra SaveManager inventory
	print("[5] Verifying SaveManager inventory entries...")
	var saved_items = sm.get_inventory_items()
	print("Total items in SaveManager: ", saved_items.size())
	assert(saved_items.size() == 4, "Should have 4 unique item entries!")

	var egg_found = false
	for it in saved_items:
		print(" - Item: [", it.get("id"), "] ", it.get("name"), " | Count: ", it.get("count", 1), " | Category: ", it.get("category", ""), " | Icon exists: ", ResourceLoader.exists(it.get("icon", "")))
		assert(ResourceLoader.exists(it.get("icon", "")), "Item icon asset must exist: " + it.get("icon", ""))
		assert(it.get("name", "") != "", "Item must have non-empty name!")
		assert(it.get("desc", "") != "", "Item must have non-empty description!")
		if it.get("id") == "rancid_egg":
			egg_found = true
			assert(it.get("count", 1) == 2, "Rancid egg should have count = 2!")
	assert(egg_found, "Rancid egg should be in inventory!")
	print("-> SUCCESS: All 4 purchased items correctly stored with metadata and valid icon paths.")

	# 7. Refresh lại InventoryScreen và kiểm tra UI Grid & Preview
	print("[6] Refreshing InventoryScreen with purchased items...")
	inv_inst._refresh_inventory_tab()
	print("Items container child count: ", items_container.get_child_count())
	assert(items_container.get_child_count() == 4, "Inventory grid should have 4 item slots!")

	# Kiểm tra preview item đầu tiên
	print("Item 1 preview name: ", inv_inst.item_preview_name.text)
	print("Item 1 preview category: ", inv_inst.item_preview_category.text)
	print("Item 1 preview desc: ", inv_inst.item_preview_desc.text)
	assert(inv_inst.item_preview_name.text.contains("CHÌA KHÓA ĐƠN"), "First item preview should show Chìa Khóa Đơn!")

	# Giả lập click vào slot Trứng Thối
	print("[7] Simulating click on Rancid Egg slot...")
	var egg_slot = items_container.get_child(2) as Button
	egg_slot.pressed.emit()
	print("Egg preview name: ", inv_inst.item_preview_name.text)
	print("Egg preview category: ", inv_inst.item_preview_category.text)
	print("Egg preview desc: ", inv_inst.item_preview_desc.text)
	assert(inv_inst.item_preview_name.text.contains("TRỨNG THỐI"), "Egg preview should contain TRỨNG THỐI!")
	assert(inv_inst.item_preview_name.text.contains("(X2)"), "Egg preview should contain (X2) stack!")

	# 8. Test lưu và đọc lại từ đĩa (Persistence)
	print("[8] Testing Persistence save and load from disk...")
	sm.save_to_disk()
	var sm2 = sm_script.new()
	root.add_child(sm2)
	sm2._enter_tree()
	sm2._ready()
	var loaded_items = sm2.get_inventory_items()
	print("Loaded items count after reading from disk: ", loaded_items.size())
	assert(loaded_items.size() == 4, "Loaded items should match saved items!")
	print("-> SUCCESS: Save & Load persistence verified successfully.")

	print("==================================================")
	print("ALL TASK 1 TESTS PASSED PERFECTLY!")
	print("==================================================")
	quit(0)
