extends RefCounted
class_name Teams

enum Team { CT, T }

const CT_COLOR := Color(0.30, 0.55, 1.0)   # blue
const T_COLOR := Color(1.0, 0.65, 0.15)    # orange/yellow

static func color_for(team: int) -> Color:
	return CT_COLOR if team == Team.CT else T_COLOR

static func group_for(team: int) -> String:
	return "ct" if team == Team.CT else "t"

static func enemy_group_for(team: int) -> String:
	return "t" if team == Team.CT else "ct"

static func name_for(team: int) -> String:
	return "CT" if team == Team.CT else "T"
