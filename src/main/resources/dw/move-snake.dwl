%dw 2.5
output application/json
import update from dw::util::Values
import * from dw::Common

var allMoves:Array<Move> = ["up", "down", "left", "right"]
var me:Snake = payload.you
var myHead:Point = me.head
var board:Board = payload.board
var food = board.food
var boardWidth = board.width - 1
var boardHeight = board.height - 1
var maxFutureMoves = 8
var otherSnake = (board.snakes filter ($.id != me.id))[0]

fun getWallsLocations(head:Point) = [
    ('down') if head.y == 0,
    ('up') if head.y == boardWidth,
    ('left') if head.x == 0,
    ('right') if head.x == boardHeight
]
fun getOwnBodyLocations(body:Array<Point>) = filterMovesByHeadAndBody(body, body[0])
fun getOtherSnakeBodyLocations(myHead:Point, otherSnakeBody:Array<Point>) = filterMovesByHeadAndBody(otherSnakeBody, myHead)
fun getSafeMoves(myBody:Array<Point>, otherSnakeBody:Array<Point>) = (
    allMoves 
    -- getWallsLocations(myBody[0]) 
    -- getOwnBodyLocations(myBody)
    -- getOtherSnakeBodyLocations(myBody[0], otherSnakeBody)
)
var safeMoves = getSafeMoves(me.body, otherSnake.body)
fun getClosestFoodLocations(availableMoves, food, head:Point) = do {
    var suggestedMoves = food map {
            ($),
            distance: head distanceTo $,
            moves: (head whereIs $) -- (allMoves -- availableMoves)
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
fun getOtherSnakeHeadLocation(availableMoves, mySnake:Snake, otherSnake:Snake) = do {
    var isSnakeClose = (mySnake.head distanceTo otherSnake.head) <= 2
    @Lazy
    var isSnakeSmaller = otherSnake.length < mySnake.length
    ---
    if (isSnakeClose)
        if (isSnakeSmaller) availableMoves // change this behaviour if you want to be aggressive
        else availableMoves -- (mySnake.head whereIs otherSnake.head)
    else availableMoves
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
var countedMoves = (
    (safeMoves
    ++ getClosestFoodLocations(safeMoves, food, myHead)
    ++ getOtherSnakeHeadLocation(safeMoves, me, otherSnake))
    reduce ((item, acc={}) -> 
        if (acc[item] == null) 
            acc ++ {
                (item): 1
            }
        else acc update item with (acc[item] + 1)
    )
    orderBy -$
)
---
{
    debug: countedMoves,
    // safeMoves: safeMoves,
    // getClosestFoodLocations: getClosestFoodLocations(safeMoves, food, myHead),
    // getOtherSnakeHeadLocation: getOtherSnakeHeadLocation(safeMoves, me, otherSnake),
    move: keysOf(countedMoves)[0] default 'up',
    turn: payload.turn
}