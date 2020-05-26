module Main exposing (..)

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
import Puzzle exposing (acceptConsonant, acceptVowel)
import Json.Decode as Decode
import Random
import Debug exposing (log)


wheelDefinition = { sectors = Array.fromList [ Guess 100,
                                               Guess 250,
                                               Guess 500,
                                               Guess 150,
                                               Guess 300,
                                               Guess 1500,
                                               Bankrupt,
                                               Guess 400,
                                               Guess 200,
                                               Guess 500,
                                               Halt,
                                               Guess 350,
                                               Guess 450,
                                               WildCard ],
                    palette = Array.fromList [
                      ("#729ea1", "dark"),
                      ("#b5bd89", "dark"),
                      ("#dfbe99", "dark"),
                      ("#ec9192", "dark"),
                      ("#db5375", "dark"),
                      ("#3e4e50", "light"),
                      ("#f2AA7e", "dark"),
                      ("#6c756b", "light"),
                      ("#96c5f7", "dark") ] }

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
             -- useless? should always get this
             wheelState = Array.get 0 wheelDefinition.sectors,
             mods = Set.empty,
             lettersUsed = [],
             puzzle = [ "..BĘDZIE.WAS..", "..PIS.RUCHAŁ..", "....W.DUPĘ...."],
             category = "Powiedzenie",
             target = Nothing,
             rng = Random.int 0 ((Array.length wheelDefinition.sectors) - 1)
             },
           Cmd.none )

-- list access by index
nth : Int -> List a -> Maybe a
nth i list = List.drop i list |> List.head

update : Msg -> GameState -> ( GameState, Cmd Msg )
update msg state =
  case log "update-msg" msg of
    KeyPressed char -> handleLetterKey state char
    SpinCommand -> launchSpin state
    SpinTo num -> ( { state | target = Just num }, Cmd.none )
    SpinComplete -> 
      case log "update-state-spin-target" state.target of
        Just n ->
          case (Array.get n wheelDefinition.sectors) of
            Just sec -> advanceFromSector n state sec
            Nothing -> ( state, Cmd.none )
        Nothing -> ( state, Cmd.none ) -- what just happened?
    NextPlayerCommand ->
      let numPlayers = List.length state.players
          nextPlayer = remainderBy numPlayers (state.currentPlayer + 1)
      in
          ( { state | currentPlayer = nextPlayer, playerState = BeforeSpin },
            Cmd.none )
    _ -> ( state, Cmd.none )

advanceFromSector : Int -> GameState -> WheelSector -> ( GameState, Cmd Msg )
advanceFromSector n state sector =
  -- remember to set state.current to n and target to Nothing
  let player = nth state.currentPlayer state.players
      newPlayerState = log "afs nps" (case sector of
        Guess val -> SpinSuccessConsonant
        Halt -> TurnLost
        Bankrupt -> TurnLost
        FreeVowel -> GuessVowel
        WildCard -> BeforeSpin
        Stonks -> BeforeSpin
        Sunks -> BeforeSpin)
      newState = log "afs nstat" { state | playerState = newPlayerState, current = n }
  in
    case sector of
        -- TODO: Unless player has wildcard
        Halt -> update NextPlayerCommand newState
        Bankrupt -> update NextPlayerCommand newState
        _ -> ( newState, Cmd.none )

handleLetterKey : GameState -> Char -> ( GameState, Cmd Msg )
handleLetterKey state char =
  let playerState = log "h-l-k pstate" state.playerState
      newGameState = log "h-l-k ngs" (case playerState of
        -- accept, pass to letter finder
        SpinSuccessConsonant -> acceptConsonant char state
        -- accept, pass to vowel finder
        ChooseAction -> acceptVowel char state
        -- otherwise, don't accept
        _ -> state)
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
  if List.member playerState [BeforeSpin, ChooseAction, SpinOrGuess] then
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
  Browser.Events.onKeyUp keyDecoder

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
