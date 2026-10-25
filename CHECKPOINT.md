# CHECKPOINT — realism-pass-1 (box reboot, 2026-10-24 ~22:51 ADT)

Written mid-flight for a box reboot. Everything below is COMMITTED
but UNVERIFIED unless it says otherwise.

## State of play
- Branch: realism-pass-1 (off main 6b221d7). PR #12 open, WIP, DO NOT MERGE
  (coordinator merges after the playtest fix wave, in order).
- BEFORE shot set: captured, eyeballed, archived at
  ~/workspace/kvp-revival/realism-pass/before/ (Muse VM) and as
  godot3d/screenshots/realism_*.png in this clone.
- A full suite battery was RUNNING when the reboot hit
  (PID 368846, log ~/pvk-realism-battery1.log, per-suite /tmp/battery_*.log).
  Its results are UNKNOWN — re-run the whole battery after reboot.

## Per scope area
1. Cat locomotion — BUILT (cat_kit/cat.gd): _update_pose() locomotion
   layer (speed-blended walk/trot/bound gait offsets, stride bob/roll,
   turn lean, accel stretch, landing settle, head stabilisation),
   _update_tail() lagged 9-seg follow-through curve, _update_ears()
   micro-motion + flicks, idle repertoire (stand -> sit -> groom on a
   17 s cycle, interruptible), pounce/airborne leg shapes. Physics,
   catch, DuoSystem, ZoneManager untouched. NOT yet suite-verified.
2. Cat coats — BUILT: seeded baked textures (_bake_coat_texture):
   Aggie tortie blend on torso/chest/haunches/skull (albedo_color kept
   == palette base), Willie saddle soft shading + stripe shells lerped
   30% toward ginger. Palette/scale asserts expected safe. Unverified.
3. Other animals — BUILT: squirrel bounding gait + tail arc (flee/hop),
   bird flap/glide cycle + landing flare, dog pivot-leg trot by ground
   speed, rat scurry strides + pivoting tail drag, raccoon waddle
   roll + bounce (mother + kits). Animation-layer only. Unverified.
4. World detail — BUILT: main.gd _dress_yard (grass tufts, flowers,
   south-fence hedge, door frame, window sills/muntins, corner boards,
   eaves fascia, porch posts + step); outside_system frontage (road
   wear, worn edge lines, sidewalk cracks, lawn tufts, hedge tops);
   house_builder hub (living-room plank strips, kitchen tile checker
   clear of the stairwell, wainscot + picture frames). No statics,
   no layout/HouseSpec changes. Node deltas not yet counted.

## New tests
- tests/test_anim.gd + .tscn: deterministic _update_pose stepping
  (gait phase vs speed, leg swing arc, diagonal pairing, tail tip >
  base travel under turn, idle stand->sit->groom + interrupt, coat
  texture variance + palette albedos). Written, never run to completion.

## Remaining after reboot (in order)
1. Re-run import + full battery (smoke 52, duo 51, massey 61,
   basement 53, attic 49, outside 67, occupants 51 + test_anim);
   fix any fallout (watch: rat _process var `spd` scope, dog trot
   anchor, cat.gd parse).
2. Eyeball pass on a live run (shots tool res://tools/realism_shots.tscn,
   identical staging) -> AFTER set to
   ~/workspace/kvp-revival/realism-pass/after/; verify sit pitch sign,
   turn lean direction, Aggie mottle read; fix and re-shoot as needed.
3. git fetch; rebase onto then-current main (fix wave may have merged);
   hand-resolve conflicts (expect cat.gd adjacency at most); re-run battery.
4. Push final, update PR #12 body with results + node deltas. DO NOT MERGE.
5. Close-out survivor sweep: recorded PIDs + pgrep -af godot scoped to
   ~/pvk-realism-work must be empty.
