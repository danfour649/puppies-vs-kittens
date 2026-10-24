class_name HissAudio
extends RefCounted
## Procedural cat hiss, synthesised at runtime — the MeowAudio
## approach (duo/meow_audio.gd) turned inside out: a meow is a tone,
## a hiss is NOISE. Band-swept white noise (one-pole lowpass whose
## cutoff falls as the burst decays) under a fast-attack envelope,
## rendered once into an AudioStreamWAV. No audio assets; deterministic
## seed, so it is the same hiss every build — including the web build.

const RATE := 22050
const DURATION := 0.8

static var _cache: AudioStreamWAV = null


static func stream() -> AudioStreamWAV:
	if _cache != null:
		return _cache
	var n := int(RATE * DURATION)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1313 # deterministic
	var lp := 0.0
	for i in n:
		var t := float(i) / float(RATE)
		var k := clampf(t / DURATION, 0.0, 1.0)
		# Envelope: 30 ms attack, long sputtering decay with a second
		# smaller burst — the classic double-hiss.
		var env := clampf(t / 0.03, 0.0, 1.0) * (1.0 - k) * (1.0 - k)
		env += 0.35 * clampf((t - 0.45) / 0.03, 0.0, 1.0) * pow(1.0 - clampf((t - 0.45) / (DURATION - 0.45), 0.0, 1.0), 2.0) * (1.0 if t >= 0.45 else 0.0)
		# One-pole lowpass; alpha falls over the burst (bright -> dull).
		var alpha := lerpf(0.55, 0.12, k)
		lp += alpha * (rng.randf_range(-1.0, 1.0) - lp)
		var hp := rng.randf_range(-1.0, 1.0) - lp # keep some top-end sizzle
		var v := (lp * 1.4 + hp * 0.35) * env * 0.8
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	_cache = s
	return s


## A positional voice for the hiss: close and loud — it is meant to
## startle (it startles the rats and spiders too; see basement.gd).
static func make_voice(host: Node3D) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = "HissVoice"
	p.stream = stream()
	p.unit_size = 1.6
	p.max_distance = 18.0
	p.volume_db = -4.0
	host.add_child(p)
	return p
