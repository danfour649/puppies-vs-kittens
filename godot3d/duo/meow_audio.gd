class_name MeowAudio
extends RefCounted
## DUO — procedural cat voices, synthesised at runtime.
##
## No audio assets: a meow is a sine sweep with vibrato and a breath
## of noise, rendered once into an AudioStreamWAV in memory and then
## played like any other stream — including in the web build, where
## by play time it is simply an AudioStream on a player node.
##
## Willie: the classic two-tone — rises, then the long falling "ow"
## (~0.45 s, 825 -> 425 Hz). Aggie: a short, high chirp (~0.18 s);
## she rarely bothers.

const RATE := 22050

static var _cache: Dictionary = {}


static func stream_for(kind: String) -> AudioStreamWAV:
	if _cache.has(kind):
		return _cache[kind]
	var s: AudioStreamWAV
	if kind == "aggie":
		s = _synth(0.18, 1120.0, 1310.0, 870.0, 0.30, 13.0, 0.55)
	else:
		s = _synth(0.45, 655.0, 825.0, 425.0, 0.35, 11.0, 0.8)
	_cache[kind] = s
	return s


## A positional voice for a cat: modest volume, generous range so a
## meow carries across the yard (which is rather the problem).
static func make_voice(cat: Node3D) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = "MeowVoice"
	p.unit_size = 2.5
	p.max_distance = 40.0
	p.volume_db = -7.0
	cat.add_child(p)
	return p


static func _synth(dur: float, f0: float, f_peak: float, f1: float, peak_at: float, vib_hz: float, vol: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 # deterministic: the same meow every build
	for i in n:
		var t := float(i) / float(RATE)
		var k := clampf(t / dur, 0.0, 1.0)
		var f: float
		if k < peak_at:
			f = lerpf(f0, f_peak, k / peak_at)
		else:
			f = lerpf(f_peak, f1, (k - peak_at) / (1.0 - peak_at))
		f *= 1.0 + 0.025 * sin(TAU * vib_hz * t) * k # vibrato grows on the fall
		phase += TAU * f / float(RATE)
		var env := pow(sin(PI * clampf(k, 0.001, 0.999)), 0.65)
		var v := sin(phase) + 0.35 * sin(2.0 * phase) + 0.12 * sin(3.0 * phase)
		v = v * env * vol + rng.randf_range(-0.02, 0.02) * env
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream
