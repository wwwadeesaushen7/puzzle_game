extends SceneTree
var checks := 0
var failures := 0
func _init() -> void:
	call_deferred("run")
func expect(condition: bool,message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
func run() -> void:
	var progress: Node = root.get_node("Progress")
	var backup: Dictionary = progress.data.duplicate(true)
	progress.data = progress.defaults()
	progress.session_abilities = 0
	var result: Dictionary = progress.complete(1,6,1)
	expect(result.stars == 3 and result.reward == 60,"First clear awards stars and golden reward")
	expect(progress.data.unlocked == 2,"Next level unlocks")
	var coins: int = progress.data.coins
	result = progress.complete(1,6,1)
	expect(result.reward == 0 and progress.data.coins == coins,"Replay cannot farm first-clear rewards")
	progress.session_abilities = 3
	result = progress.complete(2,10,0)
	expect(result.stars == 2,"Star rating accounts for abilities")
	progress.session_abilities = 0
	result = progress.complete(2,10,0)
	expect(result.reward == 15,"Improving stars rewards only the improvement")
	expect(not progress.spend(999999),"Insufficient coins cannot be spent")
	progress.complete(30,18,0,"2026-10-29")
	expect(progress.data.unlocked == 3,"Daily does not unlock standard expeditions")
	progress.save()
	var expected: Dictionary = progress.data.duplicate(true)
	progress.data = progress.defaults()
	progress.load_save()
	expect(progress.data == expected,"JSON save roundtrip preserves progress and settings")
	progress.save() # backup now also contains a valid copy of expected
	var broken := FileAccess.open("user://progress.json",FileAccess.WRITE)
	broken.store_string("{interrupted write")
	broken.close()
	progress.data = progress.defaults()
	progress.load_save()
	expect(progress.data == expected,"Corrupt current save recovers from backup")
	progress.data = backup
	progress.save()
	print("PROGRESS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
