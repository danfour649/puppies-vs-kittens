extends Node
## Headless tests for the shared creature brain.
## Run: godot --headless --path godot3d res://ai/tests_ai.tscn

var _pass := 0
var _fail := 0


func check(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  ok - ", label)
	else:
		_fail += 1
		print("  FAIL - ", label)


func _ready() -> void:
	_run()


func _ctx(extra: Dictionary = {}) -> Dictionary:
	var ctx := {
		"pos": Vector3.ZERO,
		"forward": Vector3(0, 0, -1),
		"hour": 23.0,
		"has_cat": false,
		"home": Vector3.ZERO,
		"sounds": [],
		"wall_pull": Vector3.ZERO,
		"scent": 0.0,
	}
	for k: Variant in extra.keys():
		ctx[k] = extra[k]
	return ctx


func _run() -> void:
	print("AI TESTS")
	_fsm()
	_senses()
	_scent()
	_noise()
	_mouse()
	_rat()
	_bird()
	_cat()
	_creatures()
	print("AI TESTS DONE: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _fsm() -> void:
	var fsm := CreatureFSM.new()
	fsm.add_state("a")
	fsm.add_state("b")
	check(fsm.change_to("a") == false, "already in the first state is not a change")
	check(fsm.change_to("b"), "transition a → b")
	check(fsm.state == "b" and fsm.previous == "a", "state and previous")
	fsm.tick(0.25, {})
	check(is_equal_approx(fsm.time_in_state, 0.25), "time_in_state accumulates")
	check(not fsm.change_to("nope"), "unknown state is refused")


func _senses() -> void:
	var eyes := CreaturePerception.new()
	eyes.sight_range = 5.0
	eyes.sight_fov_deg = 90.0
	var fwd := Vector3(0, 0, -1)
	check(eyes.can_see(Vector3.ZERO, fwd, Vector3(0, 0, -2), false), "sees straight ahead")
	check(not eyes.can_see(Vector3.ZERO, fwd, Vector3(0, 0, 2), false), "does not see behind")
	check(not eyes.can_see(Vector3.ZERO, fwd, Vector3(0, 0, -9), false), "does not see past the range")
	check(not eyes.can_see(Vector3.ZERO, fwd, Vector3(0, 0, -2), true), "a wall blocks sight")
	check(eyes.hear_loudness(Vector3.ZERO, Vector3(1, 0, 0), 1.0, 4.0) > 0.7, "a close sound is loud")
	check(eyes.hear_loudness(Vector3.ZERO, Vector3(5, 0, 0), 1.0, 4.0) == 0.0, "a sound past the range is silence")
	check(is_equal_approx(CreatureProfiles.nocturnal_activity(0.0), 1.0), "mice are fully awake at midnight")
	check(CreatureProfiles.nocturnal_activity(12.0) < 0.05, "mice are asleep at noon")
	check(CreatureProfiles.crepuscular_activity(18.5) > 0.9, "the other cat is up at dusk")
	check(CreatureProfiles.crepuscular_activity(12.0) < 0.15, "the other cat is not a noon cat")


func _scent() -> void:
	var map := CatScentMap.new()
	map.setup(Vector2(-4, -4), Vector2(8, 8), 0.5)
	map.deposit(Vector3.ZERO, 1.2)
	check(map.danger_at(Vector3.ZERO) > 0.9, "fresh scent under the cat is danger")
	check(map.danger_at(Vector3(3, 0, 0)) < map.danger_at(Vector3.ZERO), "danger falls off with distance")
	# One cell east of the deposit (cells are 0.5 m; the deposit covers x 0..0.5).
	var grad := map.gradient(Vector3(0.75, 0, 0))
	check(grad.x < 0.0, "the danger gradient points back toward the trail")
	var before := map.danger_at(Vector3.ZERO)
	map.decay(3.0)
	check(map.danger_at(Vector3.ZERO) < before * 0.4, "scent fades")
	map.add_novel(Vector3(1, 0, 1), "teapot")
	var near := map.nearest_novel(Vector3(1, 0, 1.2), 1.0)
	check(String(near.get("id", "")) == "teapot" and float(near.get("familiarity", 1.0)) < 0.05, "a new teapot is unfamiliar")
	map.age_novels(60.0)
	check(map.familiarity_of("teapot") > 0.9, "an old teapot becomes familiar")


func _mouse() -> void:
	var noon := CreatureBrain.new()
	noon.bind_profile("mouse", 1)
	var asleep: Dictionary = noon.step(0.3, _ctx({"hour": 12.0}))
	check(String(asleep["state"]) == "idle" and float(asleep["speed"]) == 0.0, "a mouse at noon stays put")

	var freeze := CreatureBrain.new()
	freeze.bind_profile("mouse", 1)
	var fr: Dictionary = freeze.step(0.1, _ctx({"scent": 0.5}))
	check(String(fr["state"]) == "freeze" and float(fr["speed"]) == 0.0, "medium cat-scent freezes a mouse")
	var flee := CreatureBrain.new()
	flee.bind_profile("mouse", 1)
	var fl: Dictionary = flee.step(0.1, _ctx({"scent": 0.95}))
	check(String(fl["state"]) == "flee" and float(fl["speed"]) > 2.0, "strong cat-scent makes a mouse flee")
	var heard := CreatureBrain.new()
	heard.bind_profile("mouse", 1)
	var hd: Dictionary = heard.step(0.1, _ctx({
		"sounds": [{"pos": Vector3(0.2, 0, 0), "loudness": 1.0, "kind": "meow"}],
	}))
	check(String(hd["state"]) == "flee", "a close meow is enough to flee")
	var behind := CreatureBrain.new()
	behind.bind_profile("mouse", 1)
	var bh: Dictionary = behind.step(0.1, _ctx({
		"has_cat": true,
		"cat_pos": Vector3(0, 0, 1.2),
		"forward": Vector3(0, 0, -1),
	}))
	check(String(bh["state"]) == "flee", "a cat behind the mouse is heard, not ignored")

	var plain := CreatureBrain.new()
	plain.bind_profile("mouse", 5)
	plain.profile["runway_reuse"] = 0.0
	var pulled := CreatureBrain.new()
	pulled.bind_profile("mouse", 5)
	pulled.profile["runway_reuse"] = 0.0
	var a: Dictionary = plain.step(0.4, _ctx({"force_nibble": true}))
	var b: Dictionary = pulled.step(0.4, _ctx({"force_nibble": true, "wall_pull": Vector3(1, 0, 0)}))
	check(b["target"].x > a["target"].x + 0.8, "thigmotaxis pulls the nibble toward the wall")

	var runner := CreatureBrain.new()
	runner.bind_profile("mouse", 2)
	runner.profile["runway_reuse"] = 1.0
	runner.remember_runway(Vector3(1, 0, 1))
	runner.remember_runway(Vector3(3, 0, 2))
	var reused := true
	for _i in 8:
		var sample: Dictionary = runner.sample_runway()
		var pos: Vector3 = sample["pos"]
		if not bool(sample["reused"]) or not (pos == Vector3(1, 0, 1) or pos == Vector3(3, 0, 2)):
			reused = false
	check(reused, "runway reuse picks a path the mouse already wore in")

	var nibbler := CreatureBrain.new()
	nibbler.bind_profile("mouse", 3)
	nibbler.profile["runway_reuse"] = 0.0
	check(not bool(nibbler.profile["cache_food"]), "mice do not cache food")
	var anchors: Array = []
	for i in 6:
		anchors.append(Vector3(float(i) * 0.8, 0, 0.4))
	var unique := {}
	var all_nibbles := true
	for _i in 6:
		var intent: Dictionary = nibbler.step(0.2, _ctx({"force_nibble": true, "nibble_anchors": anchors}))
		unique[intent["target"]] = true
		if String(intent["state"]) != "nibble":
			all_nibbles = false
	check(all_nibbles and unique.size() >= 5, "nibbles are scattered spots, not one cache (%d)" % unique.size())
	check(CreatureProfiles.investigates_novel("mouse"), "mice are not wary of a new object")

	var creeping := CreatureBrain.new()
	creeping.bind_profile("mouse", 1)
	var creep: Dictionary = creeping.step(0.1, _ctx({
		"has_cat": true,
		"cat_pos": Vector3(0, 0, 1.2),
		"forward": Vector3(0, 0, -1),
		"gait": "stalk",
	}))
	check(String(creep["state"]) != "flee" and String(creep["state"]) != "freeze", "a stalk behind her is quiet enough to ignore (state %s)" % String(creep["state"]))
	var sprinter := CreatureBrain.new()
	sprinter.bind_profile("mouse", 1)
	var thunder: Dictionary = sprinter.step(0.1, _ctx({
		"sounds": [CatNoise.footstep(Vector3(0.4, 0, 0), "sprint")],
	}))
	check(String(thunder["state"]) == "flee", "a sprint at her heels is loud enough to flee")
	var shouted := CreatureBrain.new()
	shouted.bind_profile("mouse", 1)
	var shout: Dictionary = shouted.step(0.1, _ctx({
		"sounds": [CatNoise.meow(Vector3(3.0, 0, 0))],
	}))
	check(String(shout["state"]) == "flee", "a meow from across the floor still sends her off")

	var hider := CreatureBrain.new()
	hider.bind_profile("mouse", 1)
	var hid: Dictionary = hider.step(0.1, _ctx({
		"scent": 0.95,
		"has_cat": true,
		"cat_pos": Vector3(-1.5, 0, 0),
		"cracks": [Vector3(1.5, 0, 0.2)],
	}))
	check(String(hid["state"]) == "crack" and String(hid["note"]) == "crack", "she dives for a crack away from the cat instead of the open")
	check(hid["target"].x > 1.0, "the crack she picks is the one behind her")
	var tucked_brain := CreatureBrain.new()
	tucked_brain.bind_profile("mouse", 1)
	var tucked: Dictionary = tucked_brain.step(0.1, _ctx({
		"pos": Vector3(1.45, 0, 0.1),
		"scent": 0.95,
		"has_cat": true,
		"cat_pos": Vector3(-1.5, 0, 0),
		"cracks": [Vector3(1.5, 0, 0.2)],
	}))
	check(String(tucked["state"]) == "crack" and float(tucked["speed"]) == 0.0 and String(tucked["note"]) == "tucked", "in the crack she holds still")

	var comer := CreatureBrain.new()
	comer.bind_profile("mouse", 1)
	comer.step(0.1, _ctx({"scent": 0.95, "home": Vector3(3, 0, 0)}))
	var back: Dictionary = comer.step(0.8, _ctx({"scent": 0.0, "home": Vector3(3, 0, 0)}))
	check(String(back["state"]) == "return", "once it is quiet she comes back")
	check(back["target"].distance_to(Vector3(3, 0, 0)) < 0.05, "she comes back to her own spot")
	var nester := CreatureBrain.new()
	nester.bind_profile("mouse", 1)
	nester.step(0.1, _ctx({"scent": 0.95, "home": Vector3(3, 0, 0)}))
	var along: Dictionary = nester.step(0.8, _ctx({
		"scent": 0.0,
		"home": Vector3(3, 0, 0),
		"wall_pull": Vector3(1, 0, 0),
	}))
	check(String(along["state"]) == "return" and String(along["note"]) == "nest", "the way home is a nest return")
	check(along["target"].x > 3.8, "she hugs the wall on the way back to the nest (x %.2f)" % along["target"].x)
	var still := CreatureBrain.new()
	still.bind_profile("mouse", 1)
	still.step(0.1, _ctx({"scent": 0.5}))
	var held: Dictionary = still.step(0.2, _ctx({"scent": 0.0}))
	check(String(held["state"]) == "freeze" and float(held["speed"]) == 0.0, "a freeze holds after the scent thins")


func _noise() -> void:
	check(CatNoise.loudness("stalk") < CatNoise.loudness("walk"), "a stalk is quieter than a walk")
	check(CatNoise.loudness("walk") < CatNoise.loudness("sprint"), "a walk is quieter than a sprint")
	check(CatNoise.loudness("sprint") < CatNoise.loudness("meow"), "a meow carries further than a sprint")
	check(CatNoise.loudness("idle") == 0.0, "standing still makes no footfall")
	check(CatNoise.gait_of(true, true, false) == "sprint", "sprinting is the sprint gait")
	check(CatNoise.gait_of(true, false, true) == "stalk", "stalking is the stalk gait")
	check(CatNoise.gait_of(false, true, false) == "idle", "shift held while still is not a footstep")
	check(CatNoise.footstep(Vector3.ZERO, "idle").is_empty(), "an idle cat leaves no sound event")
	check(String(CatNoise.meow(Vector3.ZERO)["kind"]) == "meow", "a meow is a meow")
	check(CatNoise.scent_rate("stalk") < CatNoise.scent_rate("walk"), "a stalk leaves less scent than a walk")
	check(CatNoise.scent_rate("walk") < CatNoise.scent_rate("sprint"), "a sprint leaves more scent than a walk")


func _rat() -> void:
	check(not CreatureProfiles.investigates_novel("rat"), "rats ARE wary of new things")
	var desired := Vector3.ZERO
	var novel := Vector3(0.3, 0, 0)
	var mouse_t := CreatureBrain.steer_neophobia(desired, Vector3(-1, 0, 0), novel, CreatureProfiles.neophobia_of("mouse"))
	var rat_t := CreatureBrain.steer_neophobia(desired, Vector3(-1, 0, 0), novel, CreatureProfiles.neophobia_of("rat"))
	check(rat_t.distance_to(novel) > mouse_t.distance_to(novel) + 0.5, "the rat steps further from a new object than the mouse")
	var used_to_it := CreatureBrain.steer_neophobia(desired, Vector3.ZERO, novel, CreatureProfiles.neophobia_of("rat"), 1.0)
	check(used_to_it.distance_to(desired) < 0.01, "a familiar object no longer bothers the rat")
	var flee := CreatureBrain.decide_rat("chase", 1, 1.2, 0, 4.5, 0.0, 0.016)
	check(String(flee["state"]) == "flee" and bool(flee["fleeing"]), "a lone rat at 1 HP flees")
	var brave := CreatureBrain.decide_rat("chase", 1, 1.2, 2, 4.5, 0.0, 0.016)
	check(String(brave["state"]) == "chase" and not bool(brave["fleeing"]), "packmates keep a hurt rat brave")
	var drop := CreatureBrain.decide_rat("chase", 3, 9.0, 0, 4.5, 0.0, 0.016)
	check(String(drop["state"]) == "idle", "leaving aggro ends the chase")
	var rat := CreatureBrain.new()
	rat.bind_profile("rat", 4)
	var avoid: Dictionary = rat.step(0.2, _ctx({
		"novel": {"pos": Vector3(0.4, 0, 0), "familiarity": 0.0, "id": "radio"},
		"home": Vector3.ZERO,
	}))
	check(String(avoid["state"]) == "avoid", "rat wander names the avoidance")
	check(CreatureBrain.rat_riposte("chase", 3, 0.4, 0, 0.32), "a healthy rat lunges when the cat is in reach")
	check(not CreatureBrain.rat_riposte("chase", 1, 0.4, 0, 0.32), "alone at 1 HP she does not riposte")
	check(not CreatureBrain.rat_riposte("flee", 3, 0.2, 2, 0.32), "a rat already fleeing does not turn back into a lunge")
	check(not CreatureBrain.rat_riposte("chase", 3, 3.0, 0, 0.32), "she does not lunge from across the den")


func _bird() -> void:
	var outdoor := CreatureBrain.new()
	outdoor.bind_profile("songbird", 1)
	var cat := {"has_cat": true, "cat_pos": Vector3(0, 0, -2), "indoor": false, "lights": [Vector3(5, 1.4, 0)], "flock": []}
	var alarm: Dictionary = outdoor.step(0.1, _ctx(cat))
	check(String(alarm["state"]) == "alarm" and bool(alarm["alarm"]), "first sight of a cat outdoors is an alarm call")
	var mob: Dictionary = outdoor.step(0.1, _ctx(cat))
	check(String(mob["state"]) == "mob" and bool(mob["mob"]), "the next beat, the flock mobs")
	var indoor := CreatureBrain.new()
	indoor.bind_profile("songbird", 1)
	var indoor_ctx := {
		"has_cat": true,
		"cat_pos": Vector3(0, 0, -2),
		"indoor": true,
		"lights": [Vector3(4, 1.6, 1)],
		"flock": [],
	}
	var called: Dictionary = indoor.step(0.1, _ctx(indoor_ctx))
	check(String(called["state"]) == "alarm" and bool(called["alarm"]), "indoors the first sight is an alarm call")
	var panic: Dictionary = indoor.step(0.1, _ctx(indoor_ctx))
	check(String(panic["state"]) == "panic_light", "indoors a songbird panic-flies after the call")
	var light: Vector3 = panic["target"]
	check(light.distance_to(Vector3(4, 1.6, 1)) < 0.05, "the panic aims at the light, not the cat")
	var calm := CreatureBrain.new()
	calm.bind_profile("songbird", 1)
	var forage: Dictionary = calm.step(0.1, _ctx({"indoor": false, "flock": [], "lights": []}))
	check(String(forage["state"]) == "forage", "with no cat, a songbird forages")
	var group := CreatureBrain.new()
	group.bind_profile("songbird", 1)
	var flock: Dictionary = group.step(0.1, _ctx({
		"indoor": false,
		"flock": [Vector3(6, 0, 0), Vector3(6.4, 0, 0.2)],
		"lights": [],
	}))
	check(String(flock["state"]) == "flock", "a bird far from its flock closes the gap")
	check(flock["target"].x > 5.0, "flocking steers toward the others")
	var to_glass := CreatureBrain.new()
	to_glass.bind_profile("songbird", 1)
	var glass_ctx := {
		"has_cat": true,
		"cat_pos": Vector3(0, 0, -2),
		"indoor": true,
		"lights": [Vector3(0.3, 1.2, 0)],
		"windows": [Vector3(6.0, 1.6, 1.0)],
		"flock": [],
	}
	to_glass.step(0.1, _ctx(glass_ctx))
	var glass: Dictionary = to_glass.step(0.1, _ctx(glass_ctx))
	check(String(glass["state"]) == "panic_light" and String(glass["note"]) == "window", "indoors the panic is toward a window")
	var warned := CreatureBrain.new()
	warned.bind_profile("songbird", 1)
	var flush: Dictionary = warned.step(0.1, _ctx({
		"has_cat": false,
		"indoor": true,
		"lights": [Vector3(0.3, 1.2, 0)],
		"windows": [Vector3(6.0, 1.6, 1.0)],
		"sounds": [{"pos": Vector3(1.2, 0, 0), "loudness": 0.85, "kind": "alarm"}],
		"flock": [],
	}))
	check(String(flush["state"]) == "panic_light" and String(flush["note"]) == "warned", "an alarm call flushes a bird who never saw the cat")
	var glass_at: Vector3 = glass["target"]
	check(glass_at.distance_to(Vector3(6.0, 1.6, 1.0)) < 0.05, "a far window beats a nearer lamp")


func _cat() -> void:
	var noon := CreatureBrain.new()
	noon.bind_profile("other_cat", 1)
	var perch: Dictionary = noon.step(0.2, _ctx({
		"hour": 12.0,
		"has_prey": true,
		"prey_pos": Vector3(2, 0, 0),
		"perches": [Vector3(0, 0.4, 0), Vector3(1, 1.8, 0)],
	}))
	check(String(perch["state"]) == "perch", "at noon the other cat takes a perch")
	var high: Vector3 = perch["target"]
	check(is_equal_approx(high.y, 1.8), "the perch she picks is the high one")
	var dusk := CreatureBrain.new()
	dusk.bind_profile("other_cat", 1)
	var stalk: Dictionary = dusk.step(0.1, _ctx({
		"hour": 19.0,
		"has_prey": true,
		"prey_pos": Vector3(0, 0, -4),
		"perches": [Vector3(0, 1.5, 0)],
	}))
	check(String(stalk["state"]) == "stalk", "at dusk, prey in sight, she stalks")
	var crouch: Dictionary = dusk.step(0.1, _ctx({
		"hour": 19.0,
		"has_prey": true,
		"prey_pos": Vector3(0, 0, -1.0),
		"perches": [Vector3(0, 1.5, 0)],
	}))
	check(String(crouch["state"]) == "crouch" and float(crouch["speed"]) == 0.0, "inside crouch range she stops and crouches")
	var pounce: Dictionary = dusk.step(0.5, _ctx({
		"hour": 19.0,
		"has_prey": true,
		"prey_pos": Vector3(0, 0, -0.4),
		"perches": [Vector3(0, 1.5, 0)],
	}))
	check(String(pounce["state"]) == "pounce" and float(pounce["speed"]) > 3.0, "after the crouch, the pounce")

	var picked := CreatureBrain.contested_prey(
		Vector3.ZERO,
		Vector3(0, 0, -3.2),
		[Vector3(0, 0, -4), Vector3(9, 0, 0)],
		Vector3.ZERO,
		5.0
	)
	check(not picked.is_empty() and (picked["pos"] as Vector3).z == -4.0, "she ignores a mouse outside her territory")
	check(bool(picked["contest"]), "when Willie is closer to the mouse, it is a contest")
	var hurry := CreatureBrain.new()
	hurry.bind_profile("other_cat", 1)
	var race: Dictionary = hurry.step(0.1, _ctx({
		"hour": 19.0,
		"prey_options": [Vector3(0, 0, -4)],
		"has_rival": true,
		"rival_pos": Vector3(0, 0, -3.2),
		"territory": Vector3.ZERO,
		"territory_radius": 6.0,
		"perches": [Vector3(0, 1.5, 0)],
	}))
	check(String(race["state"]) == "stalk" and String(race["note"]) == "contest", "she stalks the mouse he is closing on")
	check(float(race["speed"]) > 1.2, "a contest is faster than her ordinary stalk (%.2f)" % float(race["speed"]))
	var edge := CreatureBrain.new()
	edge.bind_profile("other_cat", 1)
	var hold: Dictionary = edge.step(0.1, _ctx({
		"hour": 19.0,
		"has_rival": true,
		"has_prey": false,
		"rival_pos": Vector3(10, 0, 0),
		"territory": Vector3.ZERO,
		"territory_radius": 4.0,
		"perches": [Vector3(0, 1.5, 0)],
	}))
	var hold_at: Vector3 = hold["target"]
	check(String(hold["state"]) == "patrol" and hold_at.x < 4.0 and hold_at.x > 3.0, "Willie outside her ground, she holds the edge (x %.2f)" % hold_at.x)
	var noon_rival := CreatureBrain.new()
	noon_rival.bind_profile("other_cat", 1)
	var nap: Dictionary = noon_rival.step(0.2, _ctx({
		"hour": 12.0,
		"has_rival": true,
		"rival_pos": Vector3(1, 0, 0),
		"territory": Vector3.ZERO,
		"territory_radius": 4.0,
		"perches": [Vector3(0, 1.6, 0)],
	}))
	check(String(nap["state"]) == "perch", "at noon she stays on the box even if Willie walks in")


func _creatures() -> void:
	var moth := CreatureBrain.new()
	moth.bind_profile("moth", 1)
	var lamp := Vector3(0, 1.5, 0)
	var orbit: Dictionary = moth.step(0.2, {"pos": lamp, "lamp": lamp, "sounds": [], "has_cat": false})
	check(String(orbit["state"]) == "orbit", "a moth with a quiet lamp stays on it")
	check((orbit["target"] as Vector3).distance_to(lamp) < 0.7, "the orbit stays in the lamp's pool")
	var scare: Dictionary = moth.step(0.1, {
		"pos": lamp,
		"lamp": lamp,
		"has_cat": true,
		"cat_pos": lamp + Vector3(0.4, 0, 0),
		"sounds": [],
	})
	check(String(scare["state"]) == "startle", "a cat in the pool startles the moth off the lamp")
	var spider := CreatureBrain.new()
	spider.bind_profile("spider", 1)
	var anchor := Vector3(0, 1.4, 0)
	var hang: Dictionary = spider.step(0.1, {"anchor": anchor, "drop": 0.0, "has_cat": true, "cat_pos": Vector3(0, 0, 4)})
	check(String(hang["state"]) == "hang", "a spider stays up when the cat is not under it")
	var descend: Dictionary = spider.step(0.1, {"anchor": anchor, "drop": 0.0, "has_cat": true, "cat_pos": Vector3(0.3, 0, 0)})
	check(String(descend["state"]) == "descend", "a cat underneath brings the spider down")
	var back: Dictionary = spider.step(0.1, {"anchor": anchor, "drop": 0.8, "has_cat": true, "cat_pos": Vector3(0.3, 0, 0), "retreating": true})
	check(String(back["state"]) == "retreat", "after the drop she goes back up")
	var sq := CreatureBrain.new()
	sq.bind_profile("squirrel", 1)
	var graze: Dictionary = sq.step(0.1, {"pos": Vector3.ZERO, "tree": Vector3(4, 0, 0), "cat_dist": 8.0, "meow": 0.0, "at_tree": false})
	check(String(graze["state"]) == "forage", "a squirrel with a quiet yard keeps foraging")
	var up: Dictionary = sq.step(0.1, {"pos": Vector3.ZERO, "tree": Vector3(4, 0, 0), "cat_dist": 5.0, "meow": CatNoise.loudness("meow"), "at_tree": false})
	check(String(up["state"]) == "flee_tree", "a meow sends the squirrel for its tree")
	check((up["target"] as Vector3).distance_to(Vector3(4, 0, 0)) < 0.05, "the tree is the one she knows")
	check(CreatureBrain.squirrel_hears_meow(5.0, CatNoise.loudness("meow")), "meow inside the radius is heard")
	check(not CreatureBrain.squirrel_hears_meow(5.0, CatNoise.loudness("stalk")), "a stalk at the same distance is not")
	check(not CreatureBrain.squirrel_hears_meow(8.0, CatNoise.loudness("meow")), "a meow past the radius fades out")
