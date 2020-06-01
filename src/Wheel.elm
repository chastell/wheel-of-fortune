module Wheel exposing (theWheel, destroySector)

import Types exposing (..)
import Html exposing (Html, node)
import Html.Attributes exposing (class, id)
import Svg exposing (Svg, Attribute, svg, path, style, text, text_, g, circle, animateTransform)
import Svg.Attributes as SA
import Svg.Events as SE
import List exposing (length, range, indexedMap, foldl, concatMap, append)
import Array exposing (Array, get)
import String exposing (fromFloat, fromInt)
import Util exposing (weightedIndex)
import Json.Decode as JD
import Random exposing (Generator)
import Debug exposing (log)

-- A SVG viewbox is defined by its left and top coordinates, plus width and height.
-- This allows us to draw the wheel as a circle of radius 1, centered at (0,0)
unitSquare = "-1 -1 2 2"

theWheel: WheelDef -> Int -> RotationTarget -> Html Msg
theWheel defn current target =
  let numSectors = Array.length defn.sectors
      angle = (2 * pi) / (toFloat numSectors)
  in
  node "wof-container" [ class "pure-u-1" ] [
    peg,
    node "wof" [] [
      svg [ SA.id "circle", SA.class "pure-u-1",
            SA.width "200", SA.height "200", SA.viewBox unitSquare ]
          [ Svg.defs [] [ oneSector angle ],
            textStyles,
            (wheelAndText defn current target), 
            innerCircle ]
      ]
  ]

peg = svg [ SA.class "peg", SA.width "50", SA.height "50", SA.viewBox unitSquare ]
          [ path [ SA.d "M-1 -1 L0 1 L1 -1", SA.fill "#000" ] [] ]

textStyles = style [] [
    text ".light { font: normal 0.1px serif; fill: white; }",
    text ".dark { font: normal 0.1px serif; fill: black; }",
    text ".symbol { font: normal 0.2px serif; fill: black; }"
  ]

innerCircle = circle [ SA.cx "0", SA.cy "0", SA.r "0.4", SA.fill transparency ] []

degrees: Float -> Float
degrees angle = 180 * angle / pi

getInitialAngle angle bias current =
  let sectorAngle = -angle * (toFloat current) + bias
  in degrees sectorAngle

wheelAndText : WheelDef -> Int -> RotationTarget -> Svg Msg
wheelAndText defn current target = 
  let numSectors = Array.length defn.sectors
      angle = (2 * pi) / (toFloat numSectors)
      bias = -pi / 2.0 - angle / 2.0
      initialAngle = getInitialAngle angle bias current
      initialRotation = (String.concat ["rotate(", (fromFloat initialAngle), ")"])
      listSectors = Array.toList defn.sectors
      sectors = (indexedMap (sectorSlice defn.palette angle) listSectors )
      labels = (indexedMap (sectorLabel defn.palette angle) listSectors)
      animations = makeAnimations current target angle bias
  in
  g [ SA.id "wheel-and-text", SA.transform initialRotation ]
   (List.concat [ sectors, labels, animations])
  
rotationAnim: Float -> Float -> String -> String -> List (Attribute msg) -> Svg msg
rotationAnim from to begin dur extra =
  animateTransform (List.append [ SA.attributeName "transform", SA.type_ "rotate",
                                  SA.begin begin, SA.dur dur,
                                  SA.from (fromFloat from), SA.to (fromFloat to) ]
                                extra)
                   []

makeAnimations : Int -> RotationTarget -> Float -> Float ->  List (Svg Msg)
makeAnimations current target angle bias = 
    let index = Maybe.withDefault current target
        -- the minus is super important here
        currentAngle = angle * (toFloat -current) + bias
        currentAngleDeg = degrees currentAngle
        targetAngle = angle * (toFloat -index) + bias
        targetAngleDeg = degrees targetAngle
        dur = (1500 * (abs targetAngle) / pi)
    in
        [ rotationAnim currentAngleDeg -360 "1000ms" "2000ms"
          [ SA.calcMode "spline", SA.keySplines "0.32 0 0.67 0", SA.keyTimes "0 ; 1",
            SA.begin "indefinite", SA.id "initialSpin" ],
          rotationAnim 0 -360 "initialSpin.end" "2000ms" [ SA.id "fullRotations" ],
          -- freeze is the key to make this work, otherwise animation resets
          -- TODO: duration here should not be fixed but depend on circle left
          rotationAnim 0 targetAngleDeg
                       "fullRotations.end" ((fromFloat dur) ++ "ms") [ 
                         SA.fill "freeze",
                         SA.calcMode "spline", SA.keySplines "0.16 1 0.3 1", 
                         SA.keyTimes "0;1",
                         SE.on "end" (JD.succeed SpinComplete)
                         ] 
          ]
  

oneSector : Float -> Svg msg
oneSector angle = 
  path [ SA.id "oneSector", SA.d (sectorPath 1 0 (cos angle) (sin angle)) ] []

sectorSlice: (Array ColorDef) -> Float -> Int -> WheelSector -> Svg msg
sectorSlice palette angle num content =
  let a = angle * (toFloat num)
      ct = cos a
      st = sin a
      color = getColor palette num
  in
    Svg.use [ SA.xlinkHref "#oneSector",
              SA.transform (transformMatrix ct st -st ct 0 0),
              SA.fill color ] []

sectorPath: Float -> Float -> Float -> Float -> String
sectorPath x0 y0 x1 y1 = 
  String.concat [
      -- start the path at one of the points that lies on the circle.
      "M ", fromFloat x0, " ", fromFloat y0, " ",
      -- draw an arc to the other circle point. First two params are x and y radii, both 1 because of the coordinate system we use.
      -- third is axis rotation, which doesn't matter for circles, so is 0.
      -- Next are large-arc and sweep, best explained on MDN https://developer.mozilla.org/en-US/docs/Web/SVG/Tutorial/Paths
      -- And then our target coordinates.
      "A 1 1 0 0 1 ", fromFloat x1, " ", fromFloat y1, " ",
      -- Draw line to center point.
      "L 0 0"
      -- For filled paths, the last segment (from 0 0 to x0 y0) is implicit, and we can omit it.
      ]

sectorLabel: Array ColorDef -> Float -> Int -> WheelSector -> Svg msg
sectorLabel palette angle num content =
  let shade = getFill palette num
      textAngle = angle * (toFloat num) + angle / 2.0
      ct = cos textAngle
      st = sin textAngle
  in
  sectorText [ SA.textAnchor "end", SA.x "0.95", SA.class shade,
               SA.transform (transformMatrix ct st -st ct 0 0) ]
             content


transformMatrix : Float -> Float -> Float -> Float -> Float -> Float -> String
transformMatrix a b c d e f = 
  String.concat [ "matrix(", (fromFloat a), " ", (fromFloat b), " ", (fromFloat c), " ",
                  (fromFloat d), " ", (fromFloat e), " ", (fromFloat f), ")"]

sectorText: List (Svg.Attribute msg) -> WheelSector -> Svg msg
sectorText attrs sec =
  let symbol = \t -> 
        text_ (List.append [SA.class "symbol", SA.rotate "90", SA.y "-0.1"] attrs) [ text t ]
      plain = \t ->
        text_ (List.append [SA.dominantBaseline "middle", SA.y "0"] attrs) [ text t ]
  in
  case sec of
    Guess val -> plain (fromInt val)
    Halt -> symbol "⛔"
    Bankrupt -> symbol "🦹"
    Stonks -> symbol "📈"
    Sunks -> symbol "📉"
    FreeVowel -> symbol "🆓"
    WildCard -> symbol "🃏"
    BoardMalfunction -> symbol "👺" -- a malicious Tengu trickster
    Bomb -> symbol "💣"
    FlipLetters -> symbol "🌀"

getColor: Array ColorDef -> Int -> String
getColor colors i =
  let index = remainderBy (Array.length colors) i
      item = Array.get index colors
  in
      case item of
        Just (color, fill) -> color
        _ -> ""

getFill: Array ColorDef -> Int -> String
getFill colors i =
  let index = remainderBy (Array.length colors) i
      item = Array.get index colors
  in
      case item of
        Just (color, fill) -> fill
        _ -> ""

isGuess sector = case sector of
  Guess _ -> True
  _ -> False

destroySector : WheelDef -> Float -> Int -> Generator Float -> (WheelDef, Generator Float)
destroySector wheel weighted current rng =
  let sectors = wheel.sectors
      numSectors = Array.length sectors
  in
    if numSectors <= 8 then
      -- Do nothing if number of sectors falls below some useful value
      let l_ = log "fast exit, not enough sectors"
      in
      (wheel, rng)
    else if List.length (List.filter isGuess (Array.toList wheel.sectors)) < 4 then
      -- Also exit if not enough guess fields left
      let l_ = log "fast exit, not enough guess fields" 1
      in
          (wheel, rng)
    else
      -- Never destroy the sector we're on, which means that the bomb sector always survives.
      -- TODO: consider a better solution
      let index = weightedIndex weighted wheel.weights
          toRemove = if index == current then index + 1 else index
          removeIndex = remainderBy numSectors toRemove
          newLength = numSectors - 1
          seclist = Array.toList sectors
          remover = \n list -> List.append (List.take n list) (List.drop (n + 1) list)
          newsecs = Array.fromList (remover removeIndex seclist)
          newrng = Random.int 0 (newLength - 1)
      in
          ({ wheel | sectors = newsecs }, rng)


