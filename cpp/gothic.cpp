#include <iostream>
#include <vector>
#include <string>

#include <cstdio>

#include "lib/lodepng.h"

#include "pixel.h"
#include "pixel_swapper.h"
#include "image_buffer.h"
#include "pseudo_random.h"
#include "sdl_app.h"

void showIt(ImageBuffer* targetBuffer, PixelSwapper* pixelSwapper) {
  SdlApp sdlApp;
  if (sdlApp.init(targetBuffer->getWidth(), targetBuffer->getHeight()) != 0) {
    printf("ERROR: could not initialize SdlApp\n");
    return;
  }

  int ditherDistance = 0;

  SDL_Event e;
  bool quit = false;
  while (!quit) {
    pixelSwapper->performUnit(100000, ditherDistance);
    sdlApp.drawFrame(pixelSwapper->getOutput());

    while (SDL_PollEvent(&e)) {
      if (e.type == SDL_QUIT) {
        quit = true;
      }
      if (e.type == SDL_KEYDOWN) {
        switch(e.key.keysym.sym) {
          case SDLK_ESCAPE:
            quit = true;
            break;
          case SDLK_q:
            ditherDistance++;
            printf("dither: %d\n", ditherDistance);
            break;
          case SDLK_a:
            if (ditherDistance > 0) {
              ditherDistance--;
            }
            printf("dither: %d\n", ditherDistance);
            break;
          default:
            break;
        }

      }
      if (e.type == SDL_MOUSEBUTTONDOWN) {
      }
    }
  }

  sdlApp.quit();
}

int main(int argc, char** argv) {
  int result = 0;

  std::string palettePath = "../input/";
  std::string targetPath = "../input/";

  // std::string palettePath = "../input/800_600/";
  // std::string targetPath = "../input/800_600/";

  if (argc >= 3) {
    palettePath.append(argv[1]);
    targetPath.append(argv[2]);
  }
  else {
    palettePath.append("b_mona.png");
    targetPath.append("a_mona.png");
  }

  ImageBuffer* paletteBuffer = new ImageBuffer();
  result = paletteBuffer->loadPng(palettePath.c_str());
  if (result != 0) {
    printf("could not load: %s\n", palettePath.c_str());
    exit(1);
  }

  ImageBuffer* targetBuffer = new ImageBuffer();
  result = targetBuffer->loadPng(targetPath.c_str());
  if (result != 0) {
    printf("could not load: %s\n", targetPath.c_str());
    delete paletteBuffer;
    exit(1);
  }

  PixelSwapper* pixelSwapper = new PixelSwapper(paletteBuffer, targetBuffer);

  // pixelSwapper->perform(1000, 0);
  showIt(targetBuffer, pixelSwapper);

  pixelSwapper->printResults();
  pixelSwapper->saveOutput();

  delete paletteBuffer;
  delete targetBuffer;
  delete pixelSwapper;
}
