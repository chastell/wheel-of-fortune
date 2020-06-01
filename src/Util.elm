module Util exposing (weightedIndex, normalizeWeights)

-- value is a float in range 0..List.sum weights
weightedIndex : Float -> List Float -> Int
weightedIndex value weights =
  case (findCumSum value weights 0) of
    Just index -> index
    Nothing -> 0 -- fallback

-- in a list of [a,b,c,d]
-- find first position where [a, b+a, c+b+a, d+c+b+a] is greater than y
findCumSum : Float -> List Float -> Int -> Maybe Int
findCumSum y weights index =
  case weights of
    [] -> Nothing
    x :: tail ->
      if y <= x then Just index
      else findCumSum (y - x) tail (index + 1)


-- normalize list of length N so that its items sum to N
normalizeWeights: List Float -> List Float
normalizeWeights weights =
  let n = toFloat (List.length weights)
      sum = List.sum weights
  in
      List.map (\x -> x * n / sum) weights
