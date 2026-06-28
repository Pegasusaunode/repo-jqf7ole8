extends Node3D
## Builds the arena, spawns a 5v5 match (you + 4 CT bots vs 5 T bots),
## and runs simple round logic.

const TEAM_SIZE := 5

var hud: HUD
var spawns := {}
var fighters: Array[Fighter] = []
var player: Player

var ct_score := 0
var t_score := 0
var intermission := 0.0
var round_active := true

const BOT_NAMES := ["Volk", "Dráp", "Nyx", "Echo", "Rook", "Saint", "Kilo", "Zane", "Mira"]


func _ready() -> void:
	randomize()
	spawns = MapBuilder.build(self)

	hud = HUD.new()
	add_child(hud)

	_spawn_teams()
	hud.set_score(ct_score, t_score)
	_update_alive()


func _spawn_teams() -> void:
	var name_pool := BOT_NAMES.duplicate()
	name_pool.shuffle()

	# CT team: index 0 is the human player.
	for i in range(TEAM_SIZE):
		if i == 0:
			player = Player.new()
			player.team = Teams.Team.CT
			add_child(player)
			player.add_to_group("ct")
			player.add_to_group("fighters")
			player.hud = hud
			_place(player, "ct", i, spawns.ct_yaw)
			_connect(player)
		else:
			var b := _make_bot(Teams.Team.CT, name_pool.pop_back())
			_place(b, "ct", i, spawns.ct_yaw)

	# T team: all bots.
	for i in range(TEAM_SIZE):
		var b := _make_bot(Teams.Team.T, name_pool.pop_back())
		_place(b, "t", i, spawns.t_yaw)


func _make_bot(team: int, nm: String) -> Bot:
	var b := Bot.new()
	b.team = team
	add_child(b)
	b.add_to_group(Teams.group_for(team))
	b.add_to_group("fighters")
	b.display_name = nm if nm else "Bot"
	b.skill = randf_range(0.55, 0.9)
	b.current_index = 0 if randf() > 0.5 else 1   # scout or deagle
	_connect(b)
	return b


func _place(f: Fighter, team_key: String, idx: int, yaw: float) -> void:
	var points: Array = spawns[team_key]
	var pos: Vector3 = points[idx % points.size()]
	f.respawn(pos, yaw)


func _connect(f: Fighter) -> void:
	fighters.append(f)
	f.died.connect(_on_died)


func _on_died(victim: Fighter, _attacker: Fighter) -> void:
	if victim == player:
		hud.flash_eliminated()
	_update_alive()
	if not round_active:
		return
	var ct_alive := _alive_count(Teams.Team.CT)
	var t_alive := _alive_count(Teams.Team.T)
	if ct_alive == 0 or t_alive == 0:
		_end_round(t_alive > 0)


func _alive_count(team: int) -> int:
	var n := 0
	for f in fighters:
		if is_instance_valid(f) and f.team == team and f.alive:
			n += 1
	return n


func _update_alive() -> void:
	hud.set_alive(_alive_count(Teams.Team.CT), _alive_count(Teams.Team.T))


func _end_round(t_won: bool) -> void:
	round_active = false
	if t_won:
		t_score += 1
	else:
		ct_score += 1
	hud.set_score(ct_score, t_score)
	var winner := "T" if t_won else "CT"
	hud.set_message("%s win the round!" % winner)
	intermission = 3.0


func _process(delta: float) -> void:
	if not round_active:
		intermission -= delta
		if intermission <= 0.0:
			_reset_round()
	if Input.is_action_just_pressed("restart"):
		_reset_round()


func _reset_round() -> void:
	var ct_i := 0
	var t_i := 0
	for f in fighters:
		if not is_instance_valid(f):
			continue
		if f.team == Teams.Team.CT:
			_place(f, "ct", ct_i, spawns.ct_yaw)
			ct_i += 1
		else:
			_place(f, "t", t_i, spawns.t_yaw)
			t_i += 1
		if f is Bot:
			f.current_index = 0 if randf() > 0.5 else 1
	round_active = true
	hud.set_message("")
	_update_alive()
