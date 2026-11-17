class_name ItemIcons
extends RefCounted
## One shared icon lookup so the hotbar, the inventory screen and dropped-on-the-ground
## pickups (Pickup.spawn) all show the same picture for the same item id. Add a new item
## here once and everything that displays items picks it up automatically.

const ICONS := {
	"hoe": preload("res://assets/items/hoe.png"),
	"water": preload("res://assets/items/watering_can.png"),
	"egg": preload("res://assets/items/egg.png"),
	"chili": preload("res://assets/items/chili.png"),
	"rice": preload("res://assets/items/rice.png"),
	"corn": preload("res://assets/items/corn.png"),
	"tomato": preload("res://assets/items/tomato.png"),
	"eggplant": preload("res://assets/items/eggplant.png"),
	"onion": preload("res://assets/items/onion.png"),
	"roselle": preload("res://assets/items/roselle.png"),
}

const SHADOW := preload("res://assets/items/item_shadow.png")
const HINT := preload("res://assets/items/key_hint_e.png")


## "chili_seeds" shows the chili icon, not a literal "seeds" icon - same rule the
## hotbar already used, now shared with the inventory screen and ground pickups.
static func get_icon(item_id: String) -> Texture2D:
	var id := item_id
	if id.ends_with("_seeds"):
		id = id.substr(0, id.length() - "_seeds".length())
	return ICONS.get(id)
