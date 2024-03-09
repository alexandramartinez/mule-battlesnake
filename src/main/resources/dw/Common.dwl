%dw 2.0
type Point = {
    x: Number,
    y: Number
}
type Points = Array<Point>
type Snake = {
    id: String,
    name: String,
    body: Points,
    head: Point,
    length: Number
}
type Snakes = Array<Snake>
type Board = {
    height: Number,
    width: Number,
    snakes: Snakes,
    food: Points
}
type Move = "up" | "down" | "left" | "right"
type Moves = Array<Move>
fun moveTo(point:Point, move:Move):Point = do {
    move match {
		case "down" -> {
			x: point.x,
			y: point.y - 1
		}
		case "up" -> {
			x: point.x,
			y: point.y + 1
		}
		case "left" -> {
			x: point.x - 1,
			y: point.y
		}
		case "right" -> {
			x: point.x + 1,
			y: point.y
		}
		else -> point
	}
}
fun distanceTo(point1:Point, point2:Point):Number = 
    abs(point1.x - point2.x) + abs(point1.y - point2.y)
fun whereIs(point1:Point, point2:Point):Moves = do {
	var xDistance = point1.x - point2.x
    var yDistance = point1.y - point2.y
	---
	[
		('left') if (xDistance >= 1),
		('right') if (xDistance <= -1),
		('down') if (yDistance >= 1),
		('up') if (yDistance <= -1)
	]
}
fun isFood(point:Point, food:Points):Boolean = 
	food contains point