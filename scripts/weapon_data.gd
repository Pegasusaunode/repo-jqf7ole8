extends Resource
class_name WeaponData
## Stats for a single weapon. Instances are built in Arsenal.gd.

@export var name: String = "Weapon"
@export var model_path: String = ""          # GLB viewmodel / worldmodel
@export var scope_model_path: String = ""    # optional attachment
@export var damage: float = 30.0
@export var headshot_multiplier: float = 4.0
@export var fire_rate: float = 5.0           # shots per second
@export var max_range: float = 200.0
@export var magazine: int = 12
@export var reserve_ammo: int = 90
@export var reload_time: float = 2.0
@export var is_sniper: bool = false
@export var scope_fov: float = 25.0          # fov when scoped (sniper)
@export var base_spread: float = 0.5         # degrees, standing still
@export var move_spread: float = 4.0         # extra degrees when moving
@export var recoil: float = 1.2              # degrees of vertical camera kick
@export var bot_accuracy: float = 0.85       # 0..1, used by AI
