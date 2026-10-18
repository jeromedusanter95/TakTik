class_name SynthSounds
extends RefCounted
## Builds the game's sound cues in code, from short notes with soft attacks
## and fading tails, so the game ships no audio files.

enum _Wave {
	SINE,
	TRIANGLE,
	SQUARE,
}

const MIX_RATE: int = 22_050
const _ATTACK_SECONDS: float = 0.006


## The sound of [param cue].
static func build(cue: SoundCue.Id) -> AudioStreamWAV:
	var samples: PackedFloat32Array = []
	match cue:
		SoundCue.Id.MOVE:
			samples = _note(330.0, 0.07, 0.35, _Wave.TRIANGLE)
			samples.append_array(_note(440.0, 0.06, 0.25, _Wave.TRIANGLE))
		SoundCue.Id.SWAP:
			samples = _note(392.0, 0.05, 0.25, _Wave.TRIANGLE)
			samples.append_array(_note(523.0, 0.05, 0.25, _Wave.TRIANGLE))
		SoundCue.Id.FIGHT:
			samples = _mix(_noise(0.12, 0.45), _note(110.0, 0.18, 0.5, _Wave.SQUARE))
		SoundCue.Id.CAPTURE:
			samples = _note(392.0, 0.08, 0.3, _Wave.SINE)
			samples.append_array(_note(262.0, 0.16, 0.3, _Wave.SINE))
		SoundCue.Id.TURN:
			samples = _note(523.0, 0.09, 0.3, _Wave.SINE)
			samples.append_array(_note(784.0, 0.16, 0.3, _Wave.SINE))
		SoundCue.Id.TICK:
			samples = _note(1_200.0, 0.03, 0.2, _Wave.SINE)
		SoundCue.Id.CHAT:
			samples = _note(880.0, 0.06, 0.2, _Wave.SINE)
			samples.append_array(_note(1_175.0, 0.08, 0.2, _Wave.SINE))
		SoundCue.Id.CHALLENGE:
			for repeat: int in 2:
				samples.append_array(_note(659.0, 0.08, 0.3, _Wave.TRIANGLE))
				samples.append_array(_note(988.0, 0.1, 0.3, _Wave.TRIANGLE))
		SoundCue.Id.VICTORY:
			for frequency: float in [523.0, 659.0, 784.0]:
				samples.append_array(_note(frequency, 0.11, 0.35, _Wave.TRIANGLE))
			samples.append_array(_note(1_047.0, 0.4, 0.35, _Wave.TRIANGLE))
		SoundCue.Id.DEFEAT:
			for frequency: float in [392.0, 330.0]:
				samples.append_array(_note(frequency, 0.16, 0.3, _Wave.SINE))
			samples.append_array(_note(262.0, 0.45, 0.3, _Wave.SINE))
	return _stream(samples)


static func _note(frequency: float, seconds: float, volume: float, wave: _Wave) -> PackedFloat32Array:
	var count: int = roundi(seconds * MIX_RATE)
	var samples: PackedFloat32Array = []
	samples.resize(count)
	for index: int in count:
		var time: float = float(index) / MIX_RATE
		var phase: float = fposmod(time * frequency, 1.0)
		var value: float = 0.0
		match wave:
			_Wave.SINE:
				value = sin(TAU * phase)
			_Wave.TRIANGLE:
				value = 4.0 * absf(phase - 0.5) - 1.0
			_Wave.SQUARE:
				value = 1.0 if phase < 0.5 else -1.0
		samples[index] = value * volume * _envelope(time, seconds)
	return samples


static func _noise(seconds: float, volume: float) -> PackedFloat32Array:
	var count: int = roundi(seconds * MIX_RATE)
	var samples: PackedFloat32Array = []
	samples.resize(count)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for index: int in count:
		var time: float = float(index) / MIX_RATE
		samples[index] = rng.randf_range(-1.0, 1.0) * volume * _envelope(time, seconds)
	return samples


## A quick rise, then an exponential fade to silence at [param seconds].
static func _envelope(time: float, seconds: float) -> float:
	var attack: float = clampf(time / _ATTACK_SECONDS, 0.0, 1.0)
	var fade: float = exp(-4.0 * time / seconds) * (1.0 - time / seconds)
	return attack * maxf(fade, 0.0)


static func _mix(first: PackedFloat32Array, second: PackedFloat32Array) -> PackedFloat32Array:
	var mixed: PackedFloat32Array = []
	mixed.resize(maxi(first.size(), second.size()))
	for index: int in mixed.size():
		var a: float = first[index] if index < first.size() else 0.0
		var b: float = second[index] if index < second.size() else 0.0
		mixed[index] = clampf(a + b, -1.0, 1.0)
	return mixed


static func _stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data: PackedByteArray = []
	data.resize(samples.size() * 2)
	for index: int in samples.size():
		data.encode_s16(index * 2, roundi(clampf(samples[index], -1.0, 1.0) * 32_767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
