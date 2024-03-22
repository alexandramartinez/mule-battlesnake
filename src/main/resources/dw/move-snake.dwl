%dw 2.0
output application/json
// import time from dw::util::Timer
import update from dw::util::Values
import * from dw::Common

var noMoves:Moves = []
var me:Snake = payload.you
var board:Board = payload.board
var food:Points = board.food
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
type FutureMovesObj = {
    move: Move,
    size: Number
}

fun getSafeMoves(body:Points):Moves = do {
    var head:Point = body[0]
    var wallsMoves:Moves = [
        (down) if head.y == 0,
        (up) if head.y == (board.width - 1),
        (left) if head.x == 0,
        (right) if head.x == (board.height - 1)
    ]
    var allSnakesMoves:Moves = flatten(otherSnakesBodies << body) distinctBy $ then
        [
            (down) if ($ contains (head moveTo down)),
            (up) if ($ contains (head moveTo up)),
            (left) if ($ contains (head moveTo left)),
            (right) if ($ contains (head moveTo right))
	    ]
    ---
    allMoves -- wallsMoves -- allSnakesMoves
}
var safeMoves:Moves = getSafeMoves(me.body)
fun filterOnlySafeMoves(fromMoves:Moves):Moves =
    fromMoves filter (safeMoves contains $)
fun getCloseSnakes(myHead:Point=me.head, myLength:Number=me.length):Snakes = otherSnakes map {
        isClose: (myHead distanceTo $.head) <= 2,
        isSmaller: $.length < myLength,
        ($)
    } filter ($.isClose)
var closestFoodMoves:Moves = do {
    var suggestedMoves:Array = food map {
            ($),
            distance: me.head distanceTo $,
            moves: filterOnlySafeMoves(me.head whereIs $)
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
var closeSnakesHeadsMoves:Moves = do {
    var closeSnakes:Snakes = getCloseSnakes()
    ---
    if (isEmpty(closeSnakes)) noMoves
    else filterOnlySafeMoves(closeSnakes flatMap (
        if ($.isSmaller) me.head whereIs $.head //noMoves // change this behaviour if you want to be aggressive
        else safeMoves -- (me.head whereIs $.head)
    ))
}
fun getFutureMovesRec(availableMoves:Moves=safeMoves, myBody:Points=me.body, level:Number=0):Array<FutureMovesObj> = 
    availableMoves map ((move) -> do {
        @Lazy
        var newHead:Point = myBody[0] moveTo move
        @Lazy 
        var newBody:Points = if (isFood(newHead,food)) (newHead >> myBody) else (newHead >> myBody[0 to -2])
        @Lazy
        var newSafeMoves:Moves = getSafeMoves(newBody)
        @Lazy
        var lookFurther = if (level == maxFutureMoves) []
            else getFutureMovesRec(newSafeMoves, newBody, level+1)
        ---
        {
            move: move,
            size: sizeOf(lookFurther),
            lookFurther: lookFurther 
        }
    }) 
    map {
        move: $.move,
        size: sum(flatten($..size))
    }
var futureMovesObjArr:Array<FutureMovesObj> = getFutureMovesRec() orderBy -$.size
var futureMoves:Moves = do {
    var futureMovesAvgSize:Number = avg(futureMovesObjArr.size)
    ---
    (
        if ((futureMovesObjArr[0].size - futureMovesObjArr[-1].size) > futureMovesAvgSize)
            futureMovesObjArr filter ($.size > futureMovesAvgSize)
        else (futureMovesObjArr filter ($.size > minFutureMoves))
    ).move default []
}
fun getMovesCount(moves:Moves, existingCountedMoves={}):MovesCountObj = moves reduce (
    (item, acc=existingCountedMoves) -> 
        if (acc[item] == null) 
            {
                (acc),
                (item): 1
            }
        else acc update item with (acc[item] + 1)
    ) orderBy -$
var countedMoves = do {
    fun getMovesByPriority(arr1:Moves, arr2:Moves, arr3:Moves):MovesCountObj =
        getMovesCount(arr1)
        then getMovesCount(arr2, $)
        then getMovesCount(arr3, $)
    var movesByPriorityDraft = getMovesByPriority(
        closeSnakesHeadsMoves,
        closestFoodMoves,
        futureMoves
        // [],[]
    )
    var futureMovesGrouped = futureMovesObjArr groupBy $.move
    ---
    if (movesByPriorityDraft[0] == movesByPriorityDraft[1])
        movesByPriorityDraft mapObject ((value, key) -> do {
            @Lazy
            var newHead:Point = (me.head moveTo (key as Move))
            @Lazy
            var closeBiggerSnakes:Snakes = getCloseSnakes(newHead, me.length) filter (not $.isSmaller)
            @Lazy
            var isBiggerSnakeClose:Boolean = not isEmpty(closeBiggerSnakes)
            @Lazy 
            var hasMinFutureMoves:Boolean = ((futureMovesGrouped[key][0]).size default 0) >= minFutureMoves
            ---
            (key): 
                if (hasMinFutureMoves)
                    if (isBiggerSnakeClose and isFood(newHead,food))
                        value-1
                    else value
                else value-1
        }) orderBy -$
        then if ($[0] == $[1]) getMovesCount(futureMoves, $) else $
    else 
        movesByPriorityDraft
}
---
{
    //debug only

    // safeMoves: safeMoves,
    // closeSnakesHeads: closeSnakesHeadsMoves,
    // closestFood: closestFoodMoves,
    // futureMovesObjArr: futureMovesObjArr,
    // futureMoves: futureMoves,
    // countedMoves: countedMoves,

    //needed fields

    move: keysOf(countedMoves)[0] default safeMoves[0],
    turn: payload.turn,
    id: payload.game.id
}