all: main.js

main.js: src/*.elm index.html
	elm make --output $@ src/Main.elm
