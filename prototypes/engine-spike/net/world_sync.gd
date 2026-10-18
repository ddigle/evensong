extends Node2D
## Tile replication for the net spike: node "World" under the Net scene (same path on every
## instance). Host-authoritative:
## - clients only *request* "break wall at cell" (RPC to the host)
## - the host validates (TileWorld.validate_break), applies, and broadcasts the changed cells as
##   one packed delta buffer per physics tick, with a sequence number
## - a peer that connects first gets the whole map as zstd chunks. Snapshot and deltas share
##   reliable channel 1, so every later delta arrives after the snapshot. Deltas are absolute,
##   so one that the snapshot already contains is harmless.

const TileWorld := preload("res://net/tile_world.gd")
const TileView := preload("res://net/tile_view.gd")

signal snapshot_ready

var world: TileWorld = TileWorld.new()
var view: TileView = null
var is_host: bool = false
## Host: after host_generate(). Client: after the snapshot is complete.
var ready_for_play: bool = false
## Players by peer id (node names), for the reach check.
var players_root: Node = null
var initial_hash: String = ""

# host
var delta_seq: int = 0
var burst_flushed_msec: int = -1
var snapshot_sent_msec: int = -1
var host_stats: Dictionary = {
	"requests_ok": 0,
	"requests_rejected": 0,
	"rejected": {},
	"edits": 0,
	"delta_batches": 0,
	"delta_payload_bytes": 0,
	"snapshots_sent": 0,
	"snapshot_chunks": 0,
	"snapshot_raw_bytes": 0,
	"snapshot_compressed_bytes": 0,
	"snapshot_build_ms": 0.0,
	"burst_cells": 0,
	"burst_payload_bytes": 0,
	"generate_ms": 0.0,
}
var _pending: PackedByteArray = PackedByteArray()
var _pending_has_burst: bool = false

# client
var snapshot_hash: String = ""
var client_stats: Dictionary = {
	"snapshot_chunks": 0,
	"snapshot_raw_bytes": 0,
	"snapshot_compressed_bytes": 0,
	"snapshot_apply_ms": 0.0,
	"snapshot_decode_ms": 0.0,
	"snapshot_view_ms": 0.0,
	"snapshot_bad_chunks": 0,
	"delta_batches": 0,
	"delta_cells": 0,
	"seq_gaps": 0,
	"early_batches": 0,
	"forged_sent": 0,
}
var _expected_seq: int = -1
var _early: Array = []
var _snapshot_t0: int = 0


func _init() -> void:
	name = "World"
	view = TileView.new()
	add_child(view)


func host_generate(size: int, seed_value: int) -> void:
	is_host = true
	var t0: int = Time.get_ticks_usec()
	world.resize(size, size)
	world.generate(seed_value)
	view.rebuild(world)
	host_stats["generate_ms"] = (Time.get_ticks_usec() - t0) / 1000.0
	initial_hash = world.hash_hex()
	ready_for_play = true


# --- requests ----------------------------------------------------------------------------------

## Called by the local player's bot or input, on any instance.
func request_break(cell: Vector2i) -> void:
	if is_host:
		handle_break(multiplayer.get_unique_id(), cell)
	else:
		_rpc_request_break.rpc_id(1, cell)


@rpc("any_peer", "call_remote", "reliable", 1)
func _rpc_request_break(cell: Vector2i) -> void:
	if not is_host:
		return
	handle_break(multiplayer.get_remote_sender_id(), cell)


## Host: validate and apply. Returns "" or the reject reason.
func handle_break(peer: int, cell: Vector2i) -> String:
	var player: Node2D = null
	if players_root != null:
		player = players_root.get_node_or_null(str(peer)) as Node2D
	var reason: String = "no_player"
	if player != null:
		reason = world.validate_break(cell, player.position)
	if not reason.is_empty():
		host_stats["requests_rejected"] += 1
		var rejected: Dictionary = host_stats["rejected"]
		rejected[reason] = int(rejected.get(reason, 0)) + 1
		return reason
	host_stats["requests_ok"] += 1
	host_set(TileWorld.LAYER_WALL, cell, TileWorld.WALL_NONE)
	host_set(TileWorld.LAYER_ORE, cell, 0)
	return ""


## Host: change one cell and queue the delta.
func host_set(layer: int, c: Vector2i, value: int) -> bool:
	if not world.set_cell(layer, c, value):
		return false
	view.set_world_cell(layer, c, value)
	_pending = TileWorld.append_delta(_pending, layer, c, value)
	host_stats["edits"] += 1
	return true


## Host: `count` wall edits in one tick (toggle dirt/empty inside TileWorld.burst_rect).
func host_burst(count: int) -> int:
	var rect: Rect2i = world.burst_rect(count)
	var done: int = 0
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			if done >= count:
				break
			var c: Vector2i = Vector2i(x, y)
			var wall: int = world.get_cell(TileWorld.LAYER_WALL, c)
			var value: int = TileWorld.WALL_NONE if wall != TileWorld.WALL_NONE else TileWorld.WALL_DIRT
			if host_set(TileWorld.LAYER_WALL, c, value):
				done += 1
	host_stats["burst_cells"] += done
	_pending_has_burst = true
	return done


func _physics_process(_delta: float) -> void:
	if is_host and not _pending.is_empty():
		flush()


## Host: broadcast the queued deltas as one batch.
func flush() -> void:
	if _pending.is_empty():
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.get_peers().is_empty():
		_rpc_apply_deltas.rpc(delta_seq, _pending)
	host_stats["delta_batches"] += 1
	host_stats["delta_payload_bytes"] += _pending.size()
	if _pending_has_burst:
		host_stats["burst_payload_bytes"] = _pending.size()
		burst_flushed_msec = Time.get_ticks_msec()
		_pending_has_burst = false
	delta_seq += 1
	_pending = PackedByteArray()


## Test only: a client pretending to be the host. _rpc_apply_deltas is an "authority" RPC, so
## every receiver must refuse this; the sender never applies it (call_remote), so a receiver
## that accepted it would end with a different tile hash.
func forge_delta(cell: Vector2i) -> void:
	var buf: PackedByteArray = TileWorld.append_delta(PackedByteArray(), TileWorld.LAYER_WALL, cell, TileWorld.WALL_BEDROCK)
	_rpc_apply_deltas.rpc(delta_seq + 100000, buf)
	client_stats["forged_sent"] += 1


# --- snapshot ----------------------------------------------------------------------------------

## Host: send the whole map to one peer as compressed chunks.
func send_snapshot(peer: int) -> void:
	var t0: int = Time.get_ticks_usec()
	var chunks: Array = []
	var raw_total: int = 0
	var packed_total: int = 0
	for cy: int in world.chunks_y():
		for cx: int in world.chunks_x():
			var r: Rect2i = world.chunk_rect(cx, cy)
			var raw_size: int = r.size.x * r.size.y * TileWorld.LAYER_COUNT
			var data: PackedByteArray = world.compress_chunk(cx, cy)
			chunks.append([cx, cy, raw_size, data])
			raw_total += raw_size
			packed_total += data.size()
	host_stats["snapshot_build_ms"] = (Time.get_ticks_usec() - t0) / 1000.0
	_rpc_snapshot_begin.rpc_id(peer, world.width, world.height, chunks.size())
	for chunk: Array in chunks:
		_rpc_snapshot_chunk.rpc_id(peer, chunk[0], chunk[1], chunk[2], chunk[3])
	# Deltas still queued this tick are already in the snapshot; they go out as delta_seq.
	_rpc_snapshot_end.rpc_id(peer, delta_seq)
	snapshot_sent_msec = Time.get_ticks_msec()
	host_stats["snapshots_sent"] += 1
	host_stats["snapshot_chunks"] = chunks.size()
	host_stats["snapshot_raw_bytes"] = raw_total
	host_stats["snapshot_compressed_bytes"] = packed_total


@rpc("authority", "call_remote", "reliable", 1)
func _rpc_snapshot_begin(w: int, h: int, _chunk_count: int) -> void:
	_snapshot_t0 = Time.get_ticks_usec()
	ready_for_play = false
	if w < TileWorld.MIN_SIZE or h < TileWorld.MIN_SIZE or w > TileWorld.MAX_SIZE or h > TileWorld.MAX_SIZE:
		client_stats["snapshot_bad_chunks"] += 1
		return
	world.resize(w, h)
	for layer: TileMapLayer in view.map_layers:
		layer.clear()


@rpc("authority", "call_remote", "reliable", 1)
func _rpc_snapshot_chunk(cx: int, cy: int, raw_size: int, data: PackedByteArray) -> void:
	var t0: int = Time.get_ticks_usec()
	if not world.apply_compressed_chunk(cx, cy, data, raw_size):
		client_stats["snapshot_bad_chunks"] += 1
		return
	var t1: int = Time.get_ticks_usec()
	view.rebuild_rect(world, world.chunk_rect(cx, cy))
	client_stats["snapshot_decode_ms"] += (t1 - t0) / 1000.0
	client_stats["snapshot_view_ms"] += (Time.get_ticks_usec() - t1) / 1000.0
	client_stats["snapshot_chunks"] += 1
	client_stats["snapshot_raw_bytes"] += raw_size
	client_stats["snapshot_compressed_bytes"] += data.size()


@rpc("authority", "call_remote", "reliable", 1)
func _rpc_snapshot_end(next_seq: int) -> void:
	client_stats["snapshot_apply_ms"] = (Time.get_ticks_usec() - _snapshot_t0) / 1000.0
	snapshot_hash = world.hash_hex()
	_expected_seq = next_seq
	ready_for_play = true
	var early: Array = _early
	_early = []
	for batch: Array in early:
		_consume(batch[0], batch[1])
	snapshot_ready.emit()


@rpc("authority", "call_remote", "reliable", 1)
func _rpc_apply_deltas(seq: int, data: PackedByteArray) -> void:
	if not ready_for_play:
		client_stats["early_batches"] += 1
		_early.append([seq, data])
		return
	_consume(seq, data)


func _consume(seq: int, data: PackedByteArray) -> void:
	if seq < _expected_seq:
		return  # older than the snapshot
	if seq != _expected_seq:
		client_stats["seq_gaps"] += 1
	_expected_seq = seq + 1
	var touched: Array = world.apply_deltas(data)
	for cell: Array in touched:
		view.set_world_cell(cell[0], cell[1], cell[2])
	client_stats["delta_batches"] += 1
	client_stats["delta_cells"] += touched.size()
