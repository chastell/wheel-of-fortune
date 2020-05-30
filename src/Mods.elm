module Mods exposing (expireMods, isMalfunction, calculateFlipState, modIcons)

import Html exposing (Html, span)
import Html.Attributes exposing (class, id)
import Types exposing (..)

expirationTurn : Modifier -> Int
expirationTurn mod =
  case mod of
    Multiplier n _ -> n
    UpsideDown n -> n
    Malfunction n -> n

expireMods : List Modifier -> Int -> List Modifier
expireMods mods playernum =
  let keep = \mod -> (expirationTurn mod) /= playernum
  in List.filter keep mods

isMalfunction : Modifier -> Bool
isMalfunction mod = case mod of
  Malfunction _ -> True
  _ -> False

isFlipped : Modifier -> Bool
isFlipped mod = case mod of
  UpsideDown _ -> True
  _ -> False

-- Flip mods stack: two flips cancel each other out.
-- Check for an odd number of flips in the mod list, 
calculateFlipState : List Modifier -> Bool
calculateFlipState mods =
  let flipcount = List.length (List.filter isFlipped mods)
  in (remainderBy 2 flipcount) == 1

modText : Modifier -> Html msg
modText mod = 
  let symbol = \t -> span [ class t ] [ ]
  in
  case mod of
    Multiplier tuple (label, mul) ->
      if mul > 1.0 then symbol "chart-up" else symbol "chart-down"
    UpsideDown n -> symbol "updown"
    Malfunction n -> symbol "malfunction"

modIcons : List Modifier -> Html msg
modIcons mods =
  Html.node "mods" [] (List.map modText mods)

