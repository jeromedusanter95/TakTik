class_name Bot
extends RefCounted
## A computer opponent playing one side. It only ever receives a PlayerView
## and PublicMoveEvents, so it cannot see Hidden Pieces (ADR 0002).
##
## Contract used by the match screen:
## 1. [method begin] once, when play starts.
## 2. [method observe] after every Move, by either side.
## 3. On its turn, [method start_thinking], then call BotThinking.step() once
##    per frame until BotThinking.is_done(), then play
##    BotThinking.chosen_move().

var _profile: BotProfile
var _side: Side.Id
var _rng: RandomNumberGenerator


func _init(profile: BotProfile, side: Side.Id, rng: RandomNumberGenerator) -> void:
	_profile = profile
	_side = side
	_rng = rng


func profile() -> BotProfile:
	return _profile


func side() -> Side.Id:
	return _side


func begin(_view: PlayerView) -> void:
	pass


func observe(_event: PublicMoveEvent) -> void:
	pass


func start_thinking(view: PlayerView) -> BotThinking:
	return BotThinking.new(view, _rng)
