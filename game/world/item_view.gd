class_name ItemView
extends RefCounted
## Draws what lies in the world (M2b): one Sprite2D per gatherable (VEGETATION layer, its world
## picture) and one per drop (its inventory icon), under the y-sorted Entities node so characters
## walk in front of and behind them by their feet. The node sits on the bottom edge of the tile (the
## sprite fills the 16x16 tile above it), so a character whose feet are inside that tile is drawn
## behind the item and one standing south of it in front. Sprites use the actors' light layer (the
## hard-edged altar light, like characters: small objects, no dither checkerboard).
## GameWorld rebuilds it on load_data and updates the one tile or drop an edit touches.

var parent: Node2D
var data: WorldData
## Sprites by tile (gatherables) and by drop id.
var plants: Dictionary[Vector2i, Sprite2D] = {}
var drops: Dictionary[int, Sprite2D] = {}

static var _world_pictures: Dictionary[StringName, Texture2D] = {}


func _init(p_parent: Node2D) -> void:
	parent = p_parent


## Every sprite for `p_data` (old ones removed).
func setup(p_data: WorldData) -> void:
	clear()
	data = p_data
	for c: Vector2i in WorldItems.gatherable_cells(data):
		update_cell(c)
	for id: int in data.drop_ids():
		update_drop(id)


func clear() -> void:
	for sprite: Sprite2D in plants.values():
		_remove(sprite)
	for sprite: Sprite2D in drops.values():
		_remove(sprite)
	plants.clear()
	drops.clear()


## Shows what the data has on tile `c` now.
func update_cell(c: Vector2i) -> void:
	var id: StringName = WorldItems.gatherable_at(data, c)
	if plants.has(c):
		_remove(plants[c])
		plants.erase(c)
	if id.is_empty():
		return
	var s: Sprite2D = _sprite(world_picture(id), StringName("Gather_%d_%d" % [c.x, c.y]))
	s.position = Vector2(c.x * Config.TILE + Config.TILE / 2, (c.y + 1) * Config.TILE)
	plants[c] = s


## Shows drop `id` as the data has it now (gone if it is not there).
func update_drop(id: int) -> void:
	if drops.has(id):
		_remove(drops[id])
		drops.erase(id)
	if not data.drops.has(id):
		return
	var d: WorldData.Drop = data.drops[id]
	var s: Sprite2D = _sprite(ItemIcons.texture_for(d.item), StringName("Drop_%d" % id))
	s.position = Vector2(d.pos.x, d.pos.y + Config.TILE / 2)
	drops[id] = s


## How a gatherable looks in the world (ItemDef.world_path).
static func world_picture(id: StringName) -> Texture2D:
	if not _world_pictures.has(id):
		var def: ItemDB.ItemDef = ItemDB.get_def(id)
		_world_pictures[id] = load(def.world_path) as Texture2D if def != null and not def.world_path.is_empty() else null
	return _world_pictures[id]


func _sprite(tex: Texture2D, node_name: StringName) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	s.name = node_name
	s.texture = tex
	s.centered = false
	s.offset = Vector2(-Config.TILE / 2, -Config.TILE)
	s.light_mask = Config.LIGHT_LAYER_ACTORS
	parent.add_child(s)
	return s


func _remove(s: Sprite2D) -> void:
	if is_instance_valid(s):
		s.get_parent().remove_child(s)
		s.free()


## Sprites against the data: gatherables and drops shown, and how many disagree (missing, extra, wrong
## picture or place). 0 mismatches = the view shows the data.
func verify() -> Dictionary[String, int]:
	var bad: int = 0
	var cells: Array[Vector2i] = WorldItems.gatherable_cells(data)
	for c: Vector2i in cells:
		var s: Sprite2D = plants.get(c, null)
		if s == null or not is_instance_valid(s) or s.texture != world_picture(WorldItems.gatherable_at(data, c)) \
				or s.position != Vector2(c.x * Config.TILE + Config.TILE / 2, (c.y + 1) * Config.TILE):
			bad += 1
	bad += maxi(plants.size() - cells.size(), 0)
	for id: int in data.drops:
		var d: WorldData.Drop = data.drops[id]
		var s: Sprite2D = drops.get(id, null)
		if s == null or not is_instance_valid(s) or s.texture != ItemIcons.texture_for(d.item) \
				or s.position != Vector2(d.pos.x, d.pos.y + Config.TILE / 2):
			bad += 1
	bad += maxi(drops.size() - data.drops.size(), 0)
	return {"gatherables": plants.size(), "drops": drops.size(), "mismatches": bad}
