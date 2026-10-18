extends SoundOutput
## A SoundOutput that remembers the cues it was asked to play, for tests.

var played: Array[SoundCue.Id] = []


func play(cue: SoundCue.Id) -> void:
	played.append(cue)
