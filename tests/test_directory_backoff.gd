extends SceneTree

const NET := preload("res://scripts/oxenwar_network.gd")

func _init() -> void:
	var failures: Array[String] = []
	if not NET.directory_sync_due(false, 0, 0.0, false): failures.append("first sync is immediate")
	if NET.directory_sync_due(true, 0, 1.0, true): failures.append("no sync 1s after a change")
	if not NET.directory_sync_due(true, 0, 2.0, true): failures.append("changed state syncs after 2s")
	if NET.directory_sync_due(true, 0, 24.0, false): failures.append("no heartbeat before 25s")
	if not NET.directory_sync_due(true, 0, 25.0, false): failures.append("heartbeat at 25s")
	# A failing sync (e.g. HTTP 403) must back off, even when the state is 'changed' and nothing was ever saved.
	for failures_count in [1, 2, 3, 6]:
		var wait: float = NET.directory_retry_interval(failures_count)
		if NET.directory_sync_due(true, failures_count, wait - 0.5, true): failures.append("no retry before %.0fs after %d failures" % [wait, failures_count])
		if not NET.directory_sync_due(true, failures_count, wait, true): failures.append("retry at %.0fs after %d failures" % [wait, failures_count])
	if NET.directory_retry_interval(1) != 10.0 or NET.directory_retry_interval(2) != 20.0: failures.append("backoff doubles from 10s")
	if NET.directory_retry_interval(50) != 300.0: failures.append("backoff capped at 300s")
	if failures.is_empty():
		print("PASS: directory sync is immediate once, then paced, and backs off after failures")
		quit(0)
	else:
		for message in failures: print("FAIL: ", message)
		quit(1)
