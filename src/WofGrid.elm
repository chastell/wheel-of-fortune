module WofGrid exposing (letterGrid)

import Html exposing (Html, div, node, text)
import Html.Attributes exposing (class, id)
import String exposing (fromChar, fromInt)
import List exposing (map2, range, map, concatMap, member)

type Facing = Left | Front | Right | Back

letterGrid : List String -> List Char -> Html msg
letterGrid textRows exposed =
  let rows = range 0 3
      indexedRows = map2 Tuple.pair rows textRows
  in
  node "letter-grid" [] (
    concatMap (gridRow exposed) indexedRows
    )

type alias HtmlRow a = List (Html a)

gridRow : List Char -> (Int, String) -> HtmlRow msg
gridRow exposed (row, letters) =
  let cols = range 0 13
      indexedCols = map2 Tuple.pair cols (String.toList letters)
  in
  map (cubeBox exposed row) indexedCols

cubeBox : List Char -> Int -> (Int, Char) -> Html msg
cubeBox exposed row (col, letter) =
  div
    [ class "box", id (String.join "-" ["box", (fromInt row), (fromInt col)]) ]
    [ if letter == '.' then
        blankCube
      else
        cube (Just letter) (facingExposed exposed letter)
      ]

cube : Maybe Char -> Facing -> Html msg
cube letter facing =
  div
    [ class "cube",
    class (case facing of
           Left -> "show-left"
           Front -> "show-front"
           Right -> "show-right"
           Back -> "show-back")
    ]
    [ div [ class "face", class "face-front" ] [],
      div [ class "face", class "face-back" ] [],
      div [ class "face", class "face-right" ] 
        (case letter of
          Just l -> [ div [] [ text (fromChar l) ] ]
          _ -> []
          ),
      div [ class "face", class "face-left" ] []
    ]

-- TODO: setup blank cubes with random emoji on the right side
blankCube : Html msg
blankCube = cube Nothing Left

letterCube letter = cube letter Front

facingExposed: List Char -> Char -> Facing
facingExposed exposed letter =
  if (member letter exposed) then
    Right
  else
    Front

