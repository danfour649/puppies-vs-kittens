class_name OutsideAudio
extends RefCounted
## Willie and Aggie — outside zone voices: procedural car horns and
## dog barks, synthesised at runtime in the same idiom as
## duo/meow_audio.gd (no audio assets; a stream is rendered once
## into memory and played like any other — web build included).
##
## Horn: a two-tone car horn (~0.5 s, 370 + 466 Hz square-ish stack)
## — the telegraph when a driver decides to aim at the cat.
## Bark: short filtered-noise + low thump bursts; the small dog
## yaps higher and faster than the big dog.

const RATE := 22050

static var _cache: Dictionary = {}


static func horn_stream() -> AudioStreamWAV:
	if _cache.has("horn"):
		return _cache["horn"]
	var dur := 0.5
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var p1 := 0.0
	var p2 := 0.0
	for i in n:
		var t := float(i) / float(RATE)
		var k := clampf(t / dur, 0.0, 1.0)
		p1 += TAU * 370.0 / float(RATE)
		p2 += TAU * 466.0 / float(RATE)
		var env := minf(1.0, t / 0.03) * minf(1.0, (dur - t) / 0.09)
		var v: float = (sign(sin(p1)) * 0.30 + sign(sin(p2)) * 0.24
			+ sin(p1) * 0.18 + sin(p2) * 0.14) * env
		# a slight sag as the horn "leans on it"
		v *= 1.0 - 0.12 * k
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	_cache["horn"] = stream
	return stream


static func bark_stream(big: bool) -> AudioStreamWAV:
	var key := "bark_big" if big else "bark_small"
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 777 if big else 778 # deterministic, like the meow
	var base := 210.0 if big else 340.0
	var burst := 0.13 if big else 0.09
	var gap := 0.07
	var bursts := 2
	var dur := bursts * burst + (bursts - 1) * gap + 0.03
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(RATE)
		var cyc := burst + gap
		var lt := fmod(t, cyc)
		var v := 0.0
		if lt < burst:
			var env := sin(PI * clampf(lt / burst, 0.001, 0.999))
			var f := base * (1.0 - 0.35 * (lt / burst)) # bark falls off
			phase += TAU * f / float(RATE)
			v = (sin(phase) * 0.55 + sign(sin(phase)) * 0.20
				+ rng.randf_range(-0.30, 0.30)) * env * 0.8
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	_cache[key] = stream
	return stream


## A positional voice on any node (car horn, dog bark).
static func make_voice(node: Node3D, volume_db := -9.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = "OutsideVoice"
	p.unit_size = 2.5
	p.max_distance = 45.0
	p.volume_db = volume_db
	node.add_child(p)
	return p
