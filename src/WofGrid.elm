module WofGrid exposing (letterGrid)

import Html exposing (Html, div, node, text)
import Html.Attributes exposing (class, id, style)
import String exposing (fromChar, fromInt)
import List exposing (map2, range, map, concatMap)
import Set exposing (Set)

type Facing = Left | Front | Right | Back

letterGrid : List String -> Set Char -> Bool -> Bool -> Html msg
letterGrid textRows exposed malfunction flipped =
  let rows = range 0 3
      indexedRows = map2 Tuple.pair rows textRows
      renderRow = \irow -> gridRow exposed irow malfunction flipped
      renderedRows = concatMap renderRow indexedRows
  in
  node "letter-grid" [] (
    if flipped then (List.reverse renderedRows) else renderedRows
    )

type alias HtmlRow a = List (Html a)

gridRow : Set Char -> (Int, String) -> Bool -> Bool -> HtmlRow msg
gridRow exposed (row, letters) malfunction flipped =
  let cols = range 0 13
      indexedCols = map2 Tuple.pair cols (String.toList letters)
  in
  map (cubeBox exposed malfunction flipped row) indexedCols

cubeBox : Set Char -> Bool -> Bool -> Int -> (Int, Char) -> Html msg
cubeBox exposed malfunction flipped row (col, letter) =
  let boxid = (String.join "-" ["box", (fromInt row), (fromInt col)])
      stagger = prng row col
  in
  div
    [ class "box", id boxid ]
    [ if letter == '.' then
        blankCube
      else
        cube (Just letter) (facingExposed exposed letter) malfunction flipped stagger
      ]

cube : Maybe Char -> Facing -> Bool -> Bool -> Int -> Html msg
cube letter facing malfunction flipped stagger =
  let delay = fromInt (10 * stagger)
      speed = "2s" -- cube rotation time when malfunctioning
      facingClass = case facing of
         Left -> "show-left"
         Front -> "show-front"
         Right -> "show-right"
         Back -> "show-back"
      animation = if malfunction && facing == Right then
          [ style "animation" ("rotate-vert-left " ++ speed ++ " linear " ++ delay ++ "ms infinite both") ]
        else
          []
      orientation = if flipped && facing == Right then
          [ class "flipped" ]
        else
          []
  in
  div
    (List.append [ class "cube", class facingClass ] animation)
    [ div [ class "face", class "face-front" ] [],
      div [ class "face", class "face-back" ] [],
      div [ class "face", class "face-right" ] 
        (case letter of
          Just l -> [ div orientation [ text (fromChar l) ] ]
          _ -> []
          ),
      div [ class "face", class "face-left" ] []
    ]

blankCube : Html msg
blankCube = cube Nothing Left False False 0

letterCube letter = cube letter Front

facingExposed: Set Char -> Char -> Facing
facingExposed exposed letter =
  if (Set.member letter exposed) then Right else Front

-- Not a real random number generator.
-- Calculates a value that is constant per input args, but different for
-- neighboring pairs
prng : Int -> Int -> Int
prng y x =
  remainderBy 113 (513 * x * x + 91 * x + 179 * y * y * y + 233 * y * y - 71 * y)
