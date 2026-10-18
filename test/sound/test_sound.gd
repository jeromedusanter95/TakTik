extends GutTest
## Every cue has a sound, the player stays quiet once muted, and the game
## screen marks its moments with cues.

const MemoryPreferenceStore: GDScript = preload("res://test/preferences/memory_preference_store.gd")
const RecordingSoundOutput: GDScript = preload("res://test/sound/recording_sound_output.gd")
const MatchScreenScene: PackedScene = preload("res://game/match/match_screen.tscn")


func test_every_cue_is_a_short_mono_sound() -> void:
	for cue: SoundCue.Id in SoundCue.Id.values():
		var stream: AudioStreamWAV = SynthSounds.build(cue)
		assert_gt(stream.data.size(), 0, "cue %d" % cue)
		assert_false(stream.stereo)
		assert_lt(stream.get_length(), 1.5, "cue %d is short" % cue)


func test_the_sound_choice_is_saved() -> void:
	var store: MemoryPreferenceStore = MemoryPreferenceStore.new()
	var preferences: PlayerPreferences = PlayerPreferences.new(store, "en", false)
	assert_true(preferences.sound_on, "sound is on at first")
	preferences.set_sound_on(false)
	assert_eq(store.values["sound"], "no")
	assert_false(PlayerPreferences.new(store, "en", false).sound_on)


func test_a_muted_player_plays_nothing() -> void:
	var preferences: PlayerPreferences = PlayerPreferences.new(_store(), "en", false)
	var player: SoundPlayer = SoundPlayer.new()
	add_child_autofree(player)
	player.use_preferences(preferences)
	preferences.set_sound_on(false)
	player.play(SoundCue.Id.MOVE)
	for voice: Node in player.get_children():
		assert_false((voice as AudioStreamPlayer).playing)


func test_the_sound_toggle_flips_the_choice() -> void:
	var preferences: PlayerPreferences = PlayerPreferences.new(_store(), "en", false)
	var toggle: SoundToggle = SoundToggle.new()
	add_child_autofree(toggle)
	toggle.use_preferences(preferences)
	toggle.pressed.emit()
	assert_false(preferences.sound_on)
	assert_eq(toggle.icon, SoundToggle.SoundOffIcon)


func test_the_game_screen_marks_moves_fights_turns_and_the_end() -> void:
	var screen: MatchScreen = MatchScreenScene.instantiate()
	add_child_autofree(screen)
	var sound: RecordingSoundOutput = RecordingSoundOutput.new()
	add_child_autofree(sound)
	screen.use_sound(sound)
	screen.play_move(PublicMoveEvent.of_move(Side.Id.RED, Move.new(Vector2i(0, 2), Vector2i(0, 3))))
	var fight: PublicMoveEvent = PublicMoveEvent.of_move(
		Side.Id.RED, Move.new(Vector2i(1, 2), Vector2i(1, 3))
	).with_fight(PieceType.Id.KNIGHT, PieceType.Id.SOLDIER, FightOutcome.Id.ATTACKER_WINS)
	screen.play_move(fight)
	screen.play_turn_banner()
	screen.add_chat("Bob", "Hello!", false)
	screen.add_chat("You", "Hi!", true)
	var view: MatchResultView = MatchResultView.new()
	view.mood = MatchResultView.Mood.DEFEAT
	screen.show_result(view)
	assert_eq(sound.played, [
		SoundCue.Id.MOVE, SoundCue.Id.FIGHT, SoundCue.Id.TURN, SoundCue.Id.CHAT, SoundCue.Id.DEFEAT,
	] as Array[SoundCue.Id])
	await wait_seconds(BoardMotion.FIGHT_SECONDS + 0.2)
	assert_has(sound.played, SoundCue.Id.CAPTURE)


func _store() -> MemoryPreferenceStore:
	return MemoryPreferenceStore.new()
