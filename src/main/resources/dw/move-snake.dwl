%dw 2.0
output application/json
import * from dw::Common

var allMoves:Array<Move> = ["up", "down", "left", "right"]
var me:Snake = payload.you
var myHead:Point = me.head
var board:Board = payload.board
var food = board.food
var boardWidth = board.width - 1
var boardHeight = board.height - 1
var otherSnake = (board.snakes filter ($.id != me.id))[0]
var safeMoves = do {
    var wallsLocations = [
		('down') if myHead.y == 0,
		('up') if myHead.y == boardWidth,
		('left') if myHead.x == 0,
		('right') if myHead.x == boardHeight
	]
    var myBodyLocations = allMoves map (move) -> (
        if (me.body contains (myHead moveTo move))
            move
        else ''
    )
    ---
    allMoves -- wallsLocations -- myBodyLocations
}
var avoidSnake = do {
    var availableMoves = safeMoves
    var snakeBodyLocations = availableMoves map (move) -> (
        if (otherSnake.body contains (myHead moveTo move))
            move
        else ''
    )
    ---
    availableMoves -- snakeBodyLocations
}
var closestFood = do {
    var availableMoves = avoidSnake
    var suggestedMoves = food map {
            ($),
            distance: myHead distanceTo $,
            moves: (myHead whereIs $) -- (allMoves -- availableMoves)
        }
        filter (not isEmpty($.moves))
    ---
    if (not isEmpty(suggestedMoves))
        suggestedMoves
        orderBy $.distance
        distinctBy $.moves
        then flatten($.moves)
    else availableMoves
}
var snakeHead = do {
    var availableMoves = closestFood
    var otherSnakeHead = otherSnake.body[0]
    var isSnakeClose = (myHead distanceTo otherSnakeHead) <= 2
    @Lazy
    var isSnakeSmaller = otherSnake.length < me.length
    ---
    if (isSnakeClose)
        if (isSnakeSmaller) availableMoves
        else safeMoves -- (myHead whereIs otherSnakeHead)
    else
        availableMoves
}
---
{
    debug: snakeHead,
    move: snakeHead[0] default 'up'
}