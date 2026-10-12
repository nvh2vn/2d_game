class_name InventoryScreen
extends CanvasLayer

## Menu 3 Tab: NHIỆM VỤ (Quests), TÚI ĐỒ & KỸ NĂNG (Inventory & Stats), SỔ TAY THỢ SĂN (Hunter's Journal)
## Thiết kế theo chuẩn phong cách Gothic tối giản của Hollow Knight / Silksong dành cho Godot 4 2D Mobile.

enum TAB {
	QUESTS = 0,
	INVENTORY = 1, # Mặc định
	JOURNAL = 2
}

@export_group("Audio")
@export var click_sfx: AudioStream = preload("res://assets/art/2d/silksong_full/Sounds/UI/ui_button_confirm.mp3")
@export var hover_sfx: AudioStream = preload("res://assets/art/2d/silksong_full/Sounds/UI/ui_change_selection.mp3")
@export var page_sfx: AudioStream = preload("res://assets/art/2d/new_assets/Audio/Effects/UI/ui_map_update.wav")

# HUD & Menu Overlay
@onready var hud_inv_button: TextureButton = get_node_or_null("%HUDInventoryButton")
@onready var menu_overlay: Control = %MenuOverlay
@onready var close_button: Button = %CloseButton

# Tab Navigation Buttons
@onready var prev_tab_btn: Button = %PrevTabButton
@onready var next_tab_btn: Button = %NextTabButton
@onready var tab_btn_quests: Button = %TabButtonQuests
@onready var tab_btn_inventory: Button = %TabButtonInventory
@onready var tab_btn_journal: Button = %TabButtonJournal

# Tab Pages
@onready var page_quests: Control = %PageQuests
@onready var page_inventory: Control = %PageInventory
@onready var page_journal: Control = %PageJournal

# TAB 1: Quests UI
@onready var quest_list_container: VBoxContainer = %QuestListContainer
@onready var quest_detail_icon: TextureRect = %QuestDetailIcon
@onready var quest_detail_title: Label = %QuestDetailTitle
@onready var quest_detail_status: Label = %QuestDetailStatus
@onready var quest_detail_desc: Label = %QuestDetailDesc
@onready var quest_detail_objective: Label = %QuestDetailObjective

# TAB 2: Inventory & Stats UI
@onready var geo_count_label: Label = %GeoCountLabel
@onready var health_count_label: Label = %HealthCountLabel
@onready var silk_count_label: Label = %SilkCountLabel
@onready var abilities_container: Control = %AbilitiesGrid
@onready var items_container: GridContainer = %ItemsGrid
@onready var item_preview_icon: TextureRect = %ItemPreviewIcon
@onready var item_preview_name: Label = %ItemPreviewName
@onready var item_preview_category: Label = %ItemPreviewCategory
@onready var item_preview_desc: Label = %ItemPreviewDesc
@onready var selection_brackets: TextureRect = get_node_or_null("%SelectionBrackets")
@onready var weapon_slot: Button = get_node_or_null("%WeaponSlot")
@onready var crests_container: Control = get_node_or_null("%CrestsContainer")
@onready var mask_upgrade_container: Control = get_node_or_null("%MaskUpgradeContainer")
@onready var mask_shard_progress: Label = get_node_or_null("%MaskShardProgress")
@onready var upgrade_mask_button: Button = get_node_or_null("%UpgradeMaskButton")

# TAB 3: Hunter's Journal UI
@onready var journal_summary_label: Label = %JournalSummaryLabel
@onready var enemy_list_container: VBoxContainer = %EnemyListContainer
@onready var enemy_showcase_art: TextureRect = %EnemyShowcaseArt
@onready var enemy_showcase_name: Label = %EnemyShowcaseName
@onready var enemy_showcase_kills: Label = %EnemyShowcaseKills
@onready var enemy_showcase_desc: Label = %EnemyShowcaseDesc
@onready var enemy_hunter_lore_box: Control = %EnemyHunterLoreBox
@onready var enemy_hunter_lore_text: Label = %EnemyHunterLoreText

@onready var sfx_player: AudioStreamPlayer = %SFXPlayer

var current_tab: TAB = TAB.INVENTORY
var is_menu_open: bool = false
var active_selected_quest: String = ""
var active_selected_item: String = ""
var active_selected_enemy: String = ""

# --- DỮ LIỆU CỐ ĐỊNH CHO SỔ TAY THỢ SĂN (HUNTER'S JOURNAL DATABASE) ---
const BESTIARY_DATABASE: Array[Dictionary] = [
	{
		"id": "crawlid",
		"name": "Crawlid",
		"portrait": "res://assets/art/2d/Hunter_s Journal/Crawlid - bestiary_crawler_s.png",
		"full_art": "res://assets/art/2d/Hunter_s Journal/Crawlid - bestiary_crawler_f.png",
		"required_kills": 5,
		"short_desc": "Loài bọ nhỏ di chuyển chậm rãi trên mặt đất, không có khả năng tự vệ.",
		"hunter_lore": "Kẻ yếu ớt nhất vương quốc. Chúng bò vô định trên những vách đá hoang phế, dường như chẳng màng đến sống chết."
	},
	{
		"id": "vengefly",
		"name": "Vengefly",
		"portrait": "res://assets/art/2d/Hunter_s Journal/Vengefly - bestiary_buzzer_s.png",
		"full_art": "res://assets/art/2d/Hunter_s Journal/Vengefly - bestiary_buzzer_f.png",
		"required_kills": 8,
		"short_desc": "Loài côn trùng bay hung hãn, luôn lao thẳng vào kẻ xâm nhập khi phát hiện.",
		"hunter_lore": "Tiếng cánh đập vo ve inh ỏi báo trước một đòn lao tới. Hãy giữ chắc ngọn kiếm và chém gục chúng khi chúng vừa vào tầm."
	},
	{
		"id": "aspid_hunter",
		"name": "Aspid Hunter",
		"portrait": "res://assets/art/2d/Hunter_s Journal/Aspid Hunter - bestiary__0008_spitter_s.png",
		"full_art": "res://assets/art/2d/Hunter_s Journal/Aspid Hunter - bestiary__0009_spitter.png",
		"required_kills": 6,
		"short_desc": "Kẻ săn mồi bay lượn trên cao, có khả năng bắn đạn axit từ khoảng cách xa.",
		"hunter_lore": "Những kẻ xảo quyệt thích rình rập ngoài tầm vũ khí. Đừng đứng yên một chỗ, hãy tiếp cận và kết liễu chúng thật nhanh."
	},
	{
		"id": "wandering_husk",
		"name": "Wandering Husk",
		"portrait": "res://assets/art/2d/Hunter_s Journal/Wandering Husk - bestiary_bug_s.png",
		"full_art": "res://assets/art/2d/Hunter_s Journal/Wandering Husk - bestiary_bug_f.png",
		"required_kills": 10,
		"short_desc": "Cái xác còn sót lại của cư dân phế tích, lang thang không mục đích.",
		"hunter_lore": "Dù thân xác còn nguyên vẹn, tâm trí đã biến mất từ lâu. Chúng chỉ biết tấn công bất cứ thứ gì phát ra tiếng động."
	},
	{
		"id": "mosscreep",
		"name": "Mosscreep",
		"portrait": "res://assets/art/2d/Hunter_s Journal/Mosscreep - bestiary__0040_moss-crawler_s.png",
		"full_art": "res://assets/art/2d/Hunter_s Journal/Mosscreep - bestiary__0041_moss-crawler.png",
		"required_kills": 5,
		"short_desc": "Sinh vật ẩn mình dưới lớp rêu lá, giật mình bỏ chạy khi bị quấy rầy.",
		"hunter_lore": "Ẩn nấp trong thảm thực vật ẩm ướt. Một bữa ăn nhẹ lý tưởng cho thợ săn khi đi săn trong rừng rậm."
	},
	{
		"id": "winged_sentry",
		"name": "Winged Sentry",
		"portrait": "res://assets/art/2d/Hunter_s Journal/Winged Sentry - bestiary_ruins_zombie_flier_s.png",
		"full_art": "res://assets/art/2d/Hunter_s Journal/Winged Sentry - bestiary_ruins_zombie_flier_f.png",
		"required_kills": 7,
		"short_desc": "Vệ binh bay lượn tuần tra mang theo đao dài của kinh thành phế tích.",
		"hunter_lore": "Kỹ năng chiến đấu của chúng vẫn còn in hằn trong cơ bắp dù linh hồn đã lụi tàn. Đòn chém bổ nhào từ trên cao rất nguy hiểm."
	},
	{
		"id": "belfly",
		"name": "Belfly",
		"portrait": "res://assets/art/2d/Hunter_s Journal/Belfly - bestiary_bat_dropper_s.png",
		"full_art": "res://assets/art/2d/Hunter_s Journal/Belfly - bestiary_bat_dropper_f.png",
		"required_kills": 4,
		"short_desc": "Sinh vật treo ngược trên trần hang, tự phát nổ khi lao trúng con mồi.",
		"hunter_lore": "Tiếng gầm rú điên loạn vang lên khi chúng buông mình rơi xuống. Tránh xa bán kính vụ nổ nếu không muốn tan xác."
	},
	{
		"id": "nightmare_king",
		"name": "Nightmare King Grimm",
		"portrait": "res://assets/art/2d/Hunter_s Journal/Nightmare King Grimm - bestiary__0000_grimm_nightmare_boss_portrait.png",
		"full_art": "res://assets/art/2d/Hunter_s Journal/Nightmare King Grimm - Bestiary_Grimm_Nightmare_boss.png",
		"required_kills": 1,
		"short_desc": "Bậc thầy của ngọn lửa ác mộng đỏ thẫm và đoàn xiếc Grimm huyền bí.",
		"hunter_lore": "Vũ điệu của ngọn lửa vĩnh cửu. Kẻ triệu hồi cơn ác mộng để nuôi dưỡng đứa con của nghi lễ. Một đối thủ xứng tầm bậc nhất."
	}
]

# --- DỮ LIỆU KỸ NĂNG TỪ MOVEMENT ASSETS (SILKSONG TOUCH CONTROLS ICONS) ---
const ABILITIES_CONFIG: Array[Dictionary] = [
	{
		"key": "attack",
		"name": "NEEDLE STRIKE",
		"category": "VŨ KHÍ CHÍNH",
		"action": "(Attack / Tấn công)",
		"icon": "res://assets/art/2d/Movement/button_attack.png",
		"desc": "Nhát chém cơ bản vung thanh kiếm tơ chém xuyên qua kẻ địch."
	},
	{
		"key": "dash",
		"name": "MOTHWING DASH",
		"category": "KỸ NĂNG DI CHUYỂN",
		"action": "(Dash / Lướt)",
		"icon": "res://assets/art/2d/Movement/button_dash.png",
		"desc": "Lướt nhanh né tránh trong chớp mắt, phóng xuyên qua các hiểm nguy."
	},
	{
		"key": "double_jump",
		"name": "MONARCH WINGS",
		"category": "KỸ NĂNG DI CHUYỂN",
		"action": "(Jump / Nhảy đôi)",
		"icon": "res://assets/art/2d/Movement/button_jump.png",
		"desc": "Bung đôi cánh tơ lấp lánh cho phép bật nhảy lần hai giữa không trung."
	},
	{
		"key": "shoot",
		"name": "NEEDLE THROW",
		"category": "KỸ NĂNG TẦM XA",
		"action": "(Throw / Ném kim)",
		"icon": "res://assets/art/2d/Movement/button_throw.png",
		"desc": "Phóng phi kim tơ sắc bén về phía trước gây sát thương tầm xa liên hoàn."
	},
	{
		"key": "special_attack",
		"name": "SILK STORM",
		"category": "TUYỆT KỸ TƠ",
		"action": "(Skill / Bão tơ)",
		"icon": "res://assets/art/2d/Movement/button_skill.png",
		"desc": "Giải phóng cơn bão lốc tơ quét sạch kẻ thù trong phạm vi rộng xung quanh."
	}
]

# --- DỮ LIỆU VŨ KHÍ & HUY HIỆU CỐT LÕI (CỘT TRÁI SILKSONG) ---
const WEAPON_CONFIG: Dictionary = {
	"id": "pure_nail",
	"name": "PURE NAIL",
	"category": "VŨ KHÍ TỐI THƯỢNG",
	"icon": "res://assets/art/Inventory & UI/nail_upgrade_0000_pure-nail.png",
	"desc": "Thanh vũ khí tối thượng được rèn giũa từ quặng Pale Ore tinh khiết nhất, có thể chém đứt mọi kết cấu phòng thủ."
}

const CORE_CRESTS: Array[Dictionary] = [
	{
		"id": "city_crest",
		"name": "CITY CREST",
		"category": "HUY HIỆU HOÀNG GIA",
		"icon": "res://assets/art/Inventory & UI/City Crest - false_knight_statue_crest.png",
		"desc": "Khối đá chạm khắc biểu tượng vương triều, dùng để kích hoạt các cơ quan ngầm cổ xưa."
	},
	{
		"id": "defender_crest",
		"name": "DEFENDER'S CREST",
		"category": "BÙA HỘ THÂN",
		"icon": "res://assets/art/Inventory & UI/Charms/Defender_s Crest - charm_dung_def.png",
		"desc": "Mang theo linh hồn của người hộ vệ trung kiên, tỏa ra làn khói bảo vệ xung quanh chủ nhân."
	},
	{
		"id": "hallownest_seal",
		"name": "HALLOWNEST SEAL",
		"category": "CỔ VẬT VƯƠNG TRIỀU",
		"icon": "res://assets/art/Inventory & UI/inv_item__0012_hallownest-seal.png",
		"desc": "Con dấu danh giá của các học giả vương quốc, lưu giữ dấu ấn của thời kỳ thịnh vượng."
	},
	{
		"id": "lumafly_lantern",
		"name": "LUMAFLY LANTERN",
		"category": "CÔNG CỤ THÁM HIỂM",
		"icon": "res://assets/art/Inventory & UI/Lumafly_Lantern0000.png",
		"desc": "Đèn lồng chứa đom đóm Lumafly phát ra ánh sáng lung linh soi tỏ những vực sâu tăm tối nhất."
	}
]

# --- DỮ LIỆU VẬT PHẨM MẶC ĐỊNH (DEFAULT ITEMS FALLBACK) ---
# Túi đồ rỗng mặc định khi bắt đầu game mới
const DEFAULT_ITEMS: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# 1. Nút mở HUD
	if hud_inv_button:
		hud_inv_button.pressed.connect(open_menu)

	# 2. Nút đóng
	if close_button:
		close_button.pressed.connect(close_menu)

	# 3. Điều hướng Tab
	if prev_tab_btn:
		prev_tab_btn.pressed.connect(_prev_tab)
	if next_tab_btn:
		next_tab_btn.pressed.connect(_next_tab)

	if tab_btn_quests:
		tab_btn_quests.pressed.connect(func(): _switch_to_tab(TAB.QUESTS))
	if tab_btn_inventory:
		tab_btn_inventory.pressed.connect(func(): _switch_to_tab(TAB.INVENTORY))
	if tab_btn_journal:
		tab_btn_journal.pressed.connect(func(): _switch_to_tab(TAB.JOURNAL))

	if upgrade_mask_button:
		upgrade_mask_button.pressed.connect(_on_upgrade_mask_pressed)

	# Kiểm tra nếu chạy độc lập như một scene Menu chính
	var is_standalone: bool = (get_tree().current_scene == self or get_parent() == get_tree().root)
	if is_standalone:
		if hud_inv_button:
			hud_inv_button.visible = false
		open_menu()
	else:
		if menu_overlay:
			menu_overlay.visible = false
		if hud_inv_button:
			hud_inv_button.visible = true


func _unhandled_input(event: InputEvent) -> void:
	# Phím tắt mở / đóng (I hoặc Tab)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_I or event.keycode == KEY_TAB:
			get_viewport().set_input_as_handled()
			if is_menu_open:
				close_menu()
			else:
				open_menu()
			return

		if is_menu_open:
			if event.keycode == KEY_ESCAPE:
				get_viewport().set_input_as_handled()
				close_menu()
				return
			elif event.keycode == KEY_Q or event.keycode == KEY_LEFT:
				get_viewport().set_input_as_handled()
				_prev_tab()
				return
			elif event.keycode == KEY_E or event.keycode == KEY_RIGHT:
				get_viewport().set_input_as_handled()
				_next_tab()
				return


# ==============================================================================
# QUẢN LÝ MỞ / ĐÓNG MENU & TẠM DỪNG GAME
# ==============================================================================

func open_menu() -> void:
	if is_menu_open:
		return
	is_menu_open = true
	_play_sfx(click_sfx)

	# Tạm dừng gameplay
	get_tree().paused = true

	# Tạm ẩn cụm TouchControls để không bị chạm nhầm
	_set_touch_controls_visible(false)

	if hud_inv_button:
		hud_inv_button.visible = false

	if menu_overlay:
		menu_overlay.visible = true
		menu_overlay.modulate.a = 0.0
		var tw = create_tween()
		tw.tween_property(menu_overlay, "modulate:a", 1.0, 0.2)

	# Mặc định mở TAB 2 (Túi đồ & Chỉ số)
	_switch_to_tab(TAB.INVENTORY)


func close_menu() -> void:
	if not is_menu_open:
		return
	_play_sfx(click_sfx)
	is_menu_open = false

	# Hiện lại cụm TouchControls khi quay lại game
	_set_touch_controls_visible(true)

	if menu_overlay:
		var tw = create_tween()
		tw.tween_property(menu_overlay, "modulate:a", 0.0, 0.15)
		await tw.finished
		menu_overlay.visible = false

	if hud_inv_button:
		hud_inv_button.visible = true

	# Tiếp tục gameplay nếu không phải là scene Menu gốc
	if get_tree().current_scene != self:
		get_tree().paused = false
	else:
		# Thoát về Main Menu
		get_tree().change_scene_to_file("res://assets/scenes/menu/main_menu.tscn")


func _set_touch_controls_visible(p_visible: bool) -> void:
	var player = _get_player()
	if player:
		var tc = player.get_node_or_null("TouchControls")
		if tc:
			tc.visible = p_visible
			return
	if is_inside_tree() and get_tree():
		var tc_nodes = get_tree().get_nodes_in_group("touch_controls")
		for node in tc_nodes:
			if node is CanvasLayer or node is Control:
				node.visible = p_visible
		var tc = get_tree().root.find_child("TouchControls", true, false)
		if tc:
			tc.visible = p_visible


# ==============================================================================
# ĐIỀU HƯỚNG 3 TAB (< >)
# ==============================================================================

func _prev_tab() -> void:
	var next_idx = int(current_tab) - 1
	if next_idx < 0:
		next_idx = TAB.JOURNAL
	_switch_to_tab(next_idx)


func _next_tab() -> void:
	var next_idx = int(current_tab) + 1
	if next_idx > TAB.JOURNAL:
		next_idx = TAB.QUESTS
	_switch_to_tab(next_idx)


func _switch_to_tab(tab_idx: int) -> void:
	current_tab = tab_idx as TAB
	_play_sfx(page_sfx)

	# 1. Ẩn/Hiện Pages
	if page_quests:
		page_quests.visible = (current_tab == TAB.QUESTS)
	if page_inventory:
		page_inventory.visible = (current_tab == TAB.INVENTORY)
	if page_journal:
		page_journal.visible = (current_tab == TAB.JOURNAL)

	# 2. Cập nhật Visual Style của Header Tab Buttons
	_update_tab_buttons_visual()

	# 3. Nạp lại nội dung cho từng Tab
	match current_tab:
		TAB.QUESTS:
			_refresh_quests_tab()
		TAB.INVENTORY:
			_refresh_inventory_tab()
		TAB.JOURNAL:
			_refresh_journal_tab()


func _update_tab_buttons_visual() -> void:
	var active_color := Color(1.0, 0.95, 0.8, 1.0) # Vàng kim sáng
	var inactive_color := Color(0.66, 0.67, 0.72, 0.8) # Bạc xám mờ

	if tab_btn_quests:
		tab_btn_quests.add_theme_color_override("font_color", active_color if current_tab == TAB.QUESTS else inactive_color)
	if tab_btn_inventory:
		tab_btn_inventory.add_theme_color_override("font_color", active_color if current_tab == TAB.INVENTORY else inactive_color)
	if tab_btn_journal:
		tab_btn_journal.add_theme_color_override("font_color", active_color if current_tab == TAB.JOURNAL else inactive_color)


# ==============================================================================
# TAB 1: NHIỆM VỤ (QUESTS TAB)
# ==============================================================================

func _refresh_quests_tab() -> void:
	if not quest_list_container:
		return

	# Xóa danh sách cũ
	for c in quest_list_container.get_children():
		c.queue_free()

	var quests: Dictionary = {}
	if SaveManager.instance:
		quests = SaveManager.instance.get_quests()

	# Nếu trống, nạp mặc định nhiệm vụ khởi đầu
	if quests.is_empty():
		quests["ancient_whispers"] = {
			"id": "ancient_whispers",
			"title": "Dấu Vết Cổ Xưa (Ancient Whispers)",
			"desc": "Một nguồn năng lượng bí ẩn đang lan tỏa khắp khu phế tích. Hãy khám phá sâu hơn vào lòng đất...",
			"objective": "Khám phá vùng đất chưa biết (0/1)",
			"status": "active",
			"icon_path": "res://assets/art/2d/Achievements/achievement__0014_dream_witch_quest_end.png"
		}

	var first_quest: Dictionary = {}
	for q_id in quests:
		var q_data: Dictionary = quests[q_id]
		if first_quest.is_empty() or q_id == active_selected_quest:
			first_quest = q_data

		var btn = _create_quest_card(q_data)
		quest_list_container.add_child(btn)

	if not first_quest.is_empty():
		_display_quest_detail(first_quest)


func _create_quest_card(q: Dictionary) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 52)
	btn.flat = true
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

	var is_completed: bool = (q.get("status", "") == "completed")
	var status_text = "[HOÀN THÀNH]" if is_completed else "[ĐANG TIẾN HÀNH]"
	var status_col = "#e6c35c" if is_completed else "#5ce6d7"

	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 12)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(40, 40)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_p = q.get("icon_path", "")
	if ResourceLoader.exists(icon_p):
		icon_rect.texture = load(icon_p)
	hbox.add_child(icon_rect)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var lbl_title = Label.new()
	lbl_title.text = q.get("title", "Nhiệm vụ")
	lbl_title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(lbl_title)

	var lbl_status = Label.new()
	lbl_status.text = status_text
	lbl_status.add_theme_font_size_override("font_size", 11)
	lbl_status.modulate = Color.from_string(status_col, Color.WHITE)
	vbox.add_child(lbl_status)

	hbox.add_child(vbox)
	btn.add_child(hbox)

	btn.pressed.connect(func():
		_play_sfx(click_sfx)
		active_selected_quest = q.get("id", "")
		_display_quest_detail(q)
	)

	return btn


func _display_quest_detail(q: Dictionary) -> void:
	if quest_detail_title:
		quest_detail_title.text = q.get("title", "")
	if quest_detail_desc:
		quest_detail_desc.text = q.get("desc", "")
	if quest_detail_objective:
		quest_detail_objective.text = q.get("objective", "")

	var is_completed: bool = (q.get("status", "") == "completed")
	if quest_detail_status:
		quest_detail_status.text = "TRẠNG THÁI: %s" % ("HOÀN THÀNH" if is_completed else "ĐANG THỰC HIỆN")
		quest_detail_status.modulate = Color(1.0, 0.85, 0.4) if is_completed else Color(0.4, 0.9, 0.9)

	if quest_detail_icon:
		var icon_p = q.get("icon_path", "")
		if ResourceLoader.exists(icon_p):
			quest_detail_icon.texture = load(icon_p)


# ==============================================================================
# TAB 2: TÚI ĐỒ & CHỈ SỐ (INVENTORY & STATS TAB)
# ==============================================================================

func _refresh_inventory_tab() -> void:
	# 1. Tiền tệ Geo
	var geo: int = 0
	if SaveManager.instance:
		geo = SaveManager.get_geo()
	if geo_count_label:
		geo_count_label.text = "%d GEO" % geo

	# 2. HP & Silk
	if SaveManager.instance:
		var p_data = SaveManager.instance.save_data.get("player", {})
		if health_count_label:
			var cur_hp = p_data.get("current_health", 5)
			var max_hp = p_data.get("max_health", 5)
			health_count_label.text = "%d / %d MASKS" % [cur_hp, max_hp]
		if silk_count_label:
			var cur_silk = p_data.get("current_silk", 4)
			var max_silk = p_data.get("max_silk", 4)
			silk_count_label.text = "%d / %d SPOOLS" % [cur_silk, max_silk]

	# 3. Cột trái: Cấu hình vũ khí và huy hiệu cốt lõi
	_setup_left_column()

	# 4. Cột giữa: Kỹ năng từ Movement (Silksong Touch Icons)
	_refresh_abilities()

	# 5. Cột giữa: Lưới vật phẩm thu thập (Items Grid)
	_refresh_items_grid()


func _setup_left_column() -> void:
	# 1. Cấu hình Vũ khí (Weapon Slot)
	if weapon_slot:
		var w_icon: TextureRect = weapon_slot.find_child("Icon", true, false)
		if w_icon and ResourceLoader.exists(WEAPON_CONFIG["icon"]):
			w_icon.texture = load(WEAPON_CONFIG["icon"])
		for conn in weapon_slot.pressed.get_connections():
			weapon_slot.pressed.disconnect(conn["callable"])
		weapon_slot.pressed.connect(func():
			_play_sfx(click_sfx)
			_display_item_preview(WEAPON_CONFIG)
			_highlight_selected_control(weapon_slot)
		)

	# 2. Cấu hình các Huy hiệu cốt lõi (Crests Container)
	if crests_container:
		for i in range(CORE_CRESTS.size()):
			var crest_data = CORE_CRESTS[i]
			var btn: Button = crests_container.get_node_or_null("Crest%d" % (i + 1))
			if not btn:
				btn = crests_container.get_node_or_null(crest_data["id"])
			if btn:
				var c_icon: TextureRect = btn.find_child("Icon", true, false)
				if c_icon and ResourceLoader.exists(crest_data["icon"]):
					c_icon.texture = load(crest_data["icon"])
				for conn in btn.pressed.get_connections():
					btn.pressed.disconnect(conn["callable"])
				btn.pressed.connect(func():
					_play_sfx(click_sfx)
					_display_item_preview(crest_data)
					_highlight_selected_control(btn)
				)


func _refresh_abilities() -> void:
	if not abilities_container:
		return

	# Lấy danh sách kỹ năng đã mở khóa từ SaveManager hoặc Player
	var skills_dict: Dictionary = {}
	if SaveManager.instance:
		skills_dict = SaveManager.instance.save_data.get("player", {}).get("skills", {})

	for ab in ABILITIES_CONFIG:
		var btn: Button = abilities_container.get_node_or_null(ab["key"])
		if not btn:
			continue

		var is_unlocked: bool = skills_dict.get(ab["key"], false)
		var player = _get_player()
		if player:
			match ab["key"]:
				"attack": is_unlocked = true
				"dash": is_unlocked = player.get("unlock_dash") if "unlock_dash" in player else is_unlocked
				"double_jump": is_unlocked = player.get("unlock_double_jump") if "unlock_double_jump" in player else is_unlocked
				"shoot": is_unlocked = player.get("unlock_shoot") if "unlock_shoot" in player else is_unlocked
				"special_attack": is_unlocked = player.get("unlock_special_attack") if "unlock_special_attack" in player else is_unlocked

		var icon: TextureRect = btn.find_child("Icon", true, false)
		if icon:
			if ResourceLoader.exists(ab["icon"]):
				icon.texture = load(ab["icon"])
			if is_unlocked:
				icon.modulate = Color(1.0, 1.0, 1.0, 1.0)
			else:
				# Silhouette mờ tối khi chưa mở khóa
				icon.modulate = Color(0.2, 0.22, 0.28, 0.4)

		# Bấm vào kỹ năng để xem thông tin ở cột phải và hiện 4 góc viền bạc
		for conn in btn.pressed.get_connections():
			btn.pressed.disconnect(conn["callable"])
		btn.pressed.connect(func():
			_play_sfx(click_sfx)
			var preview_data = {
				"name": ab["name"],
				"category": ab["category"],
				"desc": "%s\n%s" % [ab["action"], ab["desc"] if is_unlocked else "Chưa mở khóa kỹ năng này."],
				"icon": ab["icon"]
			}
			_display_item_preview(preview_data)
			_highlight_selected_control(btn)
		)


func _normalize_item_data(raw_item) -> Dictionary:
	if raw_item is Dictionary:
		return raw_item
	elif raw_item is String:
		var def: Dictionary = SaveManager.get_item_definition(raw_item)
		if not def.is_empty():
			return def
		for def_it in DEFAULT_ITEMS:
			if def_it.get("id", "") == raw_item:
				return def_it
		return {
			"id": raw_item,
			"name": raw_item.capitalize(),
			"desc": "Vật phẩm thu thập trong hành trình.",
			"icon": "res://assets/art/Inventory & UI/inv_item_city_key.png",
			"category": "VẬT PHẨM"
		}
	return {}


func _refresh_items_grid() -> void:
	if not items_container:
		return

	for c in items_container.get_children():
		c.queue_free()

	var raw_items: Array = []
	if SaveManager.instance:
		raw_items = SaveManager.instance.get_inventory_items()

	# Khi túi đồ trống (New Game hoặc chưa mua/nhặt gì), xóa preview và không sinh ô mẫu
	if raw_items.is_empty():
		if selection_brackets:
			selection_brackets.visible = false
		if mask_upgrade_container:
			mask_upgrade_container.visible = false
		if item_preview_name:
			item_preview_name.text = "TÚI ĐỒ TRỐNG"
		if item_preview_category:
			item_preview_category.text = "CHƯA CÓ VẬT PHẨM"
		if item_preview_desc:
			item_preview_desc.text = "Bạn chưa thu thập vật phẩm hoặc cổ vật nào. Hãy khám phá thế giới hoặc mua hàng từ các thương gia."
		if item_preview_icon:
			item_preview_icon.texture = null
		return

	var first_item: Dictionary = {}
	var first_btn: Control = null
	for raw_it in raw_items:
		var it: Dictionary = _normalize_item_data(raw_it)
		if it.is_empty():
			continue

		if first_item.is_empty() or it.get("id", "") == active_selected_item:
			first_item = it

		var slot_btn = _create_item_slot(it)
		items_container.add_child(slot_btn)
		if first_btn == null or it.get("id", "") == active_selected_item:
			first_btn = slot_btn

	if not first_item.is_empty():
		_display_item_preview(first_item)
		if first_btn:
			get_tree().create_timer(0.02).timeout.connect(func():
				if is_instance_valid(first_btn):
					_highlight_selected_control(first_btn)
			)


func _create_item_slot(it: Dictionary) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(52, 52)
	btn.flat = true
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var icon = TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_p = it.get("icon", "")
	if ResourceLoader.exists(icon_p):
		icon.texture = load(icon_p)
	btn.add_child(icon)

	# Hiển thị số lượng: Mảnh mặt nạ hiển thị X/4, vật phẩm khác hiển thị xN
	var item_id = it.get("id", "")
	var count: int = int(it.get("count", 1))
	if item_id == "mask_shard":
		var shards = 0
		if SaveManager.instance:
			shards = SaveManager.instance.get_mask_shards()
		else:
			shards = count
		var badge = Label.new()
		badge.text = "%d/4" % shards
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		badge.set_anchors_preset(Control.PRESET_FULL_RECT)
		badge.add_theme_font_size_override("font_size", 10)
		badge.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45, 1.0))
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(badge)
	elif count > 1:
		var badge = Label.new()
		badge.text = "x%d" % count
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		badge.set_anchors_preset(Control.PRESET_FULL_RECT)
		badge.add_theme_font_size_override("font_size", 11)
		badge.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7, 1.0))
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(badge)

	btn.pressed.connect(func():
		_play_sfx(click_sfx)
		active_selected_item = it.get("id", "")
		_display_item_preview(it)
		_highlight_selected_control(btn)
	)
	return btn


func _display_item_preview(it: Dictionary) -> void:
	var item_id: String = it.get("id", "")
	var count: int = int(it.get("count", 1))

	# 1. Tên vật phẩm
	if item_preview_name:
		var name_str = it.get("name", "").to_upper()
		if count > 1 and item_id != "mask_shard":
			name_str += " (x%d)" % count
		item_preview_name.text = name_str

	# 2. Phân loại
	if item_preview_category:
		item_preview_category.text = "PHÂN LOẠI: %s" % it.get("category", "VẬT PHẨM").to_upper()

	# 3. Mô tả chi tiết & Tiến độ Mảnh mặt nạ
	var desc_str = it.get("desc", "")
	if item_id == "mask_shard":
		var shards = 0
		if SaveManager.instance:
			shards = SaveManager.instance.get_mask_shards()
		else:
			shards = count
		desc_str = "Mảnh vỡ cổ vật tích tụ sinh mệnh.\n\nTiến độ: Mảnh mặt nạ: %d / 4\n\nThu thập đủ 4 mảnh để hợp nhất tăng vĩnh viễn 1 Mask sinh lực tối đa." % shards
		
		if mask_upgrade_container:
			mask_upgrade_container.visible = true
		if mask_shard_progress:
			mask_shard_progress.text = "Mảnh mặt nạ: %d / 4" % shards
		if upgrade_mask_button:
			upgrade_mask_button.visible = (shards >= 4)
			upgrade_mask_button.disabled = (shards < 4)
			upgrade_mask_button.text = "✨ HỢP NHẤT MẶT NẠ (+1 MASK)"
	else:
		if mask_upgrade_container:
			mask_upgrade_container.visible = false

	if item_preview_desc:
		item_preview_desc.text = desc_str

	# 4. Icon
	if item_preview_icon:
		var icon_p = it.get("icon", "")
		if ResourceLoader.exists(icon_p):
			item_preview_icon.texture = load(icon_p)
		else:
			item_preview_icon.texture = null


func _on_upgrade_mask_pressed() -> void:
	_play_sfx(click_sfx)
	if SaveManager.instance and SaveManager.instance.can_upgrade_mask():
		var success = SaveManager.instance.upgrade_mask()
		if success:
			_play_sfx(page_sfx)
			_refresh_inventory_tab()




func _highlight_selected_control(target_ctrl: Control) -> void:
	if not selection_brackets or not target_ctrl or not target_ctrl.is_inside_tree():
		return
	selection_brackets.visible = true
	if not page_inventory or not page_inventory.is_inside_tree():
		return

	var target_pos = (target_ctrl.global_position - page_inventory.global_position) + ((target_ctrl.size - selection_brackets.size) * 0.5)

	var tw = create_tween().set_parallel(true)
	tw.tween_property(selection_brackets, "position", target_pos, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	selection_brackets.scale = Vector2(1.2, 1.2)
	tw.tween_property(selection_brackets, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ==============================================================================
# TAB 3: SỔ TAY THỢ SĂN (HUNTER'S JOURNAL TAB)
# ==============================================================================

func _refresh_journal_tab() -> void:
	if not enemy_list_container:
		return

	for c in enemy_list_container.get_children():
		c.queue_free()

	var journal_data: Dictionary = {}
	if SaveManager.instance:
		journal_data = SaveManager.instance.get_hunter_journal()

	var total_encountered: int = 0
	var first_entry: Dictionary = {}

	for entry in BESTIARY_DATABASE:
		var e_id: String = entry["id"]
		var kills: int = int(journal_data.get(e_id, 0))
		if kills > 0:
			total_encountered += 1

		if first_entry.is_empty() or e_id == active_selected_enemy:
			first_entry = entry

		var row_btn = _create_enemy_journal_row(entry, kills)
		enemy_list_container.add_child(row_btn)

	if journal_summary_label:
		journal_summary_label.text = "SỔ TAY QUÁI VẬT — ĐÃ KHÁM PHÁ: %d / %d" % [total_encountered, BESTIARY_DATABASE.size()]

	if not first_entry.is_empty():
		var first_kills = int(journal_data.get(first_entry["id"], 0))
		_display_enemy_showcase(first_entry, first_kills)


func _create_enemy_journal_row(entry: Dictionary, kills: int) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 48)
	btn.flat = true
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

	var is_encountered: bool = (kills > 0)
	var req_kills: int = entry["required_kills"]
	var is_completed: bool = (kills >= req_kills)

	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 12)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(36, 36)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	if is_encountered:
		if ResourceLoader.exists(entry["portrait"]):
			icon_rect.texture = load(entry["portrait"])
	else:
		# Silhouette đen mờ khi chưa gặp
		if ResourceLoader.exists(entry["portrait"]):
			icon_rect.texture = load(entry["portrait"])
			icon_rect.modulate = Color(0.1, 0.1, 0.15, 0.4)

	hbox.add_child(icon_rect)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var lbl_name = Label.new()
	lbl_name.text = entry["name"] if is_encountered else "???"
	lbl_name.add_theme_font_size_override("font_size", 13)
	if not is_encountered:
		lbl_name.modulate = Color(0.5, 0.5, 0.55)
	vbox.add_child(lbl_name)

	var lbl_kills = Label.new()
	if not is_encountered:
		lbl_kills.text = "Chưa ghi chép"
		lbl_kills.modulate = Color(0.4, 0.4, 0.45)
	elif is_completed:
		lbl_kills.text = "ĐÃ HOÀN TẤT: %d / %d" % [kills, req_kills]
		lbl_kills.modulate = Color(1.0, 0.85, 0.4)
	else:
		lbl_kills.text = "Đã hạ: %d / %d" % [kills, req_kills]
		lbl_kills.modulate = Color(0.7, 0.8, 0.9)
	lbl_kills.add_theme_font_size_override("font_size", 10)
	vbox.add_child(lbl_kills)

	hbox.add_child(vbox)
	btn.add_child(hbox)

	btn.pressed.connect(func():
		_play_sfx(click_sfx)
		active_selected_enemy = entry["id"]
		var cur_k = 0
		if SaveManager.instance:
			cur_k = SaveManager.instance.get_enemy_kills(entry["id"])
		_display_enemy_showcase(entry, cur_k)
	)

	return btn


func _display_enemy_showcase(entry: Dictionary, kills: int) -> void:
	var is_encountered: bool = (kills > 0)
	var req_kills: int = entry["required_kills"]
	var is_completed: bool = (kills >= req_kills)

	# 1. Ảnh Artwork lớn
	if enemy_showcase_art:
		if ResourceLoader.exists(entry["full_art"]):
			enemy_showcase_art.texture = load(entry["full_art"])
		if is_encountered:
			enemy_showcase_art.modulate = Color.WHITE
		else:
			enemy_showcase_art.modulate = Color(0.08, 0.08, 0.12, 0.4)

	# 2. Tên Quái
	if enemy_showcase_name:
		enemy_showcase_name.text = entry["name"] if is_encountered else "???"

	# 3. Tiến độ Kill Tracker
	if enemy_showcase_kills:
		if not is_encountered:
			enemy_showcase_kills.text = "TIẾN ĐỘ THỢ SĂN: CHƯA GHI CHÉP"
			enemy_showcase_kills.modulate = Color(0.5, 0.5, 0.55)
		elif is_completed:
			enemy_showcase_kills.text = "TIẾN ĐỘ THỢ SĂN: %d / %d (HOÀN TẤT)" % [kills, req_kills]
			enemy_showcase_kills.modulate = Color(1.0, 0.85, 0.4)
		else:
			enemy_showcase_kills.text = "TIẾN ĐỘ THỢ SĂN: %d / %d" % [kills, req_kills]
			enemy_showcase_kills.modulate = Color(0.5, 0.9, 0.9)

	# 4. Mô tả sơ khởi
	if enemy_showcase_desc:
		if is_encountered:
			enemy_showcase_desc.text = entry["short_desc"]
		else:
			enemy_showcase_desc.text = "Chưa có dữ liệu. Hãy đánh bại sinh vật này trên hành trình để mở khóa thông tin."

	# 5. Ghi chép của Thợ săn (Hunter's Lore)
	if enemy_hunter_lore_box and enemy_hunter_lore_text:
		if not is_encountered:
			enemy_hunter_lore_box.visible = false
		elif is_completed:
			enemy_hunter_lore_box.visible = true
			enemy_hunter_lore_text.text = "\"%s\"" % entry["hunter_lore"]
			enemy_hunter_lore_text.modulate = Color(0.9, 0.9, 0.95)
		else:
			enemy_hunter_lore_box.visible = true
			var remaining = req_kills - kills
			enemy_hunter_lore_text.text = "[Tiêu diệt thêm %d con để mở khóa ghi chép thợ săn]" % remaining
			enemy_hunter_lore_text.modulate = Color(0.6, 0.65, 0.75, 0.7)


# ==============================================================================
# TIỆN ÍCH HỖ TRỢ
# ==============================================================================

func _get_player() -> Node:
	if is_inside_tree() and get_tree():
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			return players[0]
	return null


func _play_sfx(stream: AudioStream) -> void:
	if sfx_player and stream:
		sfx_player.stream = stream
		sfx_player.play()
