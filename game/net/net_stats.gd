class_name NetStats
extends RefCounted
## Traffic per situation. Every tick adds the transport's byte counts since the last tick to a
## bucket named "<moving>/<players>" (players walking / players in the session, as the host sees
## them). Rates per bucket = bytes / bucket time. Bytes are ENet's (its headers included); "wire"
## adds the UDP/IPv4 header (28 B) per datagram.

const UDP_IP_HEADER: int = 28

class Bucket:
	extends RefCounted
	var ticks: int = 0
	var sent: int = 0
	var received: int = 0
	var packets: int = 0

	func seconds() -> float:
		return ticks * Config.NET_TICK

	func to_dict() -> Dictionary:
		var sec: float = maxf(seconds(), Config.NET_TICK)
		return {
			"sec": snappedf(seconds(), 0.001), "sent_bps": snappedf(sent / sec, 0.1),
			"wire_sent_bps": snappedf((sent + UDP_IP_HEADER * packets) / sec, 0.1),
			"packets_ps": snappedf(packets / sec, 0.1), "received_bps": snappedf(received / sec, 0.1),
			"sent": sent, "received": received, "packets": packets,
		}


var buckets: Dictionary[String, Bucket] = {}
var total: Bucket = Bucket.new()


func add(key: String, stats: NetTransport.Stats) -> void:
	if not buckets.has(key):
		buckets[key] = Bucket.new()
	var b: Bucket = buckets[key]
	for target: Bucket in [b, total]:
		target.ticks += 1
		target.sent += maxi(stats.sent_bytes, 0)
		target.received += maxi(stats.received_bytes, 0)
		target.packets += maxi(stats.sent_packets, 0)


func to_dict() -> Dictionary:
	var out: Dictionary = {"total": total.to_dict()}
	for key: String in buckets:
		out[key] = buckets[key].to_dict()
	return out
