class_name Languages
extends RefCounted
## The languages the game speaks, by locale code. Adding one takes a column in
## translations.csv and an entry here.

const ENGLISH: String = "en"

## Each language is named in itself, so anyone can find their own.
const _NATIVE_NAMES: Dictionary[String, String] = {
	"en": "English",
	"fr": "Français",
}


static func is_supported(code: String) -> bool:
	return _NATIVE_NAMES.has(code)


## The saved choice when there is one, else the device's language when the
## game speaks it, else English.
static func initial(saved: String, device: String) -> String:
	if is_supported(saved):
		return saved
	if is_supported(device):
		return device
	return ENGLISH


## The language after [param current], wrapping round, so a single button
## cycles through them all.
static func next(current: String) -> String:
	var codes: Array[String] = []
	codes.assign(_NATIVE_NAMES.keys())
	var index: int = codes.find(current)
	return codes[(index + 1) % codes.size()]


static func native_name(code: String) -> String:
	return _NATIVE_NAMES.get(code, code)
