class_name Animal
extends Node2D

## One actor for every species. Behaviour comes from the species definition
## (a Dictionary loaded from JSON by AnimalKit) plus a small state-machine
## "brain" chosen by the definition's "brain" field:
##
##   player          — driven by input_move / input_strike (the kitten)
##   player_bird     — same input contract, plus the flight model (bird mode)
##   prey            — wander / graze / flee + flock separation (mice)
##   pack_hunter     — proportional chase with per-member stagger (puppies)
##   wanderer        — slow aimless wander (the kitten while you are the bird)
##   aerial_predator — circling hunter that dives at prey (wild bird NPC)
##
## Fight rules mirror the Java original (KvPModel.java): a strike wounds a
## mouse, the wound kills after wound_ttl seconds (Java: timeToLiveAfterHurt
## = 3), puppies damage the kitten per second while in attack range.
##
## The node origin is the animal's GROUND position. The visual child is
## lifted by altitude (birds) and bobbing; the shadow stays on the ground.

signal died(animal: Animal)
signal hp_changed(animal: Animal)

var species_def: Dictionary = {}
var species_id: String = ""
var brain: String = "prey"
var player_controlled: bool = false

var max_hp: float = 1.0
var hp: float = 1.0
var is_dead: bool = false
var is_wounded: bool = false
var in_attack_range: bool = false

var velocity: Vector2 = Vector2.ZERO
var facing: Vector2 = Vector2.DOWN
var field_rect: Rect2 = Rect2(0, 0, 1000, 1000)

# Wiring handed down by the game each round / tick.
var threat: Animal = null # hunters chase this; prey flees this
var flock: Array = [] # fellow prey, for separation
var pack_index: int = 0 # position in the pack (drives the Java stagger)
var tuning: Dictionary = {} # difficulty tuning from the game

# Player input contract (written by the game's controller / touch UI).
var input_move: Vector2 = Vector2.ZERO
var input_strike: bool = false

# Flight model (bird). altitude: 0 = ground, 1 = cruise.
var altitude: float = 0.0
var flight_phase: String = "ground" # ground | cruise | dive | climb

var _wound_timer: float = -1.0
var _strike_timer: float = 0.0
var _snatch_timer: float = 0.0
var _action_timer: float = 0.0
var _state_timer: float = 0.0
var _graze_left: float = 0.0
var _wander_dir: Vector2 = Vector2.ZERO
var _waypoint: Vector2 = Vector2.ZERO
var _dive_prey: Animal = null
var _bob: float = 0.0
var _squash: float = 0.0
var _flip: float = 1.0
var _rng := RandomNumberGenerator.new()

var _visual: Node2D = null
var _sprite: Sprite2D = null
var _shadow: Polygon2D = null
var _hp_fg: ColorRect = null
var _fx: CPUParticles2D = null
var _wing_l: Polygon2D = null
var _wing_r: Polygon2D = null
var _tex_idle: Texture2D = null
var _tex_action: Texture2D = null
var _tex_dead: Texture2D = null
var _base_visual_scale: Vector2 = Vector2.ONE


func _ready() -> void:
    _rng.randomize()
    if species_def.is_empty():
        species_def = AnimalKit.load_species("mouse")
    species_id = str(species_def.get("id", "mouse"))
    brain = str(species_def.get("brain", "prey"))
    max_hp = float(species_def.get("max_hp", 1))
    hp = max_hp
    add_to_group("animals")
    if brain == "prey":
        add_to_group("prey")
    if species_id == "bird":
        _state_timer = _rng.randf_range(5.0, 9.0) # first NPC dive comes late, not at t=0
    _build_visuals()


func is_airborne() -> bool:
    return altitude > 0.3


func paw_point() -> Vector2:
    var reach := float(species_def.get("strike_range", 100.0))
    return global_position + facing * reach + Vector2(0, 26)


func try_strike() -> void:
    if is_dead:
        return
    if species_id == "bird":
        start_dive()
        return
    if _strike_timer > 0.0:
        return
    _strike_timer = float(species_def.get("strike_cooldown", 0.45))
    _action_timer = 0.28
    _squash = 1.0
    _burst()
    var paw := paw_point()
    var radius := float(species_def.get("strike_radius", 100.0))
    for prey in get_tree().get_nodes_in_group("prey"):
        if prey == self or prey.is_dead:
            continue
        if paw.distance_to(prey.global_position) <= radius:
            prey.wound()


func start_dive() -> void:
    if species_id != "bird" or is_dead:
        return
    # A dive can start from cruise, or straight out of the takeoff climb
    # once the bird is high enough — mashing SPACE while climbing works.
    if (flight_phase == "cruise" or flight_phase == "ground") and altitude > 0.5 and _snatch_timer <= 0.0:
        flight_phase = "dive"
        _squash = 0.6


func wound() -> void:
    if is_dead or is_wounded:
        return
    is_wounded = true
    _wound_timer = float(species_def.get("wound_ttl", 3.0))
    _burst()
    _refresh_sprite()


func take_damage(amount: float) -> void:
    if is_dead:
        return
    if is_airborne():
        return # airborne: puppies cannot reach (bird-mode rule)
    hp -= amount
    hp_changed.emit(self)
    if hp <= 0.0:
        hp = 0.0
        die()


func die() -> void:
    if is_dead:
        return
    is_dead = true
    velocity = Vector2.ZERO
    _refresh_sprite()
    died.emit(self)


# ---------------------------------------------------------------- visuals

func _ellipse_points(rx: float, ry: float, count: int) -> PackedVector2Array:
    var pts := PackedVector2Array()
    for i in count:
        var a := TAU * float(i) / float(count)
        pts.append(Vector2(cos(a) * rx, sin(a) * ry))
    return pts


func _build_visuals() -> void:
    _shadow = Polygon2D.new()
    var sw := float(species_def.get("shadow_width", 100.0))
    _shadow.polygon = _ellipse_points(sw * 0.5, sw * 0.20, 20)
    _shadow.color = Color(0, 0, 0, 0.28)
    _shadow.position = Vector2(0, 8)
    add_child(_shadow)

    var sprites: Dictionary = species_def.get("sprites", {})
    if sprites.has("idle"):
        _tex_idle = load("res://assets/" + str(sprites["idle"]))
        if sprites.has("action"):
            _tex_action = load("res://assets/" + str(sprites["action"]))
        if sprites.has("dead"):
            _tex_dead = load("res://assets/" + str(sprites["dead"]))
        _sprite = Sprite2D.new()
        _sprite.texture = _tex_idle
        var target_w := float(species_def.get("sprite_width", 120.0))
        var s := target_w / float(_tex_idle.get_width())
        _base_visual_scale = Vector2(s, s)
        _sprite.scale = _base_visual_scale
        add_child(_sprite)
        _visual = _sprite
    else:
        # No image asset exists for this species in the original art set,
        # so the body is drawn in code (vector polygons), per project rules.
        _visual = _make_bird_body()
        var target_w := float(species_def.get("sprite_width", 190.0))
        _base_visual_scale = Vector2(target_w / 190.0, target_w / 190.0)
        _visual.scale = _base_visual_scale
        add_child(_visual)

    if bool(species_def.get("show_hp_bar", false)):
        var bg := ColorRect.new()
        bg.color = Color(0.55, 0.08, 0.08)
        bg.size = Vector2(96, 11)
        bg.position = Vector2(-48, -118)
        add_child(bg)
        _hp_fg = ColorRect.new()
        _hp_fg.color = Color(0.25, 0.85, 0.3)
        _hp_fg.size = Vector2(96, 11)
        _hp_fg.position = bg.position
        add_child(_hp_fg)

    _fx = CPUParticles2D.new()
    _fx.amount = 12
    _fx.one_shot = true
    _fx.explosiveness = 0.9
    _fx.lifetime = 0.45
    _fx.direction = Vector2(0, -1)
    _fx.spread = 180.0
    _fx.initial_velocity_min = 90.0
    _fx.initial_velocity_max = 200.0
    _fx.gravity = Vector2(0, 330)
    _fx.scale_amount_min = 3.0
    _fx.scale_amount_max = 6.0
    _fx.color = Color(1, 0.85, 0.25)
    _fx.emitting = false
    add_child(_fx)


func _make_bird_body() -> Node2D:
    # A simple osprey silhouette drawn pointing UP (-Y): white head/belly,
    # brown wings and tail (GTA bird mode's osprey colourway). Wings are
    # separate polygons pivoted at the shoulders so they can flap in code.
    var colors: Dictionary = species_def.get("body_colors", {})
    var wing_col := Color.html(str(colors.get("wing", "#5a4632")))
    var belly_col := Color.html(str(colors.get("belly", "#f5f0e6")))
    var head_col := Color.html(str(colors.get("head", "#ffffff")))
    var beak_col := Color.html(str(colors.get("beak", "#e8a020")))
    var root := Node2D.new()

    var tail := Polygon2D.new()
    tail.polygon = PackedVector2Array([Vector2(-11, 14), Vector2(11, 14), Vector2(17, 36), Vector2(-17, 36)])
    tail.color = wing_col
    root.add_child(tail)

    _wing_l = Polygon2D.new()
    _wing_l.polygon = PackedVector2Array([Vector2(0, -6), Vector2(-88, -30), Vector2(-95, 2), Vector2(-4, 10)])
    _wing_l.color = wing_col
    _wing_l.position = Vector2(-10, -2)
    root.add_child(_wing_l)

    _wing_r = Polygon2D.new()
    _wing_r.polygon = PackedVector2Array([Vector2(0, -6), Vector2(88, -30), Vector2(95, 2), Vector2(4, 10)])
    _wing_r.color = wing_col
    _wing_r.position = Vector2(10, -2)
    root.add_child(_wing_r)

    var body := Polygon2D.new()
    body.polygon = _ellipse_points(16, 27, 18)
    body.color = belly_col
    root.add_child(body)

    var head := Polygon2D.new()
    head.polygon = _ellipse_points(11.5, 11.5, 16)
    head.color = head_col
    head.position = Vector2(0, -26)
    root.add_child(head)

    var beak := Polygon2D.new()
    beak.polygon = PackedVector2Array([Vector2(-4.5, -33), Vector2(4.5, -33), Vector2(0, -44)])
    beak.color = beak_col
    root.add_child(beak)
    return root


func _burst() -> void:
    if _fx:
        _fx.restart()


func _refresh_sprite() -> void:
    if _sprite == null:
        return
    var want: Texture2D = _tex_idle
    if is_dead and _tex_dead != null:
        want = _tex_dead
    elif (is_wounded or in_attack_range or _action_timer > 0.0) and _tex_action != null:
        want = _tex_action
    if _sprite.texture != want:
        _sprite.texture = want


# ---------------------------------------------------------------- brains

func _physics_process(delta: float) -> void:
    if is_dead:
        return
    _strike_timer = maxf(0.0, _strike_timer - delta)
    _snatch_timer = maxf(0.0, _snatch_timer - delta)
    if _action_timer > 0.0:
        _action_timer -= delta
        if _action_timer <= 0.0:
            _refresh_sprite()
    if _wound_timer > 0.0:
        _wound_timer -= delta
        if _wound_timer <= 0.0:
            die()
            return
    match brain:
        "player":
            _brain_player(delta, false)
        "player_bird":
            _brain_player(delta, true)
        "prey":
            _brain_prey(delta)
        "pack_hunter":
            _brain_hunter(delta)
        "aerial_predator":
            _brain_aerial(delta)
        _:
            _brain_wanderer(delta)
    _integrate(delta)
    _update_visuals(delta)


func _brain_player(delta: float, is_bird: bool) -> void:
    if is_bird:
        _update_flight(delta)
        var speed := float(species_def["flight_speed"]) if altitude > 0.25 else float(species_def.get("ground_speed", 150.0))
        if flight_phase == "dive":
            speed = float(species_def["dive_speed"])
        var desired := input_move * speed
        if input_move == Vector2.ZERO and flight_phase == "cruise":
            desired = facing * speed * 0.55 # glide
        var turn := clampf(float(species_def.get("turn_rate", 6.0)) * delta, 0.0, 1.0)
        velocity = velocity.lerp(desired, turn)
    else:
        velocity = input_move * float(species_def.get("speed", 300.0))
    if input_strike:
        input_strike = false
        try_strike()


func _brain_prey(delta: float) -> void:
    _state_timer -= delta
    var desired := Vector2.ZERO
    var fleeing := false
    if threat != null and is_instance_valid(threat) and not threat.is_dead:
        var d := global_position.distance_to(threat.global_position)
        if d < float(species_def["flee_radius"]) and threat.altitude < 0.35:
            desired = (global_position - threat.global_position).normalized() * float(species_def["flee_speed"])
            fleeing = true
    if not fleeing:
        if _graze_left > 0.0:
            _graze_left -= delta
            desired = Vector2.ZERO # graze: sit and nibble
        else:
            if _state_timer <= 0.0:
                _state_timer = float(species_def["wander_reroll"])
                if _rng.randf() < float(species_def.get("graze_pause_chance", 0.2)):
                    _graze_left = _rng.randf_range(0.8, 2.0)
                _wander_dir = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0))
            # Random-jitter locomotion, the Java moveMice() model: a fresh
            # random velocity each reroll, magnitude scaled by difficulty.
            desired = _wander_dir * float(tuning.get("mouse_jitter", 130.0))
    # Boids-lite: separation from flock mates.
    var sep := Vector2.ZERO
    var sep_r := float(species_def["separation_radius"])
    for other in flock:
        if other == self or other.is_dead or not is_instance_valid(other):
            continue
        var dd := global_position.distance_to(other.global_position)
        if dd > 0.01 and dd < sep_r:
            sep += (global_position - other.global_position).normalized() * (1.0 - dd / sep_r)
    desired += sep * float(species_def["separation_weight"])
    if is_wounded:
        desired *= float(species_def.get("wound_speed_factor", 0.45))
    velocity = desired


func _brain_hunter(delta: float) -> void:
    if threat == null or not is_instance_valid(threat) or threat.is_dead:
        velocity = velocity.move_toward(Vector2.ZERO, 240.0 * delta)
        in_attack_range = false
        _refresh_sprite()
        return
    var dist := global_position.distance_to(threat.global_position)
    in_attack_range = dist <= float(species_def["attack_range"])
    var aim := threat.global_position
    if dist < 260.0:
        # Loose pack: once close, drift to a personal orbit offset instead
        # of stacking on the exact same point.
        var ang := float(pack_index) * 2.1 + float(Time.get_ticks_msec()) * 0.0004
        aim += Vector2(cos(ang), sin(ang)) * float(species_def.get("pack_spread", 120.0)) * 0.55
    # Java chase model: step = distance / divisor each frame, with a
    # per-puppy index multiplier (later puppies effectively faster).
    var rate := float(species_def["chase_rate"]) * float(tuning.get("puppy_rate_mult", 1.0)) * float(pack_index + 1)
    var cap := float(tuning.get("puppy_speed_cap", species_def.get("speed_cap", 300.0)))
    velocity = ((aim - global_position) * rate).limit_length(cap)
    _refresh_sprite()


func _brain_wanderer(delta: float) -> void:
    _state_timer -= delta
    if _state_timer <= 0.0:
        _state_timer = _rng.randf_range(0.9, 1.8)
        if _rng.randf() < 0.3:
            _wander_dir = Vector2.ZERO
        else:
            _wander_dir = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)).normalized()
    velocity = _wander_dir * float(species_def.get("speed", 300.0)) * 0.35


func _brain_aerial(delta: float) -> void:
    _update_flight(delta)
    _state_timer -= delta
    var speed := float(species_def["flight_speed"])
    if flight_phase == "dive":
        speed = float(species_def["dive_speed"])
        if _dive_prey != null and is_instance_valid(_dive_prey) and not _dive_prey.is_dead:
            _waypoint = _dive_prey.global_position # lead-pursuit lite: steer at the prey
    elif flight_phase == "cruise":
        if _waypoint == Vector2.ZERO or global_position.distance_to(_waypoint) < 70.0:
            _waypoint = Vector2(_rng.randf_range(140.0, 860.0), _rng.randf_range(140.0, 860.0))
        if _state_timer <= 0.0:
            _state_timer = _rng.randf_range(6.0, 11.0)
            var prey_list := get_tree().get_nodes_in_group("prey")
            var live: Array = []
            for p in prey_list:
                if not p.is_dead:
                    live.append(p)
            if not live.is_empty():
                _dive_prey = live[_rng.randi_range(0, live.size() - 1)]
                _waypoint = _dive_prey.global_position
                start_dive()
    var desired := (_waypoint - global_position).normalized() * speed
    if flight_phase == "climb":
        desired = facing * speed * 0.7
    var turn := clampf(float(species_def.get("turn_rate", 6.0)) * delta, 0.0, 1.0)
    velocity = velocity.lerp(desired, turn)


# ---------------------------------------------------------------- flight

func _update_flight(delta: float) -> void:
    var cruise := float(species_def.get("cruise_altitude", 1.0))
    match flight_phase:
        "ground":
            altitude = move_toward(altitude, cruise, float(species_def["climb_rate"]) * delta)
            if altitude >= cruise - 0.02:
                flight_phase = "cruise"
        "cruise":
            altitude = move_toward(altitude, cruise, float(species_def["climb_rate"]) * delta)
        "dive":
            altitude -= float(species_def["dive_rate"]) * delta
            if altitude <= 0.0:
                altitude = 0.0
                _resolve_snatch()
                flight_phase = "climb"
        "climb":
            altitude = move_toward(altitude, cruise, float(species_def["climb_rate"]) * delta)
            if altitude >= cruise - 0.02:
                flight_phase = "cruise"


func _resolve_snatch() -> void:
    _snatch_timer = float(species_def.get("snatch_cooldown", 1.1))
    _burst()
    var radius := float(species_def.get("snatch_radius", 62.0))
    for prey in get_tree().get_nodes_in_group("prey"):
        if prey.is_dead:
            continue
        if global_position.distance_to(prey.global_position) <= radius:
            prey.wound()


# ---------------------------------------------------------------- common

func _integrate(delta: float) -> void:
    position += velocity * delta
    var margin := float(species_def.get("body_radius", 40.0)) * 0.55
    position.x = clampf(position.x, field_rect.position.x + margin, field_rect.end.x - margin)
    position.y = clampf(position.y, field_rect.position.y + margin, field_rect.end.y - margin)
    if velocity.length() > 6.0:
        facing = velocity.normalized()


func _update_visuals(delta: float) -> void:
    _bob += delta * (5.0 + velocity.length() * 0.03)
    if _visual == null:
        return
    var speed_frac := clampf(velocity.length() / 300.0, 0.0, 1.0)
    var bob_y := sin(_bob * 2.0) * 3.0 * speed_frac
    _squash = move_toward(_squash, 0.0, delta * 4.0)
    if facing.x < -0.05:
        _flip = -1.0
    elif facing.x > 0.05:
        _flip = 1.0
    var lift := altitude * float(species_def.get("altitude_offset_px", 96.0))
    _visual.position.y = -lift + bob_y
    _visual.scale = Vector2(
        _base_visual_scale.x * _flip * (1.0 + 0.16 * _squash),
        _base_visual_scale.y * (1.0 - 0.16 * _squash))
    if species_id == "bird":
        _visual.rotation = facing.angle() + PI * 0.5
        if _wing_l != null and _wing_r != null:
            var flap := sin(_bob * 3.2) * (0.08 if flight_phase == "dive" else 0.5)
            _wing_l.rotation = flap
            _wing_r.rotation = -flap
    if _shadow != null:
        var sh := 1.0 - altitude * 0.45
        _shadow.scale = Vector2(sh, sh)
        _shadow.color = Color(0, 0, 0, 0.28 * (1.0 - altitude * 0.55))
    if _hp_fg != null:
        _hp_fg.size.x = 96.0 * clampf(hp / max_hp, 0.0, 1.0)
