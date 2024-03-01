%dw 2.0
output application/json
import update from dw::util::Values
import * from dw::Common

var allMoves:Array<Move> = ["up", "down", "left", "right"]
var noMoves:Array<Move> = []
var me:Snake = payload.you
var myHead:Point = me.head
var board:Board = payload.board
var food = board.food
var boardWidth = board.width - 1
var boardHeight = board.height - 1
var maxFutureMoves = 8
var otherSnakes:Array<Snake> = (board.snakes filter ($.id != me.id))

fun getWallsLocations(head:Point) = [
    ('down') if head.y == 0,
    ('up') if head.y == boardWidth,
    ('left') if head.x == 0,
    ('right') if head.x == boardHeight
]
fun getOwnBodyLocations(body:Array<Point>):Array = filterMovesByHeadAndBody(body, body[0])
fun getOtherSnakesBodyLocations(myHead:Point, otherSnakesBodies:Array<Array<Point>>):Array = otherSnakesBodies flatMap filterMovesByHeadAndBody($, myHead)
fun getSafeMoves(myBody:Array<Point>, otherSnakesBodies:Array<Array<Point>>):Array<Move> = (
    allMoves 
    -- getWallsLocations(myBody[0]) 
    -- getOwnBodyLocations(myBody)
    -- getOtherSnakesBodyLocations(myBody[0], otherSnakesBodies)
)
var safeMoves:Array<Move> = getSafeMoves(me.body, otherSnakes.body default [])
fun getClosestFoodLocations(availableMoves, food, head:Point):Array<Move> = do {
    var suggestedMoves:Array = food map {
            ($),
            distance: head distanceTo $,
            moves: (head whereIs $) -- (allMoves -- availableMoves)
        }
        filter (not isEmpty($.moves))
    ---
    if (not isEmpty(suggestedMoves))
        suggestedMoves
        orderBy $.distance
        then flatten($.moves)
        distinctBy $
    else noMoves
}
fun getOtherSnakesHeadLocations(availableMoves, mySnake:Snake, otherSnakes:Array<Snake>):Array<Move> = do {
    var closeSnakes:Array = (otherSnakes map {
        ($),
        isClose: (mySnake.head distanceTo $.head) <= 2,
        isSmaller: $.length < mySnake.length
    }) filter ($.isClose)
    ---
    closeSnakes match {
        case s if sizeOf(s) >= 1 -> s flatMap (
            if ($.isSmaller) noMoves // change this behaviour if you want to be aggressive
            else availableMoves -- (mySnake.head whereIs $.head)
        )
        else -> noMoves
    }
}
// fun getFutureMovesNumber(newHead:Point, currentBody:Array<Point>):Number = do {
//     var isInsideWalls = getWallsScore(newHead) > 0
//     var collidesWithSnakes = flatten(otherSnakes.body) contains newHead
//     var collidesWithSelf = currentBody contains newHead
//     ---
//     if (isInsideWalls and !collidesWithSnakes and !collidesWithSelf) 1
//     else 0
// }
// fun getFuture(myBody:Array<Point>, move:Move, maxIterations=maxFutureMoves) = do {
//     @Lazy
//     var newHead = myBody[0] moveTo move
//     @Lazy
//     var validMove = getFutureMovesNumber(newHead, myBody) // 1 or 0
//     @Lazy
//     var isFood = food contains newHead
//     @Lazy
//     var newMe = if (isFood) newHead >> myBody
//         else (newHead >> myBody[0 to -2])
//     ---
//     if (maxIterations == 0 or validMove == 0) 0
//     else validMove + sum(
//         moves map (
//             getFuture(newMe, $, maxIterations-1)
//         )
//     )
// }
// fun getFuture(myBody:Array<Point>, move:Move, maxIterations=maxFutureMoves) = do {
//     @Lazy
//     var newHead = myBody[0] moveTo move
//     @Lazy
//     var validMove = 
// }
fun getMovesCount(moves:Array<Move>, existingCountedMoves={}):Object = moves reduce (
    (item, acc=existingCountedMoves) -> 
        if (acc[item] == null) 
            {
                (acc),
                (item): 1
            }
        else acc update item with (acc[item] + 1)
    ) orderBy -$
var countedMoves = do {
    var otherSnakesHeads = getOtherSnakesHeadLocations(safeMoves, me, otherSnakes)
    var closestFood = getClosestFoodLocations(safeMoves, food, myHead)
    ---
    getMovesCount(otherSnakesHeads)
    then getMovesCount(closestFood, $)
}
---
{
    debug: countedMoves,
    move: keysOf(countedMoves)[0] default safeMoves[0],
    turn: payload.turn
}