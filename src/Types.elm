module Types exposing (..)

import Array exposing (Array)

type PlayerState = Dead
                   | BeforeSpin -- only action available is spin
                   | Spinning -- wait for spin to end
                   | SpinSuccessConsonant -- spin rolled a number, can guess
                   | SpinSpecial -- spin rolled a special field
                   | ChooseAction -- can now spin, buy vowel or guess
                   | SpinOrGuess -- no more vowels, can now spin or guess
                   | MustGuess -- final round? only action is to guess
                   | TurnLost -- lost, advance to next player. Useless?

type alias Player = { name : String, score: Int }

type alias GameState = { players : List Player, 
                         currentPlayer : Int,
                         playerState : PlayerState,
                         lettersUsed : List Char,
                         puzzle: List String,
                         category: String,
                         wheelState : Maybe WheelSector
                       }

type Msg = NoOp 
           | KeyPressed Char
           | NextPlayerCommand
           | SpinCommand
           | RevealCommand

type WheelSector = Guess Int
                   | Halt
                   | Bankrupt
                   | Stonks
                   | Sunks
                   | FreeVowel
                   | WildCard

type alias ColorDef = (String, String)

type alias WheelDef = { sectors: Array WheelSector, palette: Array ColorDef }

-- not a type, but useful to many modules

transparency = "#f0f"
