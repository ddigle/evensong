extends SceneTree
## Measures the torso / head anchors of the base body sheets (actors/rig_measure.gd) and writes
## res://actors/rig_anchors.gd.
##
##   godot --headless --path game --script res://tools/build_rig_anchors.gd
##
## Prints one "EVENSONG_ANCHORS <anim> <row> torso=... head=..." line per sheet row and
## "EVENSONG_ANCHORS saved <path> error=<n> md5=<hash>", exit 0 when saved. Same sheets -> same file
## (tests/test_actors.gd measures again and compares with the committed table).

const OUT_PATH: String = "res://actors/rig_anchors.gd"


func _initialize() -> void:
	var t0: int = Time.get_ticks_msec()
	var torso: Array[Array] = RigMeasure.measure_all(RigData.ANCHOR_TORSO)
	var head: Array[Array] = RigMeasure.measure_all(RigData.ANCHOR_HEAD)
	for anim: int in RigData.ANIM_NAMES.size():
		for row: int in RigData.ROWS:
			var t: Array = torso[anim]
			var h: Array = head[anim]
			print("EVENSONG_ANCHORS %s %s torso=%s head=%s" % [RigData.ANIM_NAMES[anim], RigData.DIR_NAMES[row],
				str(t[row]), str(h[row])])
	var source: String = RigMeasure.anchors_source(torso, head)
	var f: FileAccess = FileAccess.open(OUT_PATH, FileAccess.WRITE)
	var err: Error = FileAccess.get_open_error()
	if f != null:
		f.store_string(source)
		f.close()
	print("EVENSONG_ANCHORS saved %s error=%d md5=%s ms=%d" % [OUT_PATH, err, FileAccess.get_md5(OUT_PATH),
		Time.get_ticks_msec() - t0])
	quit(0 if err == OK else 1)
