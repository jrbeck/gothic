This is a little sketch I made after stumbling across this Code Golf post:

http://codegolf.stackexchange.com/questions/33172/american-gothic-in-the-palette-of-mona-lisa-rearrange-the-pixels

I originally made this in Ruby as it seemed like a good chance to work on something that wasn't a Rails project. I didn't work to hard to optimize it, but it still seemed pretty slow for what it was doing. So I decided to rewrite, fairly verbatim, in C++ to see what kind of speed increase would come from a naive translation. I haven't done any benchmarking, but ... well there's no real comparison. The C++ version stabilizes on my machine in < 1s with pretty much real time graphics where the Ruby version takes, ahem, a long time with much slower graphical updating. The Ruby version can produce animations, which I never implemented in the C++ version.

The Ruby version requires ImageMagick for loading and saving images and uses Gosu for window/graphics abstraction.

The C++ version uses SDL2 (since that's all Brew was willing to give me) for the window management and OpenGL. I also used LodePNG to load up the image files.

I tried out a bunch of different algorithms/color strategies/etc... and threw most of them out in favor of a pretty naive method that gives pretty good results. A lot of the code is vestigial in that sense as I just didn't bother getting rid of all of it.

Resources:
- [Imagemagick](http://www.imagemagick.org/script/index.php)
- [Gosu](https://www.libgosu.org/)
- [LodePNG](http://lodev.org/lodepng/)
- [SDL](https://www.libsdl.org/)
