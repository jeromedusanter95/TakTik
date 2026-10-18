@abstract
class_name SoundOutput
extends Node
## Where screens send their sound cues. Screens depend on this, never on the
## audio engine.


@abstract func play(cue: SoundCue.Id) -> void
