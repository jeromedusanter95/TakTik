class_name PairedSeat
extends RefCounted
## The seat Quick Match gave this Guest in a new online game.

var game_id: String
var side: Side.Id
## The secret that proves to the referee this seat is ours.
var seat_token: String
var opponent: String
