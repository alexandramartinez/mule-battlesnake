%dw 2.0
output application/json
import update from dw::util::Values
import * from dw::Common

var allMoves:Array<Move> = ["up", "down", "left", "right"]
var noMoves:Array<Move> = []
var me:Snake = payload.you
var myHead:Point = me.head
var board:Board = payload.board
var food:Array<Point> = board.food
var boardWidth:Number = board.width - 1
var boardHeight:Number = board.height - 1
var maxFutureMoves:Number = 8
var otherSnakes:Array<Snake> = (board.snakes filter ($.id != me.id))
var otherSnakesBodies:Array<Array<Point>> = otherSnakes.body default []

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
var safeMoves:Array<Move> = getSafeMoves(me.body, otherSnakesBodies)
fun getClosestFoodLocations(availableMoves:Array<Move>, food:Array<Point>, head:Point):Array<Move> = do {
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
fun getOtherSnakesHeadLocations(availableMoves:Array<Move>, mySnake:Snake, otherSnakes:Array<Snake>):Array<Move> = do {
    var closeSnakes:Array = (otherSnakes map {
        ($),
        isClose: (mySnake.head distanceTo $.head) <= 2,
        isSmaller: $.length < mySnake.length
    }) filter ($.isClose)
    ---
    if (isEmpty(closeSnakes)) noMoves
    else closeSnakes flatMap (
        if ($.isSmaller) mySnake.head whereIs $.head //noMoves // change this behaviour if you want to be aggressive
        else availableMoves -- (mySnake.head whereIs $.head)
    )
}
fun getFutureMovesRec(availableMoves:Array<Move>, myBody:Array<Point>, otherSnakesBodies:Array<Array<Point>>, level:Number=0) = availableMoves map ((move) -> do {
    @Lazy
    var newHead:Point = myBody[0] moveTo move
    @Lazy
    var isFood:Boolean = food contains newHead
    @Lazy 
    var newBody:Array<Point> = if (isFood) (newHead >> myBody) else (newHead >> myBody[0 to -2])
    @Lazy
    var newSafeMoves:Array<Move> = getSafeMoves(newBody, otherSnakesBodies)
    @Lazy
    var lookFurther = if (level == maxFutureMoves) []
        else getFutureMovesRec(newSafeMoves, newBody, otherSnakesBodies, level+1)
    ---
    {
        move:move,
        size:sizeOf(lookFurther) + sum(lookFurther.size default []),
        // lookFurther:lookFurther // uncomment to debug Tree
    }
}) orderBy(-$.size)
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
    var otherSnakesHeads:Array<Move> = getOtherSnakesHeadLocations(safeMoves, me, otherSnakes)
    var closestFood:Array<Move> = getClosestFoodLocations(safeMoves, food, myHead)
    var futureMovesObj = getFutureMovesRec(safeMoves, me.body, otherSnakesBodies)
    var avgSize = avg(futureMovesObj.size)
    var futureMoves:Array<Move> = (if ((futureMovesObj[0].size - futureMovesObj[-1].size) > avgSize) 
            futureMovesObj filter ($.size > avgSize)
        else (futureMovesObj filter ($.size > 1))).move default []
    fun getMovesByPriority(arr1:Array<Move>, arr2:Array<Move>, arr3:Array<Move>) =
        getMovesCount(arr1)
        then getMovesCount(arr2, $)
        then getMovesCount(arr3, $)
    ---
    getMovesByPriority(
        futureMoves,
        otherSnakesHeads,
        closestFood
        // [],[]
    )
}
---
{
    debug: countedMoves,
    move: keysOf(countedMoves)[0] default safeMoves[0],
    turn: payload.turn
}