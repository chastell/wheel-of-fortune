all: main.js

main.js: src/*.elm
	elm make --output $@ src/Main.elm
