class_name PurrAudio
extends RefCounted
## Occupants — a cat purr, synthesised at runtime (mirrors the
## approach of duo/meow_audio.gd: no audio assets, just an
## AudioStreamWAV rendered once in memory).
##
## A purr is a low rumble (~55 Hz with harmonics) whose amplitude is
## pulsed at ~21 Hz — the classic purr pulse rate. The stream is
## exactly 2 s and every component completes a whole number of
## cycles in that window (21 Hz -> 42, 55 -> 110, 110 -> 220,
## 165 -> 330, 260.5 -> 521), so it loops seamlessly.

const RATE := 22050
const DUR := 2.0

static var _stream: AudioStreamWAV = null


static func stream() -> AudioStreamWAV:
	if _stream != null:
		return _stream
	var n := int(RATE * DUR)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(RATE)
		var pulse := pow(0.5 + 0.5 * sin(TAU * 21.0 * t - PI * 0.5), 1.6)
		var carrier := sin(TAU * 55.0 * t) * 0.55 \
			+ sin(TAU * 110.0 * t) * 0.28 \
			+ sin(TAU * 165.0 * t) * 0.10 \
			+ sin(TAU * 260.5 * t) * 0.05
		var v := carrier * (0.30 + 0.70 * pulse) * 0.55
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = n
	_stream = s
	return s


## A soft positional voice for the lap: quiet, short range — a purr
## is a close-up sound.
static func make_player(parent: Node) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = "PurrVoice"
	p.stream = stream()
	p.unit_size = 1.2
	p.max_distance = 7.0
	p.volume_db = -15.0
	parent.add_child(p)
	return p
