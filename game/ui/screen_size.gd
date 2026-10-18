class_name ScreenSize
extends RefCounted
## The size of the page in CSS pixels on the web, which the layout
## breakpoints are written in; the window size elsewhere.


static func css_size(window: Window) -> Vector2:
	if OS.has_feature("web"):
		var width: float = _number(JavaScriptBridge.eval("window.innerWidth", true))
		var height: float = _number(JavaScriptBridge.eval("window.innerHeight", true))
		if width > 0.0 and height > 0.0:
			return Vector2(width, height)
	return Vector2(window.size)


## [param value] as a number, or 0 when it is not one.
static func _number(value: Variant) -> float:
	if value is int:
		var whole: int = value
		return whole
	if value is float:
		var real: float = value
		return real
	return 0.0
