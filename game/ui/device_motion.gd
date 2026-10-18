class_name DeviceMotion
extends RefCounted
## Whether the device asks for less motion. On the web this is the browser's
## prefers-reduced-motion setting; elsewhere the game cannot tell.


static func prefers_reduced_motion() -> bool:
	if not OS.has_feature("web"):
		return false
	var answer: Variant = JavaScriptBridge.eval(
		"window.matchMedia('(prefers-reduced-motion: reduce)').matches", true
	)
	return answer is bool and answer
