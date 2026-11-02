class_name Hitbox
extends Area2D
## Something that deals damage on contact: Patch's shears, an enemy body, a hazard.
## Hurtboxes look for Hitboxes; a Hitbox does nothing on its own.

## Emitted (by the Hurtbox) when this hitbox's damage actually lands on something.
signal landed(target: Node)

@export var damage := 1
@export var knockback := 520.0
## Inactive hitboxes are ignored (e.g. Patch's swipe between attacks).
@export var active := true
## How much it wears down the target's Hold (see HoldComponent).
@export var hold_damage := 1
## Sends light enemies up into the air instead of back (Patch's launcher).
@export var launch := false
## Enemy attacks: a red-glow attack can't be guarded or parried, only dodged.
@export var unblockable := false
