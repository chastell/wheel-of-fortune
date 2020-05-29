port module Main exposing (..)

import Types exposing (..)
import Browser
import Browser.Events
import Array
import Set exposing (Set)
import Html exposing (Html, button, div, text, node)
import Html.Attributes exposing (class)
import Template exposing (template, render)
import WofGrid exposing (letterGrid)
import Wheel exposing (theWheel)
import Players exposing (modIcons, playerList)
import Puzzle exposing (acceptConsonant, acceptVowel, reveal, reset, setBoard)
import Json.Decode as Decode
import Random
import Process
import Task
import Debug exposing (log)


wheelDefinition = { sectors = Array.fromList [ Guess 100, Guess 250, Guess 500, Guess 150, Guess 300, Guess 1500, Bankrupt, Guess 400, Guess 200, Guess 500, Halt, Guess 350, Guess 450, WildCard ],
                    palette = Array.fromList [ ("#729ea1", "dark"), ("#b5bd89", "dark"), ("#dfbe99", "dark"), ("#ec9192", "dark"), ("#db5375", "dark"), ("#3e4e50", "light"), ("#f2aa7e", "dark"), ("#6c756b", "light"), ("#96c5f7", "dark") ] }

initialPlayers = [
  initPlayer "Mario",
  initPlayer "Peach",
  initPlayer "Luigi",
  initPlayer "Toad"
  ]

initPlayer: String -> Player
initPlayer name = { name = name, score = 0, wildcard = False }

main = Browser.element { init = init, update = update, view = view, subscriptions = subscriptions }

init : () -> ( GameState, Cmd msg )
init _ = ( { players = initialPlayers,
             currentPlayer = 0, playerState = BeforeSpin,
             current = 0,
             mods = [],
             lettersUsed = Set.empty,
             puzzle = [ "..BĘDZIE.WAS..", "..PIS.RUCHAŁ..", "....W.DUPĘ...."],
             category = "Powiedzenie",
             wheel = wheelDefinition,
             target = Nothing,
             rng = Random.int 0 ((Array.length wheelDefinition.sectors) - 1)
             },
           Cmd.none )

-- list access by index
nth : Int -> List a -> Maybe a
nth i list = List.drop i list |> List.head

replaceNth : Int -> a -> List a -> List a
replaceNth index new list =
  let replacer = (\i elem -> if i == index then new else elem)
  in
  List.indexedMap replacer list

port animationLauncher : () -> Cmd msg
port setPuzzleText : (List String -> msg) -> Sub msg

update : Msg -> GameState -> ( GameState, Cmd Msg )
update msg state =
  case log "update-msg" msg of
    KeyPressed char -> handleLetterKey state char
    SpinCommand -> launchSpin state
    SpinTo num ->
      if num == state.current then
        -- Try to never spin same value twice
        launchSpin state
      else
        ( { state | target = Just num }, animationLauncher () )
    SpinComplete -> 
      -- TODO: rewrite to a single tuple-matching case
      case log "update-state-spin-target" state.target of
        Just n ->
          case (Array.get n wheelDefinition.sectors) of
            Just sec -> advanceFromSector n state sec
            Nothing -> ( state, Cmd.none )
        Nothing -> ( state, Cmd.none ) -- what just happened?
    NextPlayerCommand ->
      -- TODO: check if mods need to be dropped
      let numPlayers = List.length state.players
          nextPlayer = remainderBy numPlayers (state.currentPlayer + 1)
      in
          ( { state | currentPlayer = nextPlayer, playerState = BeforeSpin },
            Cmd.none )
    RevealCommand -> ( reveal state, Cmd.none )
    SetPuzzleCommand step text category ->
      case step of
        False -> ( reset state text category, 
               Process.sleep 1000 |>
               Task.perform (always (SetPuzzleCommand True text category)) )
        True -> ( setBoard state text category, Cmd.none )
    _ -> ( state, Cmd.none )

-- TODO: kick to module?
advanceFromSector : Int -> GameState -> WheelSector -> ( GameState, Cmd Msg )
advanceFromSector n state sector =
  let player = nth state.currentPlayer state.players
      landedState = { state | current = n, target = Nothing }
  in
      case (player, sector) of
        (Just(_), Guess val) ->
          ( { landedState | playerState = SpinSuccessConsonant }, Cmd.none )
        (Just(_), Halt) ->
          -- TODO: also consume wildcard here?
          update NextPlayerCommand landedState -- NOTE: TurnLost not set here
        (Just(p), Bankrupt) ->
          let bankruptPlayer = if p.wildcard then { p | wildcard = False } else { p | score = 0 }
              updatedPlayerList = replaceNth state.currentPlayer bankruptPlayer state.players
          in
              if p.wildcard then
                ( { landedState | players = updatedPlayerList, playerState = BeforeSpin }, Cmd.none )
              else
                update NextPlayerCommand { landedState | players = updatedPlayerList }
        (Just(_), FreeVowel) -> ( { landedState | playerState = GuessVowel }, Cmd.none )
        (Just(p), WildCard) ->
          let updatedPlayer = { p | wildcard = True }
              updatedPlayerList = replaceNth state.currentPlayer updatedPlayer state.players
          in
              ( { landedState | playerState = BeforeSpin, players = updatedPlayerList }, Cmd.none )
        (Just(_), Stonks) ->
          let multiplier = Multiplier n ("STONKS", 2.0)
              newMods = multiplier :: state.mods
          in
              ( { landedState | mods = newMods, playerState = BeforeSpin }, Cmd.none )
        (Just(_), Sunks) ->
          let multiplier = Multiplier n ("SUNKS", 0.5)
              newMods = multiplier :: state.mods
          in
              ( { landedState | mods = newMods, playerState = BeforeSpin }, Cmd.none )
        (_, _) -> ( state, Cmd.none )

handleLetterKey : GameState -> Char -> ( GameState, Cmd Msg )
handleLetterKey state char =
  let playerState = state.playerState
      newGameState = case playerState of
        -- accept, pass to letter finder
        SpinSuccessConsonant -> acceptConsonant char state
        -- accept, pass to vowel finder
        ChooseAction -> acceptVowel char state
        GuessVowel -> acceptVowel char state
        -- otherwise, don't accept
        _ -> state
  in
    case newGameState.playerState of
      TurnLost -> update NextPlayerCommand newGameState
      SpinOrGuess -> update NoOp newGameState
      ChooseAction -> update NoOp newGameState
      _ -> ( state, Cmd.none )

view : GameState -> Html Msg
view state =
  div [class "pure-g"] [
    node "main" [class "pure-u-20-24"] [
      (categoryDisplay state.category),
      (letterGrid state.puzzle state.lettersUsed),
      (theWheel wheelDefinition state.current state.target)
      ],
    node "sidebar" [class "pure-u-4-24"] [
      (modIcons state.mods),
      (playerList state.players state.currentPlayer state.playerState)
      ]
  ]

launchSpin : GameState -> (GameState, Cmd Msg)
launchSpin state =
  let playerState = log "launchSpin playerstate" state.playerState
  in
  -- The first three are obvious, the last one is to retry spins if the rng
  -- returns the same value.
  if List.member playerState [BeforeSpin, ChooseAction, SpinOrGuess, Spinning] then
    spinRNG state
  else
    (state, Cmd.none)

spinRNG state =
  ( { state | playerState = Spinning }, 
    -- how to handle rng generating same sector?
    Random.generate SpinTo state.rng )

categoryDisplay : String -> Html msg
categoryDisplay cat = 
  node "category" [class "pure-u-1"] [text cat]

subscriptions : GameState -> Sub Msg
subscriptions state =
  Sub.batch [ Browser.Events.onKeyUp keyDecoder,
              setPuzzleText (\l -> case l of
                text :: category :: [] ->
                  SetPuzzleCommand False text category
                _ ->
                  NoOp)
              ]

keyDecoder : Decode.Decoder Msg
keyDecoder =
  Decode.map toKey (Decode.field "key" Decode.string)

toKey : String -> Msg
toKey inp =
  case String.uncons inp of
    -- Funky syntax, but useful for pattern matching on single character
    Just ( ' ', "" ) -> NextPlayerCommand
    Just ( 'E', "nter" ) -> SpinCommand
    Just ( '!', "") -> RevealCommand
    Just ( char, "" ) -> KeyPressed (Char.toUpper char)
    _ -> NoOp
