class_name Hitbox
extends Area2D
## Something that deals damage on contact: Patch's shears, an enemy body, a hazard.
## Hurtboxes look for Hitboxes; a Hitbox does nothing on its own.

## Emitted (by the Hurtbox) when this hitbox's damage actually lands on something.
signal landed(target: Node)

## How an ordinary enemy reacts to this hit (see HitReaction). Each of Patch's moves
## lands differently: light cuts make it flinch, a heavy makes it reel, the thrust that
## ends a combo sends it flying into whatever is behind it, the launcher pops it up and
## the Plunge and slam crush it flat.
enum Reaction { FLINCH, REEL, LAUNCH, SEND, CRUSH }

@export var damage := 1
@export var knockback := 520.0
## Inactive hitboxes are ignored (e.g. Patch's swipe between attacks).
@export var active := true
## How much it wears down the target's Hold (see HoldComponent).
@export var hold_damage := 1.0
## Sends light enemies up into the air instead of back (Patch's launcher).
@export var launch := false
## Enemy attacks: a red-glow attack can't be guarded or parried, only dodged.
@export var unblockable := false
@export var reaction := Reaction.FLINCH
## Patch's cuts: which form the shears were in (ShearForms.Form), or -1. A form an
## enemy is weak to hits harder (Bestiary).
@export var form := -1
## The Beak snips through guards: a Tack Knight's shield doesn't turn it.
@export var pierces_guard := false
