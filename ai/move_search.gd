class_name MoveSearch
extends RefCounted
## The search of one root Move, which MoveSearcher.advance can stop and
## resume anywhere in its subtree, so one frame never has to search the
## whole subtree at once.

var _frames: Array[SearchFrame] = []
var _score: int = 0
var _is_done: bool = false


func is_done() -> bool:
	return _is_done


## The exact score of the root Move for the side to move at the root. Only
## valid once [method is_done] is true.
func score() -> int:
	return _score


## False before the first frame is pushed and once the last one is popped.
func has_frames() -> bool:
	return not _frames.is_empty()


## The deepest position still being searched.
func top() -> SearchFrame:
	return _frames[-1]


func push(frame: SearchFrame) -> void:
	_frames.append(frame)


func pop() -> void:
	_frames.pop_back()


## Ends the search with [param root_score], already seen from the root.
func finish(root_score: int) -> void:
	_score = root_score
	_is_done = true
	_frames.clear()
