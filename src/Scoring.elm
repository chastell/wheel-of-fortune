module Scoring exposing (..)

import Types exposing (..)
import List exposing (indexedMap, foldl, filter, length, map)
import String exposing (toList)
import Debug exposing (log)

updateScore: List Player -> Int -> Int -> List Player
updateScore players index points =
  let modPoints = \i player -> if i == index then
                        { player | score = player.score + points }
                      else
                        player
  in
  indexedMap (modPoints) players

countTimes : Char -> String -> Int
countTimes letter str =
  toList str |> filter (\c -> c == letter) |> length

sum = \list -> foldl (+) 0 list

countInPuzzle : Char -> List String -> Int
countInPuzzle letter puzzle = (sum (map (countTimes letter) puzzle))

sectorPoints : WheelSector -> Int
sectorPoints sector = case sector of
  Guess points -> points
  _ -> 0

calculateScore: Char -> List String -> WheelSector -> Int
calculateScore letter puzzle sector =
  let perLetter = sectorPoints sector
      occurrences = countInPuzzle letter puzzle
  in
      perLetter * occurrences

