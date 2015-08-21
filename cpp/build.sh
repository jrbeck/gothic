#!/bin/sh

g++ gothic.cpp sdl_app.cpp image_buffer.cpp pixel.cpp pixel_swapper.cpp pseudo_random.cpp lib/lodepng.cpp -lSDL2 -ansi -pedantic -Wall -Wextra -O3 -o gothic
