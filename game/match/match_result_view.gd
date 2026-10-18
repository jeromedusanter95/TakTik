class_name MatchResultView
extends RefCounted
## What the end of game modal shows: the title, why the game ended, the last
## Fight, what each side lost, and the two buttons.

enum Mood {
	## A win for the person looking, or a winner named on a shared device.
	VICTORY,
	DEFEAT,
	DRAW,
}

var mood: Mood = Mood.VICTORY
var title: String = ""
var reason: String = ""
## The Fight that ended the game, or the last one; null without any.
var final_fight: PublicMoveEvent = null
var red_losses: Array[PieceType.Id] = []
var green_losses: Array[PieceType.Id] = []
## "Red lost", or the player's name in place of the colour.
var red_loss_title: String = ""
var green_loss_title: String = ""
## The Piece shown above the title: the winner's King, or the loser's
## Princess, grey, on a defeat.
var hero_type: PieceType.Id = PieceType.Id.KING
var hero_side: Side.Id = Side.Id.RED
var primary_label: String = ""
var secondary_label: String = ""


## The modal for [param result], seen by [param viewer], or by both players
## of a shared device when [param shared_device].
static func of(
		result: GameResult,
		viewer: Side.Id,
		shared_device: bool,
		final_fight: PublicMoveEvent,
		red_losses: Array[PieceType.Id],
		green_losses: Array[PieceType.Id],
		names: Dictionary[Side.Id, String],
) -> MatchResultView:
	var view: MatchResultView = MatchResultView.new()
	view.reason = MatchNarrator.describe_reason(result)
	view.final_fight = final_fight
	view.red_losses = red_losses
	view.green_losses = green_losses
	view.red_loss_title = Translated.text(&"RESULT_LOST", {"name": names.get(Side.Id.RED, PieceNames.side_name(Side.Id.RED))})
	view.green_loss_title = Translated.text(&"RESULT_LOST", {"name": names.get(Side.Id.GREEN, PieceNames.side_name(Side.Id.GREEN))})
	if result.status == GameResult.Status.DRAW:
		view.mood = Mood.DRAW
		view.title = Translated.text(&"RESULT_TITLE_DRAW")
		view.hero_type = PieceType.Id.PRINCESS
		view.hero_side = viewer
		return view
	var winner: Side.Id = Side.Id.RED if result.status == GameResult.Status.RED_WINS else Side.Id.GREEN
	if shared_device:
		view.mood = Mood.VICTORY
		view.title = Translated.text(&"RESULT_TITLE_WINNER", {"side": PieceNames.side_name(winner)})
	elif winner == viewer:
		view.mood = Mood.VICTORY
		view.title = Translated.text(&"RESULT_TITLE_VICTORY")
	else:
		view.mood = Mood.DEFEAT
		view.title = Translated.text(&"RESULT_TITLE_DEFEAT")
	view.hero_type = PieceType.Id.KING if view.mood == Mood.VICTORY else PieceType.Id.PRINCESS
	view.hero_side = winner if view.mood == Mood.VICTORY else viewer
	return view
