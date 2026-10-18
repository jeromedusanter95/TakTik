class_name SoundPlayer
extends SoundOutput
## Plays the cues the screens ask for, unless the player muted the sound.
## Builds every cue once, and keeps a few voices so cues can overlap.

const VOICES: int = 4

var _preferences: PlayerPreferences = null
var _streams: Dictionary[SoundCue.Id, AudioStreamWAV] = {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0


func _ready() -> void:
	for cue: SoundCue.Id in SoundCue.Id.values():
		_streams[cue] = SynthSounds.build(cue)
	for index: int in VOICES:
		var voice: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(voice)
		_voices.append(voice)


func use_preferences(preferences: PlayerPreferences) -> void:
	_preferences = preferences


func play(cue: SoundCue.Id) -> void:
	if _preferences != null and not _preferences.sound_on:
		return
	if _voices.is_empty():
		return
	var voice: AudioStreamPlayer = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = _streams[cue]
	voice.play()
