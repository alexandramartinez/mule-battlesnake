%dw 2.0
type Point = {
    x: Number,
    y: Number
}
type Snake = {
    id: String,
    name: String,
    body: Array<Point>,
    head: Point,
    length: Number
}
type Board = {
    height: Number,
    width: Number,
    snakes: Array<Snake>,
    food: Array<Point>
}
type Move = "up" | "down" | "left" | "right"
type ScorePoints = {
    positive: Number,
    negative: Number
}
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
fun distanceTo(point1:Point, point2:Point):Number = do {
    abs(point1.x - point2.x) + abs(point1.y - point2.y)
}
fun whereIs(point1:Point, point2:Point):Array = do {
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