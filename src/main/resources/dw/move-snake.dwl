%dw 2.0
output application/json
import * from dw::Common

var moves:Array<Move> = ["up", "down", "left", "right"]
var me:Snake = payload.you
var board:Board = payload.board
var otherSnakes = board.snakes filter ($.id != me.id)
var food = board.food
var maxFutureMoves = 8

var maxScore:Number = sizeOf(food) + 3 // bc there are max 3 possible moves
var negativeScore:Number = -100*maxScore
var bodyScore:ScorePoints = {
    positive: 1,
    negative: negativeScore
}
var wallsScore:ScorePoints = {
    positive: 1,
    negative: negativeScore
}
var snakesHeadsScore:ScorePoints = {
    positive: 1,
    negative: -(maxScore+2)
}
var foodScore:ScorePoints = {
    positive: sizeOf(food), // - index
    negative: 0
}
var futureScore:ScorePoints = {
    positive: maxScore, // will be overriden to be sizeOf(filteredFutureMoves)
    negative: -1
}

var orderedFood = if (isEmpty(food)) [] else (
    food map {
        distance: me.head distanceTo $,
        directions: me.head whereIs $
    } orderBy ($.distance) map {
        score: foodScore.positive - $$,
        ($)
    }
)

fun getBodyScore(snakes:Array<Snake>, myNewHead:Point):Number = do {
    sum(snakes map (
        if ($.body contains myNewHead) bodyScore.negative
        else bodyScore.positive
    ))
}
fun getWallsScore(myNewHead:Point):Number = do {
    myNewHead match {
        case p if p.x < 0 -> wallsScore.negative
        case p if p.y < 0 -> wallsScore.negative
        case p if p.x >= board.width -> wallsScore.negative
        case p if p.y >= board.height -> wallsScore.negative
        else -> wallsScore.positive
    }
}
fun getSnakesHeadsScore(snakes:Array<Snake>, myNewHead:Point, myLength:Number):Number = do {
    var closeSnakes = if (isEmpty(otherSnakes)) null
        else (snakes map (snake) -> {
            distance: snake.head distanceTo myNewHead,
            score: if (snake.length >= myLength) snakesHeadsScore.negative
                else snakesHeadsScore.positive
        }) filter ($.distance <= 2)
    ---
    sum(closeSnakes.score default [])
}
fun getFoodScore(move:Move):Number = do {
    if (isEmpty(food)) 0
    else max(orderedFood map (
        if ($.directions contains move) $.score
        else foodScore.negative
    ))
}
fun getFutureMovesNumber(newHead:Point, currentBody:Array<Point>):Number = do {
    var isInsideWalls = getWallsScore(newHead) > 0
    var collidesWithSnakes = flatten(otherSnakes.body) contains newHead
    var collidesWithSelf = currentBody contains newHead
    ---
    if (isInsideWalls and !collidesWithSnakes and !collidesWithSelf) 1
    else 0
}
fun getFuture(myBody:Array<Point>, move:Move, maxIterations=maxFutureMoves) = do {
    @Lazy
    var newHead = myBody[0] moveTo move
    @Lazy
    var validMove = getFutureMovesNumber(newHead, myBody) // 1 or 0
    @Lazy
    var isFood = food contains newHead
    @Lazy
    var newMe = if (isFood) newHead >> myBody
        else (newHead >> myBody[0 to -2])
    ---
    if (maxIterations == 0 or validMove == 0) 0
    else validMove + sum(
        moves map (
            getFuture(newMe, $, maxIterations-1)
        )
    )
}
var scoredMoves = moves map do {
    var myNewHead:Point = me.head moveTo $
    var snakesHeadsScore = getSnakesHeadsScore(otherSnakes, myNewHead, me.length)
    var foodScore = getFoodScore($)
    var foodAndSnakesHeadsScore = if (snakesHeadsScore < 0) snakesHeadsScore
        else snakesHeadsScore + foodScore
    var score:Number = 
            getBodyScore(board.snakes, myNewHead) 
            + getWallsScore(myNewHead) 
            + foodAndSnakesHeadsScore
    ---
    {
        move: $,
        score: score,
        futureMoves: (getFuture(me.body, $))
    }
}
var finalMoves = do {
    var filteredFutureMoves = scoredMoves filter ($.futureMoves > 0) orderBy -($.futureMoves)
    var avgFutureMoves = avg(filteredFutureMoves.futureMoves)
    var diff = (max(filteredFutureMoves.futureMoves) default 0) - (min(filteredFutureMoves.futureMoves) default 0)
    var needToFilterFurther = diff > avgFutureMoves
    var maxScoreOverride = sizeOf(filteredFutureMoves)
    ---
    filteredFutureMoves map {
        ($ - "score"),
        score: $.score + (
            if (needToFilterFurther and ($.futureMoves < avgFutureMoves)) futureScore.negative
            else maxScoreOverride - $$
            then $/2
        )
    }
} orderBy -($.score)
---
{
    debug: finalMoves,
    orderedFood: orderedFood,
    move: finalMoves.move[0] default 'up'
}