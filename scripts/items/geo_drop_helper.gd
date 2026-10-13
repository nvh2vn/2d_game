class_name GeoDropHelper
extends RefCounted

enum EnemyTier {
	NORMAL,   # Quái thường (bò, bay nhỏ): 1 - 3 đồng 1Geo
	ELITE,    # Quái tinh anh / quái to: 3 - 6 đồng (pha trộn 1Geo và 5Geo)
	BOSS,     # Boss / Trùm cuối: 10 - 20 đồng (pha trộn 5Geo và 25Geo cực nhiều)
	CUSTOM    # Tùy chỉnh tự do trong Inspector
}

static var coin_scene: PackedScene = preload("res://scenes/prefabs/items/geo_coin.tscn")

## Hàm thả tiền Geo theo Tier quái vật
static func drop_from_tier(pos: Vector2, parent_node: Node, tier: EnemyTier) -> void:
	match tier:
		EnemyTier.NORMAL:
			drop_geo(pos, parent_node, 1, 3, 0.0, 0.0)
		EnemyTier.ELITE:
			drop_geo(pos, parent_node, 3, 6, 0.35, 0.08)
		EnemyTier.BOSS:
			drop_geo(pos, parent_node, 10, 20, 0.50, 0.30)
		EnemyTier.CUSTOM:
			drop_geo(pos, parent_node, 1, 3, 0.0, 0.0)


## Hàm thả tiền Geo tổng quát với tỷ lệ tùy biến
static func drop_geo(pos: Vector2, parent_node: Node, min_coins: int = 1, max_coins: int = 3, chance_5: float = 0.0, chance_25: float = 0.0) -> void:
	if coin_scene == null or parent_node == null:
		return
		
	var count = randi_range(min_coins, max_coins)
	for i in range(count):
		var coin = coin_scene.instantiate() as GeoCoin
		if coin == null:
			continue
			
		# Xác định mệnh giá xu dựa trên tỷ lệ
		var r = randf()
		if r < chance_25:
			coin.set_value(25)
		elif r < (chance_25 + chance_5):
			coin.set_value(5)
		else:
			coin.set_value(1)
			
		coin.global_position = pos + Vector2(randf_range(-8.0, 8.0), randf_range(-12.0, -4.0))
		# Vận tốc nảy hình nan quạt
		var angle_frac = randf()
		var vx = lerpf(-140.0, 140.0, angle_frac) + randf_range(-20.0, 20.0)
		var vy = randf_range(-280.0, -140.0)
		coin.velocity = Vector2(vx, vy)
		
		parent_node.call_deferred("add_child", coin)
