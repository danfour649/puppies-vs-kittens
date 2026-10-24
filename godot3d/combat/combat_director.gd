class_name CombatDirector
extends RefCounted
## COMBAT DIRECTOR — the paw-sweep glue between the cats and the
## enemy base. main.gd calls check_paw_hits() from its paw_swiped
## handler (the same one that catches mice), so the PLAYER cat's
## strikes land on enemies exactly the way they land on mice, and
## the duo system keeps it pointed at whoever is being played.
##
## A hit lands when an enemy is within the paw arc of the cat's
## paw point: the base arc while standing, ~1.6x while pouncing.

const PAW_ARC := 0.55
const POUNCE_ARC := 0.88
const MAX_DY := 1.3 # don't hit through floors/shelves


static func check_paw_hits(tree: SceneTree, cat: PvKCat) -> int:
	if tree == null or cat == null:
		return 0
	var arc := POUNCE_ARC if cat.is_pouncing() else PAW_ARC
	var pp := cat.paw_point()
	var prof := CombatData.paw_profile(cat)
	var hits := 0
	for e: Variant in tree.get_nodes_in_group("enemies"):
		var enemy := e as PvKEnemy
		if enemy == null or not enemy.is_alive():
			continue
		if absf(enemy.global_position.y - cat.global_position.y) > MAX_DY:
			continue
		var d := Vector2(enemy.global_position.x - pp.x, enemy.global_position.z - pp.z).length()
		if d <= arc:
			if enemy.take_hit(float(prof.get("damage", 10.0)), cat.global_position):
				hits += 1
	return hits
