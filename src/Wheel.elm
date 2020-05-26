module Wheel exposing (theWheel)

import Types exposing (..)
import Html exposing (Html, node)
import Html.Attributes exposing (class, id)
import Svg exposing (Svg, svg, path, style, text, text_, g, circle, animateTransform)
import Svg.Attributes as SA
import Svg.Events as SE
import List exposing (length, range, indexedMap, foldl, concatMap, append)
import Array exposing (Array, get)
import String exposing (fromFloat, fromInt)
import Json.Decode as JD
import Debug exposing (log)

theWheel: WheelDef -> Int -> RotationTarget -> Html Msg
theWheel defn current target =
  node "wof-container" [ class "pure-u-1" ] [
    peg,
    node "wof" [] [
      svg [ SA.id "circle", SA.class "pure-u-1",
            SA.width "200", SA.height "200", SA.viewBox "-1 -1 2 2" ]
          [ textStyles, (wheelAndText defn current target), innerCircle ]
      ]
  ]

peg = svg [ SA.class "peg", SA.width "50", SA.height "50", SA.viewBox "-1 -1 2 2" ]
          [ path [ SA.d "M-1 -1 L0 1 L1 -1", SA.fill "#000" ] [] ]

textStyles = style [] [
    text ".light { font: normal 0.1px serif; fill: white; }",
    text ".dark { font: normal 0.1px serif; fill: black; }",
    text ".symbol { font: normal 0.2px serif; fill: black; }"
  ]

innerCircle = circle [ SA.cx "0", SA.cy "0", SA.r "0.4", SA.fill transparency ] []

getInitialAngle angle bias current target =
  let a = case target of
          Just n ->
            if current == n then
              log "gia at-target" (-angle * (toFloat current) + bias)
            else
              log "gia not-at-target" bias
          Nothing ->
            -- if target is not set, we're not animating. use current to calculate resting angle
            log "gia no-target-set" (-angle * (toFloat current) + bias)
  in 180 * a / pi

wheelAndText : WheelDef -> Int -> RotationTarget -> Svg Msg
wheelAndText defn current target = 
  let c_ = log "wat current" current
      t_ = log "wat target" target
      numSectors = Array.length defn.sectors
      angle = (2 * pi) / (toFloat numSectors)
      bias = -pi / 2.0 - angle / 2.0
      biasDegrees = 180 * bias / pi
      initialAngle = log "initialAngle" (getInitialAngle angle bias current target)
      initialRotation = (String.concat ["rotate(", (fromFloat initialAngle), ")"])
      listSectors = (Array.toList defn.sectors)
      -- Could likely use a <defn> element with a single sector, then copy it with different matrix
      sectors = (indexedMap (sectorSlice defn.palette angle) listSectors )
      labels = (indexedMap (sectorLabel defn.palette angle) listSectors)
      animations = makeAnimations current target numSectors angle bias
  in
  g [ SA.id "wheel-and-text", SA.transform initialRotation ]
   (List.concat [sectors, labels, animations])
  
rotationAnim from to begin dur extra =
  let l_ = log "rotanim" { from=from, to=to, begin=begin, dur=dur, extra=extra }
  in
  animateTransform (List.append [ SA.attributeName "transform", SA.type_ "rotate",
                                  SA.begin begin, SA.dur dur, SA.from from, SA.to to ] extra) []

-- NOTE: could take a List/Array WheelSector instead of num ??
makeAnimations : Int -> RotationTarget -> Int -> Float -> Float ->  List (Svg Msg)
makeAnimations current target num angle bias = 
    case log "mkanim target" target of
      Just index ->
        if index == current then
          []
        else
          let currentAngle = angle * (toFloat current) + bias
              currentAngleDeg = 180 * currentAngle / pi
              -- the minus is key
              targetAngle = angle * (toFloat -index) + bias
              targetAngleDeg = 180 * targetAngle / pi
              dur = (1500 * (abs targetAngle) / pi)
          in
              -- NOTE: to not start the animations use begin=indefinite
              -- and call to javascripts .beginElement() on the first element to start
              [ rotationAnim (fromFloat currentAngleDeg) "-360" "1000ms" "2000ms" [ SA.calcMode "spline", SA.keySplines "0.32 0 0.67 0", SA.keyTimes "0 ; 1" ],
                rotationAnim "0" "-360" "3000ms" "2000ms" [],
                -- freeze is the key to make this work, otherwise animation resets
                -- duration here should not be fixed but depend on circle left
                rotationAnim "0" (fromFloat targetAngleDeg)
                             "5000ms" ((fromFloat dur) ++ "ms") [ 
                               SA.fill "freeze",
                               SA.calcMode "spline", SA.keySplines "0.16 1 0.3 1", 
                               SA.keyTimes "0;1",
                               SE.on "end" (JD.succeed SpinComplete)
                               ] 
                ]
      Nothing -> []
  

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
  sectorText [ SA.textAnchor "end", SA.dominantBaseline "middle",
               SA.x "0.95", SA.y "0", SA.class shade,
               SA.transform (transformMatrix ct st -st ct 0 0) ]
             content


transformMatrix : Float -> Float -> Float -> Float -> Float -> Float -> String
transformMatrix a b c d e f = 
  String.concat [ "matrix(", (fromFloat a), " ", (fromFloat b), " ", (fromFloat c), " ",
                  (fromFloat d), " ", (fromFloat e), " ", (fromFloat f), ")"]

-- TODO: fill with emoji
sectorText: List (Svg.Attribute msg) -> WheelSector -> Svg msg
sectorText attrs sec =
  let symbol = \t -> text_ ((SA.class "symbol") :: attrs) [ text t ]
      plain = \t -> text_ attrs [ text t ]
  in
  case sec of
    Guess val -> plain (fromInt val)
    Halt -> symbol "⛔"
    Bankrupt -> plain "BANKRUT"
    Stonks -> symbol "📈"
    Sunks -> symbol "📉"
    FreeVowel -> plain "AEIOU"
    WildCard -> symbol "🃏"

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
