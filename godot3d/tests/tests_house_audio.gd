extends Node
## Voices, the mouse mix, and the manner pose fallback.
## Run: godot --headless --path godot3d res://tests/tests_house_audio.tscn

const CatScript := preload("res://cat_kit/cat.gd")

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


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _run() -> void:
	print("HOUSE AUDIO")
	var kinds: Array[String] = ["meow", "chirp", "chatter", "trill", "purr", "hiss", "scrabble", "squeak", "scurry", "alarm", "wingbeat", "creak", "fridge", "wind", "drip"]
	for kind in kinds:
		var stream := HouseAudio.stream(kind)
		check(stream != null and stream.get_length() > 0.05, "%s ogg loads (%.2fs)" % [kind, stream.get_length() if stream != null else -1.0])
		var web_n := HouseAudio.file_bytes("web", kind)
		var desk_n := HouseAudio.file_bytes("desktop", kind)
		check(web_n > 0 and web_n <= desk_n, "%s web ogg is the smaller file (%d <= %d)" % [kind, web_n, desk_n])
	check(not HouseAudio.uses_low_bitrate(), "desktop playback is the higher-rate folder")
	check(HouseAudio.WEB_BITRATE == 24 and HouseAudio.DESKTOP_BITRATE == 64, "web is 24 kbit/s and desktop is 64")
	var squeak_mix: Dictionary = HouseAudio.MIX["squeak"]
	var fridge_mix: Dictionary = HouseAudio.MIX["fridge"]
	check(float(squeak_mix["reach"]) == HouseAudio.MOUSE_REACH and HouseAudio.MOUSE_REACH < 8.0, "a squeak carries a stalk, not the whole house")
	check(float(squeak_mix["db"]) > float(fridge_mix["db"]) + 12.0, "the fridge sits well under a mouse squeak")
	var mouse := PvKMouse.new()
	add_child(mouse)
	await _frames(2)
	var voice := mouse.get_node_or_null("Voice_squeak") as AudioStreamPlayer3D
	check(voice != null and is_equal_approx(voice.max_distance, HouseAudio.MOUSE_REACH), "the mouse squeak is positional inside the stalk reach")
	var scurry := mouse.get_node_or_null("Voice_scurry") as AudioStreamPlayer3D
	check(scurry != null and scurry.stream is AudioStreamOggVorbis and (scurry.stream as AudioStreamOggVorbis).loop, "scurry loops")
	var purr := HouseAudio.make_player(self, "purr", true)
	check(purr.stream is AudioStreamOggVorbis and (purr.stream as AudioStreamOggVorbis).loop, "the purr loops")

	print("MANNER POSES")
	var rig := _hunyuan_names()
	add_child(rig)
	var mapped := CatBoneMap.resolve(rig)
	check(int(mapped.get("head", -1)) == rig.find_bone("Head"), "Head maps to the head role")
	check(int(mapped.get("jaw", -1)) == rig.find_bone("Jaw"), "Jaw maps to the jaw role")
	check(int(mapped.get("tail", -1)) == rig.find_bone("Tail"), "Tail maps to the tail role")
	check(int(mapped.get("arm_l", -1)) == rig.find_bone("LeftArm"), "LeftArm maps to the near front leg")
	check(int(mapped.get("paw_l", -1)) == rig.find_bone("LeftHand"), "LeftHand maps to the front paw")
	check(int(mapped.get("thigh_l", -1)) == rig.find_bone("LeftUpLeg"), "LeftUpLeg maps to the thigh")
	check(int(mapped.get("ear_l", -1)) == rig.find_bone("LeftEar"), "LeftEar maps to the left ear")
	var chain: Array = mapped.get("tail_chain", [])
	check(chain.size() == 3, "the tail chain keeps every tail bone (%d)" % chain.size())

	var cat = CatScript.new()
	add_child(cat)
	await _frames(3)
	var sculpt = cat.get("_sculpt")
	var sk: Skeleton3D = sculpt.skeleton if sculpt != null else null
	check(sk != null, "willie still has a skeleton to pose")
	if sk != null:
		var live := CatBoneMap.resolve(sk)
		check(int(live.get("head", -1)) == sk.find_bone("head"), "the house sculpt head still resolves")
		check(int(live.get("tail", -1)) == sk.find_bone("tail00"), "the house sculpt tail still resolves")
		check(int(live.get("jaw", -1)) == sk.find_bone("jaw"), "the house sculpt jaw still resolves")
		var clips: Dictionary = cat.manner_clips
		check(clips.is_empty(), "this rig has no manner clips, so the fallback owns them")
		var tip := int(live.get("tail_tip", -1))
		sk.reset_bone_poses()
		var rest_y := _tip_y(sk, tip)
		CatMannerPose.apply(sk, live, "greet", 1.0, 0.2)
		var up_y := _tip_y(sk, tip)
		check(up_y > rest_y + 0.02, "a tail-up greeting lifts the tail (%.3f -> %.3f)" % [rest_y, up_y])
		sk.reset_bone_poses()
		var jaw := int(live.get("jaw", -1))
		var before := sk.get_bone_pose_rotation(jaw).get_angle() if jaw >= 0 else 0.0
		CatMannerPose.apply(sk, live, "chatter", 1.0, 0.5)
		var after := sk.get_bone_pose_rotation(jaw).get_angle() if jaw >= 0 else 0.0
		check(jaw >= 0 and after > before + 0.05, "chatter moves the jaw (%.3f -> %.3f)" % [before, after])
		sk.reset_bone_poses()
		var spine := int(live.get("spine_b", -1))
		var ear := int(live.get("ear_l", -1))
		var still := sk.get_bone_pose_rotation(spine) if spine >= 0 else Quaternion.IDENTITY
		var ear_still := sk.get_bone_pose_rotation(ear) if ear >= 0 else Quaternion.IDENTITY
		CatMannerPose.apply_life(sk, live, 0.6, 1.0, 1.0, 0.4, 0.0, 0.3, -0.1)
		var breathed := sk.get_bone_pose_rotation(spine) if spine >= 0 else Quaternion.IDENTITY
		var ear_turned := sk.get_bone_pose_rotation(ear) if ear >= 0 else Quaternion.IDENTITY
		check(spine >= 0 and still.angle_to(breathed) > 0.01, "idle breath moves the chest")
		check(ear >= 0 and ear_still.angle_to(ear_turned) > 0.05, "a nearby sound turns an ear")
		cat.manner = "wiggle"
		cat.manner_k = 1.0
		cat.manner_phase = 0.4
		await _frames(2)
		var wag_bone := int(live.get("tail_tip", tip))
		var wiggling := _tip_at(sk, wag_bone)
		cat.manner_clips = {"wiggle": true}
		await _frames(2)
		var clipped := _tip_at(sk, wag_bone)
		check(wiggling.distance_to(clipped) > 0.004, "the fallback steps aside when a wiggle clip exists")
	var cat_voice := cat.get_node_or_null("CatVoice") as CatVoice
	check(cat_voice != null and cat_voice.get_node_or_null("Voice_meow") != null, "the cat carries a positional meow")
	cat.play_meow()
	var meow: AudioStreamPlayer3D = null
	if cat_voice != null:
		meow = cat_voice.get_node_or_null("Voice_meow") as AudioStreamPlayer3D
	check(meow != null and meow.playing, "play_meow speaks the ogg")

	print("HOUSE AUDIO DONE: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _tip_at(sk: Skeleton3D, idx: int) -> Vector3:
	if idx < 0:
		return Vector3.ZERO
	return sk.to_global(sk.get_bone_global_pose(idx).origin)


func _tip_y(sk: Skeleton3D, idx: int) -> float:
	if idx < 0:
		return 0.0
	return sk.to_global(sk.get_bone_global_pose(idx).origin).y


func _hunyuan_names() -> Skeleton3D:
	var sk := Skeleton3D.new()
	sk.name = "HunyuanNames"
	var specs: Array[String] = [
		"Hips", "Spine", "Spine1", "Spine2", "Neck", "Head", "Jaw", "LeftEar", "RightEar",
		"LeftArm", "LeftForeArm", "LeftHand", "RightArm", "RightForeArm", "RightHand",
		"LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg", "RightFoot",
		"Tail", "Tail1", "Tail2",
	]
	var parent_of := {
		"Spine": "Hips", "Spine1": "Spine", "Spine2": "Spine1", "Neck": "Spine2",
		"Head": "Neck", "Jaw": "Head", "LeftEar": "Head", "RightEar": "Head",
		"LeftArm": "Spine2", "LeftForeArm": "LeftArm", "LeftHand": "LeftForeArm",
		"RightArm": "Spine2", "RightForeArm": "RightArm", "RightHand": "RightForeArm",
		"LeftUpLeg": "Hips", "LeftLeg": "LeftUpLeg", "LeftFoot": "LeftLeg",
		"RightUpLeg": "Hips", "RightLeg": "RightUpLeg", "RightFoot": "RightLeg",
		"Tail": "Hips", "Tail1": "Tail", "Tail2": "Tail1",
	}
	for bone_name in specs:
		var idx := sk.add_bone(bone_name)
		sk.set_bone_rest(idx, Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 0)))
	for bone_name in parent_of.keys():
		sk.set_bone_parent(sk.find_bone(bone_name), sk.find_bone(str(parent_of[bone_name])))
	return sk
