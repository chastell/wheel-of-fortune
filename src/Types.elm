module Types exposing (..)

import Array exposing (Array)
import Set exposing (Set)
import Random exposing (Generator)

type PlayerState = Dead
                   | BeforeSpin -- only action available is spin
                   | Spinning -- wait for spin to end
                   | SpinSuccessConsonant -- spin rolled a number, can guess
                   | SpinSpecial -- spin rolled a special field
                   | ChooseAction -- can now spin, buy vowel or guess
                   | SpinOrGuess -- no more vowels, can now spin or guess
                   | MustGuess -- final round? only action is to guess
                   | GuessVowel
                   | TurnLost -- lost, advance to next player. Useless?

type alias Player = { name : String, score: Int, wildcard: Bool }

type alias GameState = { players : List Player, 
                         mods: Mods,
                         currentPlayer : Int,
                         playerState : PlayerState,
                         lettersUsed : List Char,
                         puzzle: List String,
                         category: String,
                         current: Int,
                         -- NOTE: this is just (get current wheelDefinition.sectors)
                         wheelState : Maybe WheelSector,
                         -- NOTE: this is just the index of wheelState's sector
                         target: RotationTarget,
                         rng: Generator Int
                       }

type Msg = NoOp 
           | KeyPressed Char
           | NextPlayerCommand
           | SpinCommand
           | SpinTo Int
           | SpinComplete
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

type alias RotationTarget = Maybe Int

-- for these, the Int is player on whose turn it is to end
type Modifier = Multiplier (Int, String, Float) -- icon, multiplier
                | UpsideDown Int
                | Shuffled Int
                | Malfunction Int

type alias Mods = Set Modifier

-- not a type, but useful to many modules

transparency = "#f0f"
