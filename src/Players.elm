module Players exposing (playerList, modIcons, buildNewPlayer)

import Html exposing (Html, text, ul, li, span, div)
import Html.Attributes exposing (class, id)
import Html.Events exposing (onClick)
import List exposing (map, indexedMap)
import String exposing (String)
import Types exposing (..)

modText : Modifier -> Html msg
modText mod = 
  let symbol = \t -> span [ class t ] [ ]
  in
  case mod of
    Multiplier tuple (label, mul) ->
      if mul > 1.0 then
        symbol "chart-up"
      else
        symbol "chart-down"
    UpsideDown n -> symbol "updown"
    Shuffled n -> symbol "shuffled"
    Malfunction n -> symbol "malfunction"

modIcons : List Modifier -> Html msg
modIcons mods =
  Html.node "mods" [] (List.map modText mods)

playerList : List Player -> Int -> PlayerState -> Html Msg
playerList players current state =
  div [] [
    ul [id "scores"] (indexedMap (playerEntry current) players),
    ul [id "actions"] (availableActions state)
    ]

playerEntry : Int -> Int -> Player -> Html msg
playerEntry index current player =
  li [ class (if index == current then "active" else "") ] [
    span [ class "player-name" ] [
      text player.name,
      if player.wildcard then text "🃟" else text ""
      ],
    span [ class "player-score" ] [ text (String.fromInt player.score) ]
    ]

availableActions : PlayerState -> List (Html Msg)
availableActions state =
  case state of
    BeforeSpin -> [ li [] [ spinButton ] ]
    SpinSuccessConsonant -> [ li [] [ guessButton ] ]
    SpinSpecial -> [ ] -- depends, really
    ChooseAction -> [
      li [] [ spinButton ],
      li [] [ vowelButton ],
      li [] [ guessButton ]
      ]
    SpinOrGuess -> [ li [] [ spinButton ], li [] [ guessButton ] ]
    GuessVowel -> [ li [] [ vowelButton ] ]
    MustGuess -> [ li [] [ mustGuessButton ] ]
    -- useless states
    Spinning -> []
    TurnLost -> []
    Dead -> []


spinButton : Html Msg
spinButton = Html.button [ onClick SpinCommand, class "spin" ] [ text "Spin" ]
guessButton = Html.button [ class "guess" ] [ text "Guess" ]
mustGuessButton = Html.button [ class "guess", onClick RevealCommand ] [ text "Guess!" ]
vowelButton = Html.button [ class "vowel" ] [ text "Buy Vowel" ]

buildNewPlayer : String -> Player
buildNewPlayer name = { name = name, score = 0, wildcard = False }
