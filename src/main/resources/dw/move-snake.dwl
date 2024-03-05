%dw 2.0
output application/json
import update from dw::util::Values
import * from dw::Common

var allMoves:Array<Move> = ["up", "down", "left", "right"]
var noMoves:Array<Move> = []
var me:Snake = payload.you
var myHead:Point = me.head
var board:Board = payload.board
var food:Points = board.food
var boardWidth:Number = board.width - 1
var boardHeight:Number = board.height - 1
var maxFutureMoves:Number = 8
var minFutureMoves:Number = maxFutureMoves * 2
var otherSnakes:Snakes = (board.snakes filter ($.id != me.id))
var otherSnakesBodies:Array<Points> = otherSnakes.body default []

type MovesCountObj = {
    up?: Number,
    down?: Number,
    left?: Number,
    right?: Number
}

fun getWallsLocations(head:Point) = [
    ('down') if head.y == 0,
    ('up') if head.y == boardWidth,
    ('left') if head.x == 0,
    ('right') if head.x == boardHeight
]
fun getOwnBodyLocations(body:Points):Array = filterMovesByHeadAndBody(body, body[0])
fun getOtherSnakesBodyLocations(myHead:Point, otherSnakesBodies:Array<Points>):Array = otherSnakesBodies flatMap filterMovesByHeadAndBody($, myHead)
fun getSafeMoves(myBody:Points, otherSnakesBodies:Array<Points>):Array<Move> = (
    allMoves 
    -- getWallsLocations(myBody[0]) 
    -- getOwnBodyLocations(myBody)
    -- getOtherSnakesBodyLocations(myBody[0], otherSnakesBodies)
)
var safeMoves:Array<Move> = getSafeMoves(me.body, otherSnakesBodies)
fun getClosestFoodLocations(availableMoves:Array<Move>, food:Points=food, head:Point=myHead):Array<Move> = do {
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
fun getOtherSnakesHeadLocations(availableMoves:Array<Move>, mySnake:Snake=me, otherSnakes:Snakes=otherSnakes):Array<Move> = do {
    var closeSnakes:Array = getCloseSnakes(mySnake.head, mySnake.length, otherSnakes)
    ---
    if (isEmpty(closeSnakes)) noMoves
    else closeSnakes flatMap (
        if ($.isSmaller) mySnake.head whereIs $.head //noMoves // change this behaviour if you want to be aggressive
        else availableMoves -- (mySnake.head whereIs $.head)
    )
}
fun getFutureMovesRec(availableMoves:Array<Move>, myBody:Points=me.body, otherSnakesBodies:Array<Points>=otherSnakesBodies, level:Number=0) = availableMoves map ((move) -> do {
    @Lazy
    var newHead:Point = myBody[0] moveTo move
    @Lazy 
    var newBody:Points = if (hasFood(newHead,food)) (newHead >> myBody) else (newHead >> myBody[0 to -2])
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
fun getMovesCount(moves:Array<Move>, existingCountedMoves={}):MovesCountObj = moves reduce (
    (item, acc=existingCountedMoves) -> 
        if (acc[item] == null) 
            {
                (acc),
                (item): 1
            }
        else acc update item with (acc[item] + 1)
    ) orderBy -$
var countedMoves = do {
    var otherSnakesHeads:Array<Move> = getOtherSnakesHeadLocations(safeMoves)
    var closestFood:Array<Move> = getClosestFoodLocations(safeMoves)
    var futureMovesObj = getFutureMovesRec(safeMoves)
    var avgSize = avg(futureMovesObj.size)
    var futureMoves:Array<Move> = (if ((futureMovesObj[0].size - futureMovesObj[-1].size) > avgSize) 
            futureMovesObj filter ($.size > avgSize)
        else (futureMovesObj filter ($.size > minFutureMoves))).move default []
    fun getMovesByPriority(arr1:Array<Move>, arr2:Array<Move>, arr3:Array<Move>):MovesCountObj =
        getMovesCount(arr1)
        then getMovesCount(arr2, $)
        then getMovesCount(arr3, $)
    var movesByPriorityDraft = getMovesByPriority(
        otherSnakesHeads,
        closestFood,
        futureMoves
        // [],[]
    )
    ---
    if (movesByPriorityDraft[0] == movesByPriorityDraft[1])
        movesByPriorityDraft mapObject ((value, key) -> do {
            @Lazy
            var newHead:Point = (myHead moveTo (key as Move))
            @Lazy
            var closeBiggerSnakes:Snakes = getCloseSnakes(newHead, me.length, otherSnakes) filter (not $.isSmaller)
            @Lazy
            var isBiggerSnakeClose:Boolean = not isEmpty(closeBiggerSnakes)
            @Lazy 
            var hasMinFutureMoves:Boolean = ((futureMovesObj filter ($.move ~= key)).size[0]) >= minFutureMoves
            ---
            (key): 
                if (hasMinFutureMoves)
                    if (isBiggerSnakeClose and hasFood(newHead,food))
                        value-1
                    else value
                else value-1
        }) orderBy -$
        then if ($[0] == $[1]) getMovesCount(futureMoves, $) else $
    else movesByPriorityDraft
}
---
{
    debug: countedMoves,
    // debug2: getFutureMovesRec(safeMoves),
    move: keysOf(countedMoves)[0] default safeMoves[0],
    turn: payload.turn
}