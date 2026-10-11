class_name EnemyHurtbox
extends Area2D

## Chuyển tiếp sát thương lên Node kẻ địch cha để đảm bảo hỗ trợ Player Attack & Nail Pogo 100%
func take_damage(amount: int = 1, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	var enemy = get_parent()
	if enemy and enemy.has_method("take_damage"):
		enemy.take_damage(amount, knockback_dir)
