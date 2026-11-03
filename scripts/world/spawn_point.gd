class_name SpawnPoint
extends Marker2D
## A named place Patch can arrive at on a text-map page (a door's or exit's
## `target_spawn`). Give it its name through the map's entity_props ("name").


func _init() -> void:
	add_to_group(&"spawn_points")
