@abstract
class_name BotThinking
extends RefCounted
## One Bot turn being computed, spread over several frames so the screen stays
## responsive (the web build runs on a single thread).


## Does one slice of work. Call once per frame until [method is_done].
@abstract func step() -> void


@abstract func is_done() -> bool


## The Move to play. Only valid once [method is_done] is true; null only when
## the Bot has no legal Move, which means the game is already over.
@abstract func chosen_move() -> Move
