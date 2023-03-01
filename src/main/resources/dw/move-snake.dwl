%dw 2.0
import drop from dw::core::Arrays

output application/json

type Coordinates = {
	x: Number,
	y: Number
}
type Moves = "up" | "down" | "left" | "right"
type Body = Array<Coordinates>

var head = payload.you.head
var body = payload.you.body
var length = payload.you.length

var board = payload.board
var boardWidth = board.width - 1
var boardHeight = board.height - 1
var food = board.food
var otherSnakes = board.snakes filter ($.id != payload.you.id)
var otherSnakesBodies = flatten(otherSnakes.body) //flatten(otherSnakes.body map ($ drop 1))
var otherSnakesHeads = otherSnakes map {
    ($.head),
    length: $.length
}

var moves = ["up", "down", "left", "right"]
var defaultMove = 'up'
var defaultMaxIterations = 7

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
fun getDistance(c1:Coordinates, c2:Coordinates):Number =
	abs(c1.x - c2.x) + abs(c1.y - c2.y)
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
	var snakesBodies = if (isEmpty(otherSnakesBodies)) []
		else availableMoves map (move) -> do {
			var newCoordinate = getCoordinates(head, move)
			---
			if (otherSnakesBodies contains newCoordinate) move
			else ''
		}
	---
	availableMoves -- wallsLocations -- myBodyLocations -- snakesBodies

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
fun getClosestFood(head:Coordinates, food:Array<Coordinates>) = do {
	food map {
		($),
		distance: head getDistance $,
		moves: head whichDirections $
	} 
	orderBy $.distance
	distinctBy $.moves
}

var snakesHeads = otherSnakesHeads map {
		($),
		distance: head getDistance $,
		directions: head whichDirections $
	} filter ($.distance <= 2 and $.length >= length)
	then flatten($.directions)
	then $ default []
var closestFood = head getClosestFood food
var safeMoves = do {
	var sm = getSafeMoves(body, moves) //-- snakesHeads
	var size = sizeOf(sm)
	@Lazy
	var bestNextMoves = (body getBestNextMovesFrom sm) 
	@Lazy
	var filteredBestNextMoves = (do {
		var avgSize = avg(bestNextMoves.size)
		---
		if (
			(bestNextMoves[0].size - bestNextMoves[-1].size) > avgSize
		) bestNextMoves filter ($.size > avgSize)
		else (bestNextMoves filter ($.size > 1)) // NOTE: this filter is a workaround. should be in the getBestNextMovesFrom function
		then if (isEmpty($)) bestNextMoves else $
	}).move
	@Lazy
	var prioritizedMoves = flatten(
		closestFood.moves map (
			$ -- (moves -- filteredBestNextMoves)
		)
	) -- snakesHeads
	fun removeSnakesHeads(mvs) = do {
		var newmvs = mvs -- snakesHeads
		---
		if (isEmpty(newmvs)) mvs else newmvs
	}
	---
	if (size < 1) [defaultMove]
	else if (size == 1) sm
	else if (size == 2 or isEmpty(prioritizedMoves)) removeSnakesHeads(filteredBestNextMoves)
	else prioritizedMoves
		// removeSnakesHeads(prioritizedMoves)
}
var nextMove = safeMoves[0] default defaultMove
---
{
	// shout: "Moving $(nextMove)",
	safeMoves: safeMoves,
	move: nextMove,
}