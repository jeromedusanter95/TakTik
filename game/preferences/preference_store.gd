@abstract
class_name PreferenceStore
extends RefCounted
## Remembers the player's choices between two visits, as text by name.


## The value saved under [param key], or an empty String when none was saved.
@abstract func load_value(key: String) -> String


@abstract func save_value(key: String, value: String) -> void
