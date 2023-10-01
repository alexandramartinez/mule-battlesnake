# A simple [Battlesnake](http://play.battlesnake.com) written in Mule and DataWeave

[![Build and Deploy to Sandbox](https://github.com/alexandramartinez/mule-battlesnake/actions/workflows/build.yml/badge.svg)](https://github.com/alexandramartinez/mule-battlesnake/actions/workflows/build.yml)

Cool tool to check other scenarios: [Battlesnake board generator](https://nettogrof.github.io/battle-snake-board-generator/).

Watch my Battlesnake live streams on [Twitch](https://www.twitch.tv/devalexmartinez) or [YouTube](https://www.youtube.com/playlist?list=PLb61lESgk6hi60IazebMZ7pmZBZeIcEKt). 

## Quickstart

To get started with your own Mule and DataWeave Battlesnake, please refer to Manik's [starter project](https://github.com/manikmagar/mule-battlesnake-starter) or [this article](https://www.prostdev.com/post/how-to-develop-a-battlesnake-using-a-mulesoft-api-and-the-dataweave-language).

## About my Battlesnake

`Maxine the Mule` version 2 is based on a scoring system to take better decisions. 

She counts the scores for each move (up, down, left, right) depending on a series of criteria like food, other snakes, walls, and so on. Based on those scores, she takes a decision.

For example:

```json
[
    {
      "move": "up",
      "score": -481,
      "futureMoves": 0
    },
    {
      "move": "down",
      "score": 13,
      "futureMoves": 272
    },
    {
      "move": "left",
      "score": 13,
      "futureMoves": 29
    },
    {
      "move": "right",
      "score": 20,
      "futureMoves": 137
    }
  ]
```

You can battle Maxine by using her from the public snakes when you [create a game](https://play.battlesnake.com/account/games/create).
