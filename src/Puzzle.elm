module Puzzle exposing (..)

import Types exposing (..)
import Scoring exposing (..)
import List exposing (member)
import Debug exposing (log)
import Maybe 

vowels = String.toList "AEIOUYĄĘ"
vowelCost = 200

acceptConsonant : Char -> GameState -> (GameState, Cmd msg)
acceptConsonant letter state =
  let used = log "used" state.lettersUsed
      -- if we're here, wheel state is definitely ok. But cannot express that via type system yet :(
      wheel = log "wheel" (Maybe.withDefault (Guess 0) state.wheelState)
      le_ = log "acl" letter
      st_ = log "acst" state
  in
      if member letter used then
        (log "used" { state | playerState = TurnLost }, Cmd.none)
      else if member letter vowels then
        (log "vwl" { state | playerState = TurnLost }, Cmd.none)
      else
        (log "yes" { state |
          playerState = ChooseAction,
          lettersUsed = letter :: state.lettersUsed,
          players = updateScore state.players state.currentPlayer (calculateScore letter state.puzzle wheel)
        } , Cmd.none)

acceptVowel : Char -> GameState -> (GameState, Cmd msg)
acceptVowel letter state =
  let used = state.lettersUsed
      le_ = log "avl" letter
      st_ = log "avst" state
  in
      if member letter used then
        ({ state | playerState = TurnLost }, Cmd.none)
      else if not (member letter vowels) then
        ({ state | playerState = TurnLost }, Cmd.none)
      else
        ({state | playerState = SpinOrGuess}, Cmd.none)

