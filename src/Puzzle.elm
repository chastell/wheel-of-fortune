module Puzzle exposing (..)

import Types exposing (..)
import Scoring exposing (..)
import Set exposing (Set)
import Padding exposing (padPuzzle)
import Array
import Maybe 

vowels = Set.fromList (String.toList "AEIOUYĄĘ")
vowelCost = 200

acceptConsonant : Char -> GameState -> GameState
acceptConsonant letter state =
  let used = state.lettersUsed
      -- if we're here, wheel state is definitely ok. But cannot express that via type system yet :(
      wheel = (Array.get state.current state.wheel.sectors)
      letterScore = (calculateScore letter state.puzzle (Maybe.withDefault (Guess 0) wheel))
  in
      if Set.member letter used then
        { state | playerState = TurnLost }
      else if Set.member letter vowels then
        { state | playerState = TurnLost }
      else if letterScore == 0 then
        { state | playerState = TurnLost }
      else
        { state |
          playerState = ChooseAction,
          lettersUsed = Set.union (Set.singleton letter) state.lettersUsed,
          players = updateScore state.players state.currentPlayer letterScore state.mods
        }

acceptVowel : Char -> GameState -> GameState
acceptVowel letter state =
  let used = state.lettersUsed
  in
      if Set.member letter used then
        { state | playerState = TurnLost }
      else if not (Set.member letter vowels) then
        { state | playerState = TurnLost }
      else
        {state | playerState = SpinOrGuess,
          lettersUsed = Set.union (Set.singleton letter) state.lettersUsed,
          -- mods do not apply to vowels
          -- TODO: freeVowel
          players = updateScore state.players state.currentPlayer -vowelCost []
        }

allLetters : List String -> Set Char
allLetters puzzle =
  let stringToSet = \t -> String.toList t |> Set.fromList
      puzzleSet = List.foldl Set.union Set.empty (List.map stringToSet puzzle)
  in
      Set.filter (\c -> c /= '.') puzzleSet
  

reveal : GameState -> GameState
reveal state =
  { state | lettersUsed = allLetters state.puzzle, playerState = Dead }

reset : GameState -> String -> String -> GameState
reset state newPuzzle category = 
  let width = 14 -- constants
      height = 4 
      padded = padPuzzle width height "." -- Will get padded to the whole board
  in
      { state |
        lettersUsed = Set.empty,
        puzzle = padded,
        category = category,
        playerState = BeforeSpin
        }

setBoard : GameState -> String -> String -> GameState
setBoard state newPuzzle category =
  let width = 14 -- constants
      height = 4 
      padded = padPuzzle width height newPuzzle
  in
      { state |
        lettersUsed = Set.empty,
        puzzle = padded,
        category = category,
        playerState = BeforeSpin
        }


