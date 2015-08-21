#include <iostream>

#include <SDL2/SDL.h>

#include "image_buffer.h"

#ifndef _sdl_app_h

#define SCREEN_WIDTH  (320)
#define SCREEN_HEIGHT (386)

class SdlApp {
public:
  SdlApp();
  ~SdlApp();

  int init(unsigned width, unsigned height);
  int quit();

  int drawFrame(ImageBuffer* imageBuffer);

private:
  SDL_Window* mSdlWindow;
  SDL_Renderer* mSdlRenderer;
  SDL_Texture* mSdlTexture;

  void destroyTexture();
};


#define _sdl_app_h
#endif
