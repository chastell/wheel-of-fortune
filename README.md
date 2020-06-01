# Wheel of fortune for videocalls

This is a browser version of the popular TV format "Wheel of Fortune", implemented in Elm. It is intended to be played online, but in a specific way, which is explained down the line. It is somewhat usable in hot-seat mode, although one person must take on the role of host.


## Why elm?

This was a fun side project, a weekend dabble. I actually created it first in very ugly and hacky Javascript, what you see here is an improved rewrite.

I wanted to try creating a real (albeit small) project in some less known language. The choices therefore were either Elm, ReasonML or ClojureScript. I chose Elm, because it has a fairly small runtime (versus the other two) and a **super-helpful** compiler. It even puts the Rust compiler to shame. Also, the language itself is fairly small - there are just a handful of concepts to learn. 


## Features

* Construct your own wheel using reward fields and many actions.
* Buffs/debuffs which modify the game!
* Likely usable only for alphabet-based languages, not ones that use ideograms or logograms (like Chinese), syllabaries (like Japanese), abjads (Arabic, Hebrew) or abugidas (like Tamil or Thai). However, many countries using these writing systems _did have_ their editions of the TV show, so it may work out for you.
* Will accept any letter your keyboard produces. Needs tweaking to know what the vowels for your language are, comes with defaults for Polish.
* Annoying magenta background.
* Devtools-based management.


# Building

1. [Install elm](https://guide.elm-lang.org/install/elm.html)
2. Run `make` in the project directory
3. Launch a webserver in the project directory and navigate to `index.html`


# Developing

1. [Install elm](https://guide.elm-lang.org/install/elm.html) and [entr](http://eradman.com/entrproject/)
2. Run `elm reactor` in the project directory, and `find src/ | entr -s make` alongside.
3. Navigate to `localhost:8000` (or whatever port the reactor runs on) and open `src/Main.elm`. This is automatically compiled by the reactor, but lacks styles and JS interop. This is where you'll read compiler errors in detail.
4. Navigate to `localhost:8000/index.html` for the full page. The `entr + make` command automatically builds the js bundle on save, but will fail on errors - this is when you read the previous tab.


# Manual

## Keyboard shortcuts

* <kbd>⏎</kbd>: spin wheel, only if allowed in the current state. If the "Spin" button is visible, you can use Enter instead of clicking it.
* <kbd>Space</kbd>: skip to next player. The game tracks it automatically, but you may still use it whenever a player can take action.
* <kbd>Any letter</kbd>: on a player's turn, try guessing that letter. Depending on state, a consonant or vowel is required, using the wrong one will concede the turn. Guessing wrongly will also concede, obviously. If the "Guess" button is visible, this is when to use it (because clicking the button does nothing)
* <kbd>!</kbd>: Reveal the whole board. Use when a player correctly guesses the entire password. Does not end the game, but the host should then jump to devtools and set a new puzzle.

## Devtools

There are two elm _ports_ (interfaces for communicating with Javascript), and two functions that are available on console:

### `loadPuzzle(text, category)`

Resets board, sets new puzzle, allows the current player to spin again. Does not change the current player (use the Space key if you need to).

Puzzle is passed as a single string, using dots (`.`) for covered fields. These are both side padding and any whitespace. Rows are separated by vertical bars (`|`). Row width may not exceed 14 characters, and strange things may happen if it does.

It is enough to just lay the words across rows, as necessary padding will be added automatically to keep the puzzle centered. If it has less than four rows, empty rows will be added as necessary. If a row is not 14 characters wide, padding dots will be added on both sides.

Category is just a single string, and will be displayed constantly above the letter board.

Example:

```
loadPuzzle("HELLO|WORLD", "Computer greeting")
// equivalent to
loadPuzzle("..............|.....HELLO....|.....WORLD....|..............", "Computer greeting")
```
### `setPlayers("player1", "player2", ...)`

Changes the player list, resetting scores to zero. Sets first named player as current. There is no limit to the number of players, except that a lot of waiting for one's turn makes a boring game.


## Game mechanics explained

In each turn, the player always starts with spinning the wheel.
If the result is a score field (with numbers), the player must guess a consonant. This is realized by the host typing that character on their keyboard.
If successful, all instances of that letter are revealed, and she gains the landed amount multiplied by number of letters revealed.
Next, the player is given a choice: to spin again, buy a vowel for 200 points, or to guess the entire puzzle. 
Buying a vowel is only available if the player has more than 200 points, and always costs 200 points. Guessing correctly reveals all instances of that letter, and the player may spin or guess the puzzle.
Guessing the puzzle has no game mechanic other than the host verifying and revealing on success, or skipping the player's turn on failure.

Fields other than numbers are actions, which alter the game flow in some way. Here's a list:

* Joker card: current player gains a wildcard, indicated by a card icon next to their name. If they already had one, nothing happens. In both cases, player spins again.
* No entry sign: lose turn. If player had a wildcard, it is consumed, and turn is not lost, player spins again.
* Masked supervillain: bankrupt, player loses all points and the turn. If player had a wildcard, she keeps the points, but still loses a turn.
* "FREE" text: player guesses a vowel, without paying for it. If guess was correct, player can spin again.
* All following entries are buffs or debuffs, which always last for everyone until the current player's next turn. Active ones are displayed in the bottom right area, with the same icons that are used on the board. (This is where the host can use skipping turns to remove the modifiers manually)
* Chart pointing up: 2x multiplier to points scored by guessing consontants. Multipliers stack - if another one is landed on, 4x multiplier etc.
* Chart pointing down: ½ multiplier to points scored by guessing. Stacks.
* Cyclone icon: board is displayed upside-down
* Angry red face/Japanese goblin: board malfunction. Revealed letters will spin in place until the effect expires, making the board harder to read.

# Using on a videoconference

Tools required:

1. [OBS](https://obsproject.com)
2. A virtual cam module for your system, see below. You may get away with just screensharing, but it's less fun.
3. A modern browser
4. Your videocall program or WebRTC-enabled browser. Some have annoying quirks, check their section below for tips. If you don't have a preferred one, [Jitsi](https://meet.jit.si) is nice to work with.

## Virtual cams

A virtual cam module is any piece of software that exposes itself to other apps as a regular webcam, but is fed video data from other sources. We need one that works with OBS.

On Windows, use [OBS Virtualcam](https://obsproject.com/forum/resources/obs-virtualcam.949/).
On Linux, first install [v4l2-loopback](https://github.com/umlaeute/v4l2loopback) for your distribution, load the module, then use [v4l2sink](https://github.com/CatxFish/obs-v4l2sink) in OBS. You may want to enable the exclusive-caps mode for v4l2loopback if Chrome/Chromium doesn't cooperate.
On macOS, use [obs-mac-virtualcam](https://github.com/johnboiles/obs-mac-virtualcam).



## Setting up OBS, easy mode

1. You'll start with a default empty scene. Add a window capture source.
2. Point it to the browser window that is running wheel-of-fortune.
3. Right click that source in the list, select Filters, add Chroma Key filter, set chroma key color to magenta. Stretch it as necessary.
4. Add your prefered background as an image source, reorder it to be after the capture.
5. Add a video input source, using your actual webcam. Position it so that it doesn't obscure anything.
6. Launch your virtualcam module from Tools menu

Now launch your videoconference tool or website, and select the virtual camera as video source. Use the same sound source as usual, there isn't an easy way to feed sound from OBS.

And done!

### Advanced mode

Set more than one window capture, each capturing (via cropping) only a single part of the game interface: the wheel, scoreboard, letter grid, status display. Compose them as you prefer, showing only some of them, or reorganize order. Group these in scenes, and jump between them to direct your own TV show.

# Video conference software: opinions and quirks

## Jitsi Electron App

It is open source, has all the necessary features, is free to use and has least quirks. Allows choosing from any webcam you have connected, and even changing it mid-conference. If you want to move from regular webcam to the streamed virtualcam, just disable your video for a while and launch OBS, which will be then able to use your camera.

The preferred choice.

## Google Hangouts and Google Meet, in browser

Will ignore your virtualcam device on Linux if it isn't named properly. Use names like 'Webcam V4L2' and you should be fine. Allows choosing from connected cameras, but doesn't make it easy to change what you use mid-call, so best just set up OBS beforehand, and use a scene that just feeds your webcam and nothing else. Can drop quality to 360p which is enough to recognize a face, but not play this game.

## Zoom Linux application

Does not allow switching cameras mid-call. You'll have to restart the application (just disconnecting may not be enough), or just setup OBS beforehand. Also picky about camera names.

## Facebook Messenger, in browser

Very annoying, avoid. Always tries to grab the first camera and shows an error if it's busy (when used by OBS), refusing to start or join the call. However, allows switching cameras mid-call, therefore the solution is to let it grab your actual webcam, then disable video, launch OBS + virtualcam and select the new camera again. Drops quality without warning or options to change behavior, to levels unusable for the game.

## macOS apps

Some signed applications may reject cameras from modules not signed by Apple, making the Virtualcam useless. Check the [compatibility list](https://github.com/johnboiles/obs-mac-virtualcam/wiki/Compatibility) from obs-mac-virtualcam.
