module Scoring exposing (..)

import Types exposing (..)
import List exposing (indexedMap, foldl, filter, length, map)
import String exposing (toList)

updateScore: List Player -> Int -> Int -> List Player
updateScore players index points =
  let modPoints = \i player -> if i == index then
                        { player | score = player.score + points }
                      else
                        player
  in
  -- pseudocode: players[index].score += points
  indexedMap (modPoints) players

countTimes : Char -> String -> Int
countTimes letter str =
  toList str |> filter (\c -> c == letter) |> length

sum = \list -> foldl (+) 0 list

calculateScore: Char -> List String -> WheelSector -> Int
calculateScore letter puzzle wheel =
  let perLetter = case wheel of
        Guess v -> v
        _ -> 0
      occurrences = sum (map (countTimes letter) puzzle)
  in
      perLetter * occurrences


