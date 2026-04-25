class_name EventSelector
extends RefCounted

## --- Event Selector ---
## Picks one EventData for the player to encounter at the given ring.
## Tracks drawn ids in GameState.used_event_ids for no-repeat logic.
## Do NOT call GameState.save() here — save happens in MapManager.

static func pick_for_node(ring: String) -> EventData:
	var pool: Array[EventData] = EventLibrary.all_events_for_ring(ring)

	if pool.is_empty():
		push_warning("EventSelector: no events authored for ring '%s'" % ring)
		return EventLibrary.get_event("")

	var unseen: Array[EventData] = []
	for e in pool:
		if not GameState.used_event_ids.has(e.id):
			unseen.append(e)

	# Fallback: all ring events seen this run — silently reset by drawing from full pool
	var candidates: Array[EventData] = unseen if not unseen.is_empty() else pool

	var chosen: EventData = candidates[randi() % candidates.size()]
	GameState.used_event_ids.append(chosen.id)
	return chosen
