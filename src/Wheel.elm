module Wheel exposing (theWheel, spinWheel)

import Types exposing (..)
import Html exposing (Html, node)
import Html.Attributes exposing (class, id)
import Svg exposing (Svg, svg, path, style, text, text_, g, circle, animateTransform)
import Svg.Attributes as SA
import List exposing (length, range, indexedMap, foldl, concatMap, append)
import Array exposing (Array, get)
import String exposing (fromFloat, fromInt)

theWheel: WheelDef -> Html msg
theWheel defn =
  node "wof-container" [ class "pure-u-1" ] [
    peg,
    node "wof" [] [
      svg [ SA.id "circle", SA.class "pure-u-1",
            SA.width "200", SA.height "200", SA.viewBox "-1 -1 2 2" ]
          [ textStyles, (wheelAndText defn), innerCircle ]
      ]
  ]

peg = svg [ SA.class "peg", SA.width "50", SA.height "50", SA.viewBox "-1 -1 2 2" ]
          [ path [ SA.d "M-1 -1 L0 1 L1 -1", SA.fill "#000" ] [] ]

textStyles = style [] [
    text ".light { font: normal 0.1px serif; fill: white; }",
    text ".dark { font: normal 0.1px serif; fill: black; }"
  ]

innerCircle = circle [ SA.cx "0", SA.cy "0", SA.r "0.4", SA.fill transparency ] []

-- NOTE: transform should be set to bias value, and then we rotate the svg itself?
wheelAndText : WheelDef -> Svg msg
wheelAndText defn = 
  let numSectors = Array.length defn.sectors
      angle = (2 * pi) / (toFloat numSectors)
      bias = -pi / 2.0 - angle / 2.0
      biasDegrees = 360.0 * bias / (2 * pi)
      initialRotation = (String.concat ["rotate(", (fromFloat biasDegrees), ")"])
      listSectors = (Array.toList defn.sectors)
      sectors = (indexedMap (sectorSlice defn.palette angle) listSectors )
      labels = (indexedMap (sectorLabel defn.palette angle) listSectors)
      animations = makeAnimations
  in
  g [ SA.id "wheel-and-text", SA.transform initialRotation ]
   (List.concat [sectors, labels, animations])
  

makeAnimations : List (Svg msg)
makeAnimations = 
  [ animateTransform [ SA.attributeName "transform", SA.type_ "rotate",
  SA.begin "0s", SA.dur "500ms", SA.from "0", SA.to "360",
  SA.repeatCount "indefinite"] [] ]

sectorSlice: (Array ColorDef) -> Float -> Int -> WheelSector -> Svg msg
sectorSlice palette angle num content =
  let startAngle = angle * (toFloat num)
      x0 = cos startAngle
      y0 = sin startAngle
      endAngle = angle * (toFloat num + 1)
      x1 = cos endAngle
      y1 = sin endAngle
      color = getColor palette num
  in
      path [ SA.d (sectorPath x0 y0 x1 y1), SA.fill (color) ] []


sectorPath: Float -> Float -> Float -> Float -> String
sectorPath x0 y0 x1 y1 = 
  String.concat [ "M ", fromFloat x0, " ", fromFloat y0, " ",
      "A 1 1 0 0 1 ", fromFloat x1, fromFloat y1, " ",
      "L 0 0" ]

sectorLabel: Array ColorDef -> Float -> Int -> WheelSector -> Svg msg
sectorLabel palette angle num content =
  let shade = getFill palette num
      textAngle = angle * (toFloat num) + angle / 2.0
      ct = cos textAngle
      st = sin textAngle
  in
  text_ [ SA.textAnchor "end", SA.dominantBaseline "middle",
          SA.x "0.95", SA.y "0", 
          SA.class shade,
          SA.transform (transformMatrix ct st -st ct 0 0)]
        [ text (sectorText content) ]


transformMatrix : Float -> Float -> Float -> Float -> Float -> Float -> String
transformMatrix a b c d e f = 
  String.concat [ "matrix(", (fromFloat a), " ", (fromFloat b), " ", (fromFloat c), " ",
                  (fromFloat d), " ", (fromFloat e), " ", (fromFloat f), ")"]

-- TODO: fill with emoji
sectorText: WheelSector -> String
sectorText sec = case sec of
                   Guess val -> fromInt val
                   Halt -> "STOP"
                   Bankrupt -> "BANKRUT"
                   Stonks -> "Stonks"
                   Sunks -> "Sunks"
                   FreeVowel -> "AEIOU"
                   WildCard -> "Q<3"

getColor: Array ColorDef -> Int -> String
getColor colors i =
  let len = Array.length colors
      index = remainderBy len i
      item = Array.get index colors
  in
      case item of
        Just (color, fill) -> color
        _ -> ""

getFill: Array ColorDef -> Int -> String
getFill colors i =
  let len = Array.length colors
      index = remainderBy len i
      item = Array.get index colors
  in
      case item of
        Just (color, fill) -> fill
        _ -> ""


-- NOTE: could take a List/Array WheelSector instead
-- Return new global state which contains a list of animations
-- to apply on the wheel. To match the js version:
-- 1. a fast rotation from current angle to 360
-- 2. two medium full rots
-- 3. slow rot to designated position
spinWheel : WheelDef -> PlayerState
spinWheel wheel =
  Spinning

