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
import Wheel exposing (theWheel, destroySector)
import Players exposing (..)
import Mods exposing (..)
import Puzzle exposing (acceptConsonant, acceptVowel, reveal, reset, setBoard)
import Util exposing (weightedIndex, normalizeWeights)
import Json.Decode as Decode
import Random
import Process
import Task
import Debug exposing (log)


fullSectors = Array.fromList [ FreeVowel, Guess 100, Guess 250, BoardMalfunction, Guess 500,
                               Stonks, Guess 150, Guess 300, Guess 1500, Bankrupt, 
                               Guess 400, Guess 200, Sunks, Guess 500, Halt, 
                               Guess 350, Guess 450, WildCard, Guess 300, FlipLetters, 
                               Guess 400 ]

fullWeights = normalizeWeights [ 0.8, 1, 1, 0.1, 1, 
                                 0.3, 1, 1, 0.5, 0.2, 
                                 1, 1, 0.3, 1, 0.4,
                                 1, 1, 0.5, 1, 0.1,
                                 1 ]


-- Use for debugging, or assign your own
shortSectors = Array.fromList [Bomb, Guess 100, Guess 200,  Guess 400, Halt]
shortWeights = [ 0.5, 2, 1, 1, 0.5 ]

wheelDefinition = { sectors = fullSectors,
                    -- use List.repeat n 1.0 for an equally weighted wheel
                    weights = fullWeights,
                    palette = Array.fromList [ ("#729ea1", "dark"), ("#b5bd89", "dark"), ("#dfbe99", "dark"), ("#ec9192", "dark"), ("#db5375", "dark"), ("#3e4e50", "light"), ("#f2aa7e", "dark"), ("#6c756b", "light"), ("#96c5f7", "dark") ] }


initialPlayers = [
  let p = (initPlayer "Mario") in { p | wildcard = True },
  initPlayer "Peach",
  initPlayer "Luigi",
  initPlayer "Toad"
  ]

initPlayer: String -> Player
initPlayer name = { name = name, score = 0, wildcard = False }

main = Browser.element { init = init, update = update, view = view, subscriptions = subscriptions }

init : () -> ( GameState, Cmd msg )
init _ = let totalWeight = List.sum wheelDefinition.weights
             state = { players = initialPlayers,
                 currentPlayer = 0, playerState = BeforeSpin,
                 current = 0,
                 mods = [],
                 lettersUsed = Set.empty,
                 puzzle = [ ".PAN.TADEUSZ..", "....CZYLI.....", "OSTATNI.ZAJAZD", "..NA.LITWIE..." ],
                 category = "Tytuł",
                 wheel = wheelDefinition,
                 target = Nothing,
                 rng = Random.float 0 totalWeight
               }
         in ( state, Cmd.none )

-- list access by index
nth : Int -> List a -> Maybe a
nth i list = List.drop i list |> List.head

replaceNth : Int -> a -> List a -> List a
replaceNth index new list =
  let replacer = (\i elem -> if i == index then new else elem)
  in List.indexedMap replacer list

port animationLauncher : () -> Cmd msg
port setPuzzleText : (List String -> msg) -> Sub msg
port setPlayers : (List String -> msg) -> Sub msg

update : Msg -> GameState -> ( GameState, Cmd Msg )
update msg state =
  case log "update-msg" msg of
    KeyPressed char -> handleLetterKey state char
    SpinCommand -> launchSpin state
    SpinTo weighted ->
      let num = weightedIndex weighted state.wheel.weights 
      in
      if num == state.current then
        -- Try to never spin same value twice
        launchSpin state
      else
        ( { state | target = Just num }, animationLauncher () )
    SpinComplete -> 
      case state.target of
        Just n ->
          case (Array.get n state.wheel.sectors) of
            Just sec -> advanceFromSector n state sec
            _ -> ( state, Cmd.none )
        _ -> ( state, Cmd.none )
    NextPlayerCommand ->
      let numPlayers = List.length state.players
          nextPlayer = remainderBy numPlayers (state.currentPlayer + 1)
          mods = expireMods state.mods nextPlayer
      in
          ( { state | currentPlayer = nextPlayer, mods = mods,
              playerState = BeforeSpin }, Cmd.none )
    RevealCommand -> ( reveal state, Cmd.none )
    SetPuzzleCommand step text category ->
      case step of
        False -> ( reset state text category, 
               Process.sleep 1000 |>
               Task.perform (always (SetPuzzleCommand True text category)) )
        True -> ( setBoard state text category, Cmd.none )
    SetPlayersCommand newPlayers ->
      ( { state | players = newPlayers, currentPlayer = 0, playerState = BeforeSpin }, Cmd.none )
    DestroySector weightedIndex ->
      let (newWheel, newRng) = destroySector state.wheel weightedIndex state.current state.rng
      in
      ( { state | wheel = (log "newWheel" newWheel), playerState = BeforeSpin,
                  rng = newRng },
        Cmd.none )
    NoOp -> ( state, Cmd.none )

-- TODO: kick to module?
advanceFromSector : Int -> GameState -> WheelSector -> ( GameState, Cmd Msg )
advanceFromSector n state sector =
  let player = nth state.currentPlayer state.players
      landedState = { state | current = n, target = Nothing }
  in
      case (player, sector) of
        (Just(_), Guess val) ->
          ( { landedState | playerState = SpinSuccessConsonant }, Cmd.none )
        (Just(p), Halt) ->
          -- with wildcard: consume it, don't lose turn
          if p.wildcard then
            let playerchanged = { p | wildcard = False }
                updatedPlayers = replaceNth state.currentPlayer playerchanged state.players
            in
                ( { landedState | players = updatedPlayers, playerState = BeforeSpin }, Cmd.none )
          else
            update NextPlayerCommand landedState
        (Just(p), Bankrupt) ->
          -- with wildcard: consume it, lose turn, but don't bankrupt.
          let playerchanged = if p.wildcard then
                                { p | wildcard = False }
                              else
                                { p | score = 0 }
              updated = replaceNth state.currentPlayer playerchanged state.players
          in
              update NextPlayerCommand { landedState | players = updated }
        (Just(_), FreeVowel) -> ( { landedState | playerState = GuessVowel }, Cmd.none )
        -- IDEA: new sector type, with a bomb icon. When landed on, a random sector is removed from the wheel and the player spins again.
        (Just(p), WildCard) ->
          let playerchanged = { p | wildcard = True }
              updated = replaceNth state.currentPlayer playerchanged state.players
          in
              ( { landedState | playerState = BeforeSpin, players = updated }, Cmd.none )
        (Just(_), Stonks) ->
          let mul = Multiplier state.currentPlayer ("STONKS", 2.0)
          in
              ( { landedState | mods = mul :: state.mods, playerState = BeforeSpin }, Cmd.none )
        (Just(_), Sunks) ->
          let mul = Multiplier state.currentPlayer ("SUNKS", 0.5)
          in
              ( { landedState | mods = mul :: state.mods, playerState = BeforeSpin }, Cmd.none )
        (Just(_), BoardMalfunction) ->
          let mal = Malfunction state.currentPlayer
          in
              ( { landedState | mods = mal :: state.mods, playerState = BeforeSpin }, Cmd.none )
        (Just(_), Bomb) ->
          -- The bomb state is not very fun in its current version.
          -- Maybe it could remove both itself and a random other tile?
          ( { landedState | playerState = BeforeSpin }, Random.generate DestroySector state.rng )
        (Just(_), FlipLetters) ->
          let upd = UpsideDown state.currentPlayer
          in
              ( { landedState | mods = upd :: state.mods, playerState = BeforeSpin }, Cmd.none )
        -- this branch could be (_, ). But keeping it this way makes Elm enforce
        -- exhaustive matching over board sectors.
        (Nothing, _) -> ( state, Cmd.none )

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
      SpinOrGuess -> ( newGameState, Cmd.none )
      ChooseAction -> ( newGameState, Cmd.none )
      _ -> ( state, Cmd.none )

view : GameState -> Html Msg
view state =
  let malfunction = List.any isMalfunction state.mods
      flipped = calculateFlipState state.mods
  in
  div [class "pure-g"] [
    node "main" [class "pure-u-20-24"] [
      (categoryDisplay state.category),
      (letterGrid state.puzzle state.lettersUsed malfunction flipped),
      (theWheel state.wheel state.current state.target)
      ],
    node "sidebar" [class "pure-u-4-24"] [
      (modIcons state.mods),
      (playerList state.players state.currentPlayer state.playerState)
      ]
  ]

categoryDisplay : String -> Html msg
categoryDisplay cat = 
  node "category" [class "pure-u-1"] [text cat]

launchSpin : GameState -> (GameState, Cmd Msg)
launchSpin state =
  let playerState = state.playerState
      canSpin = List.member playerState [
        BeforeSpin, ChooseAction, SpinOrGuess,
        -- allow launching for this state, needed when RNG rolls current value again
        Spinning ]
  in
  if canSpin then
    spinRNG state
  else
    (state, Cmd.none)

spinRNG: GameState -> (GameState, Cmd Msg)
spinRNG state =
  ( { state | playerState = Spinning }, Random.generate SpinTo state.rng )

subscriptions : GameState -> Sub Msg
subscriptions state =
  Sub.batch [ Browser.Events.onKeyUp keyDecoder,
              setPuzzleText (\l -> case l of
                text :: category :: [] ->
                  SetPuzzleCommand False text category
                _ ->
                  NoOp),
              setPlayers (\l -> SetPlayersCommand (List.map buildNewPlayer l))
              ]

keyDecoder : Decode.Decoder Msg
keyDecoder =
  Decode.map3 toKey (Decode.field "key" Decode.string)
                    (Decode.field "ctrlKey" Decode.bool)
                    (Decode.field "altKey" Decode.bool)

toKey : String -> Bool -> Bool -> Msg
toKey inp ctrl alt =
  if ctrl || alt then
    NoOp
  else
    case String.uncons inp of
      -- Funky syntax, but useful for pattern matching on single character
      Just ( ' ', "" ) -> NextPlayerCommand
      Just ( 'E', "nter" ) -> SpinCommand
      Just ( '!', "") -> RevealCommand
      Just ( char, "" ) -> KeyPressed (Char.toUpper char)
      _ -> NoOp
