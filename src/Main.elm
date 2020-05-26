module Main exposing (..)

import Types exposing (..)
import Browser
import Browser.Events
import Array
import Html exposing (Html, button, div, text, node)
import Html.Attributes exposing (class)
import Template exposing (template, render)
import WofGrid exposing (letterGrid)
import Wheel exposing (theWheel, spinWheel)
import Puzzle exposing (acceptConsonant, acceptVowel)
import Json.Decode as Decode
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

main = Browser.element { init = init, update = update, view = view, subscriptions = subscriptions }

init : () -> ( GameState, Cmd msg )
init _ = ( { players = [],
             currentPlayer = -1, playerState = BeforeSpin,
             current = 0,
             wheelState = Array.get 0 wheelDefinition.sectors,
             lettersUsed = [],
             puzzle = [ "..BĘDZIE.WAS..", "..PIS.RUCHAŁ..", "....W.DUPĘ...."],
             category = "Powiedzenie",
             target = Just 9
             },
           Cmd.none )

update : Msg -> GameState -> ( GameState, Cmd msg )
update msg state =
  case msg of
    KeyPressed char -> handleLetterKey state char
    SpinCommand -> launchSpin state
    _ -> ( state, Cmd.none )


handleLetterKey : GameState -> Char -> ( GameState, Cmd msg )
handleLetterKey state char =
  let playerState = state.playerState
  in
  case playerState of
    -- accept, pass to letter finder
    SpinSuccessConsonant -> acceptConsonant char state
    -- accept, pass to vowel finder
    ChooseAction -> acceptVowel char state
    -- otherwise, don't accept
    _ -> ( state, Cmd.none )


view : GameState -> Html msg
view state =
  node "main" [class "pure-u-20-24"] [
    (categoryDisplay state.category),
    (letterGrid state.puzzle state.lettersUsed),
    (theWheel wheelDefinition state.current state.target)
  ]

launchSpin : GameState -> ( GameState, Cmd msg)
launchSpin state =
  let playerState = state.playerState
  in
  case playerState of
    BeforeSpin -> ( { state | playerState = spinWheel wheelDefinition }, Cmd.none )
    ChooseAction -> ( { state | playerState = spinWheel wheelDefinition }, Cmd.none ) 
    SpinOrGuess -> ( { state | playerState = spinWheel wheelDefinition }, Cmd.none )
    _ -> (state, Cmd.none)

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
