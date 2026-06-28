extends RefCounted
class_name Arsenal
## Factory for the two weapons used in the game.

const WEAPON_DIR := "res://assets/weapons/"

static func make_scout() -> WeaponData:
	var w := WeaponData.new()
	w.name = "Scout (SSG 08)"
	w.model_path = WEAPON_DIR + "blaster-q.glb"
	w.scope_model_path = WEAPON_DIR + "scope-large-a.glb"
	w.damage = 88.0
	w.headshot_multiplier = 3.0
	w.fire_rate = 1.2
	w.max_range = 400.0
	w.magazine = 10
	w.reserve_ammo = 90
	w.reload_time = 2.3
	w.is_sniper = true
	w.scope_fov = 20.0
	w.base_spread = 0.05
	w.move_spread = 8.0
	w.recoil = 3.5
	w.bot_accuracy = 0.8
	return w


static func make_deagle() -> WeaponData:
	var w := WeaponData.new()
	w.name = "Desert Eagle"
	w.model_path = WEAPON_DIR + "blaster-a.glb"
	w.damage = 53.0
	w.headshot_multiplier = 3.0
	w.fire_rate = 4.0
	w.max_range = 250.0
	w.magazine = 7
	w.reserve_ammo = 35
	w.reload_time = 2.2
	w.is_sniper = false
	w.base_spread = 0.8
	w.move_spread = 5.0
	w.recoil = 2.2
	w.bot_accuracy = 0.7
	return w


static func default_loadout() -> Array[WeaponData]:
	var arr: Array[WeaponData] = []
	arr.append(make_scout())
	arr.append(make_deagle())
	return arr
