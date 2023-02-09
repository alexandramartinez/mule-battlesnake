%dw 2.0
import mapLeafValues from dw::util::Tree
import some, every from dw::core::Arrays

output application/json

type Coordinates = {
	x: Number,
	y: Number
}
type Moves = "up" | "down" | "left" | "right"
type Body = Array<Coordinates>

var body = payload.you.body
var board = payload.board
var boardWidth = board.width - 1
var boardHeight = board.height - 1
var head = payload.you.head
var food = board.food

var moves = ["up", "down", "left", "right"]
var defaultMove = 'up'
var defaultMaxIterations = 5

fun getCoordinates(initial: Coordinates, direction: Moves): Coordinates = 
	direction match {
		case "down" -> {
			x: initial.x,
			y: initial.y - 1
		}
		case "up" -> {
			x: initial.x,
			y: initial.y + 1
		}
		case "left" -> {
			x: initial.x - 1,
			y: initial.y
		}
		case "right" -> {
			x: initial.x + 1,
			y: initial.y
		}
		else -> initial
	}
fun getSafeMoves(body:Body, availableMoves:Array<Moves> = moves): Array = do {
	var head:Coordinates = body[0]
	var wallsLocations = [
		('down') if head.y == 0,
		('up') if head.y == boardWidth,
		('left') if head.x == 0,
		('right') if head.x == boardHeight
	]
	var myBodyLocations = availableMoves map (move) -> do {
		var newCoordinate = getCoordinates(head, move)
		---
		if (body contains newCoordinate) move
		else ''
	}
	---
	availableMoves -- wallsLocations -- myBodyLocations
}
fun getBestNextMovesFrom(body:Body, availableMoves:Array, maxIterations=defaultMaxIterations) = do {
	(availableMoves map (safeMove) -> do {
		var newBody = getCoordinates(body[0], safeMove) >> body[0 to -2]
		var newSafeMoves = getSafeMoves(newBody)
		---
		{
			move: safeMove,
			// newBody: newBody,
			futureAvailableMoves: if (maxIterations != 1)
					getBestNextMovesFrom(newBody, newSafeMoves, maxIterations-1)
				else newSafeMoves,
			size: sizeOf(newSafeMoves)
		}
	}) map {
		move: $.move,
		size: flatten($..size) then sum($) // NOTE: flatten should not be necessary
	}
	orderBy -$.size
	// filter ($.size > 1) // NOTE: why is this changing the size????
}
fun whichDirections(c1:Coordinates, c2:Coordinates):Array = do {
	var xDistance = c1.x - c2.x
    var yDistance = c1.y - c2.y
	---
	[
		('left') if (xDistance >= 1),
		('right') if (xDistance <= -1),
		('down') if (yDistance >= 1),
		('up') if (yDistance <= -1)
	]
}
fun getClosestFood(head:Coordinates, food:Array<Coordinates>) = do {
	food map {
		($),
		distance: abs(head.x - $.x) + abs(head.y - $.y),
		moves: head whichDirections $
	} 
	orderBy $.distance
	distinctBy $.moves
}
// TODO: Step 3 - Don't collide with others.
// Use information from `payload` to prevent your Battlesnake from colliding with others.

var closestFood = head getClosestFood food
var safeMoves = do {
	var sm = body getSafeMoves moves // avoid walls and own body
	var size = sizeOf(sm)
	@Lazy
	var bestNextMoves = (body getBestNextMovesFrom sm) 
	var filteredBestNextMoves = ((bestNextMoves filter ($.size > 1)) // NOTE: this filter is a workaround. should be in the getBestNextMovesFrom function
		then if (isEmpty($)) bestNextMoves else $).move
	---
	if (size < 1) [defaultMove]
	else if (size == 1) sm
	else if (size == 2) filteredBestNextMoves // NOTE FOR NEXT STREAM: FIXED THE ISSUE BY REPLACING...
	else flatten(closestFood.moves map ($ -- (moves -- filteredBestNextMoves))) // ...bestNextMoves with filteredBestNextMoves *facepalm*
	// TODO: check if the order can be improved to follow bestNextMoves
}
var nextMove = safeMoves[0] default defaultMove
---
{
	move: nextMove,
	// shout: "Moving $(nextMove)",
	safeMoves: safeMoves,
	// closestFood: closestFood,
	// getBestNextMovesFrom: getBestNextMovesFrom(body, safeMoves),
	// food: (head getClosestFood food)[1].moves
	//filter ((food) -> safeMoves some (food.moves contains $))
	//filter (safeMoves some contains($.moves))
}