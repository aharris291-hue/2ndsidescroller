class_name Hitbox
extends Area2D
## Something that deals damage on contact: Patch's Crease Swipe, an enemy body, a hazard.
## Hurtboxes look for Hitboxes; a Hitbox does nothing on its own.

@export var damage := 1
@export var knockback := 520.0
## Inactive hitboxes are ignored (e.g. Patch's swipe between attacks).
@export var active := true
