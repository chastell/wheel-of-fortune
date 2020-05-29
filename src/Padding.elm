module Padding exposing (padPuzzle)

padRow : Int -> String -> String
padRow width text =
  let textLen = String.length text
      padWidth = (width - textLen) // 2
      padLeft = String.repeat padWidth "."
      padRight = String.repeat (width - textLen - padWidth) "."
  in
      padLeft ++ text ++ padRight

padToBoard : Int -> Int -> List String -> List String
padToBoard width height rows =
  let padding = String.repeat width "."
      rowCount = List.length rows
  in
      if rowCount == height then
        rows
      else if (remainderBy 2 rowCount) == 0 then
        padToBoard width height (padding  :: rows)
      else
        padToBoard width height (List.append rows [padding])

padPuzzle : Int -> Int -> String -> List String
padPuzzle width height input =
  let noSpaces = String.replace " " "." input
      rows = String.split "|" noSpaces
      paddedRows = List.map (padRow width) rows
  in
      padToBoard width height paddedRows
