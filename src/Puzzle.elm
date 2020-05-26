module Puzzle exposing (..)

import Types exposing (..)
import Scoring exposing (..)
import List exposing (member)
import Debug exposing (log)
import Maybe 

vowels = String.toList "AEIOUYĄĘ"
vowelCost = 200

acceptConsonant : Char -> GameState -> GameState
acceptConsonant letter state =
  let used = state.lettersUsed
      -- if we're here, wheel state is definitely ok. But cannot express that via type system yet :(
      wheel = (Maybe.withDefault (Guess 0) state.wheelState)
      letterScore = (calculateScore letter state.puzzle wheel)
  in
      if member letter used then
        { state | playerState = TurnLost }
      else if member letter vowels then
        { state | playerState = TurnLost }
      else
        { state |
          playerState = ChooseAction,
          lettersUsed = letter :: state.lettersUsed,
          players = updateScore state.players state.currentPlayer letterScore
        }

acceptVowel : Char -> GameState -> GameState
acceptVowel letter state =
  let used = state.lettersUsed
  in
      if member letter used then
        { state | playerState = TurnLost }
      else if not (member letter vowels) then
        { state | playerState = TurnLost }
      else
        {state | playerState = SpinOrGuess,
          lettersUsed = letter :: state.lettersUsed,
          players = updateScore state.players state.currentPlayer -vowelCost
        }

