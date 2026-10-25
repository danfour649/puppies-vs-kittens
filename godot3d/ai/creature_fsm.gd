class_name CreatureFSM
extends RefCounted
## Shared state-machine base for Willie and Aggie's creatures.
## States are names plus optional enter / tick / exit callables.
## Changing to the current state is a no-op, so callers can assign
## a mode every frame without resetting time_in_state.


var state: String = ""
var previous: String = ""
var time_in_state: float = 0.0

var _enter := {}
var _tick := {}
var _exit := {}


func add_state(name: String, on_enter: Callable = Callable(), on_tick: Callable = Callable(), on_exit: Callable = Callable()) -> void:
	_enter[name] = on_enter
	_tick[name] = on_tick
	_exit[name] = on_exit
	if state == "":
		state = name


func has_state(name: String) -> bool:
	return _enter.has(name)


func change_to(next: String, ctx: Dictionary = {}) -> bool:
	if next == state:
		return false
	if not has_state(next):
		return false
	if state != "" and _exit[state] is Callable and (_exit[state] as Callable).is_valid():
		(_exit[state] as Callable).call(state, next, ctx)
	previous = state
	state = next
	time_in_state = 0.0
	if _enter[next] is Callable and (_enter[next] as Callable).is_valid():
		(_enter[next] as Callable).call(previous, next, ctx)
	return true


func tick(delta: float, ctx: Dictionary = {}) -> void:
	time_in_state += delta
	if state == "":
		return
	var cb: Callable = _tick.get(state, Callable())
	if cb.is_valid():
		cb.call(delta, ctx)
