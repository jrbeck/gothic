#include "pixel_swapper.h"

PixelSwapper::PixelSwapper(ImageBuffer* colorSource, ImageBuffer* imageSource) :
  mSrcImage(nullptr),
  mOutput(nullptr),
  mTotalFrames(0),
  mTotalSwaps(0)
{
  mSrcImage = imageSource;
  mOutput = new ImageBuffer();
  mOutput->copy(*colorSource);
  mWidth = imageSource->getWidth();
  mHeight = imageSource->getHeight();
  mOutput->softResize(mWidth, mHeight);
}

PixelSwapper::~PixelSwapper() {
  if (mOutput != nullptr) {
    delete mOutput;
    mOutput = nullptr;
  }
}

void PixelSwapper::perform(int workUnits, int distance) {
  printf("Beginning processing...\n");

  unsigned start_time = SDL_GetTicks();
  unsigned swaps, tempSwaps = 0;
  int tenPercent = workUnits / 10;

  for (int i = 0; i < workUnits; i++) {
    swaps = performUnit(100000, distance);
    tempSwaps += swaps;

    if (((i + 1) % tenPercent) == 0) {
      printf("%.2f: %d\n", (double)i / (double)workUnits, tempSwaps);
      tempSwaps = 0;
    }
  }

  double totalTime = (double)(SDL_GetTicks() - start_time) / 1000.0;
  printf("Processing time: %.2f\n", totalTime);
  printf("FPS: %.2f\n", (double)mTotalFrames / totalTime);
}

unsigned PixelSwapper::performUnit(int iterations, int distance) {
  unsigned swaps = 0;
  for (int i = 0; i < iterations; i++) {
    swaps += checkSwapDither(
      mPrng.nextInt(0, mWidth),
      mPrng.nextInt(0, mHeight),
      mPrng.nextInt(0, mWidth),
      mPrng.nextInt(0, mHeight),
      distance);
    // swaps += checkswap_exact(x1, y1, x2, y2)
    // swaps += checkswap_single(x1, y1, x2, y2)
  }
  mTotalFrames += iterations;
  mTotalSwaps += swaps;
  return swaps;
}


void PixelSwapper::printResults() {
  printf("Swaps: %d\n", mTotalSwaps);
  printf("Frames: %d\n", mTotalFrames);
}

void PixelSwapper::saveOutput() {
  mOutput->savePng("output_001.png");
}

ImageBuffer* PixelSwapper::getOutput() {
  return mOutput;
}

unsigned PixelSwapper::checkSwapDither(int x1, int y1, int x2, int y2, int distance) {
  int cur_delta;
  int new_delta;
  int u1, v1, u2, v2;
  float mult;
  float max_mult = 1 + (2 * distance);

  Pixel source_accum_1;
  Pixel source_accum_2;
  Pixel output_accum_1;
  Pixel output_accum_2;
  Pixel swap_accum_1;
  Pixel swap_accum_2;
  Pixel pixel;

  for (int j = -distance; j <= distance; j++) {
    v1 = (y1 + j);
    v2 = (y2 + j);
    if (v1 < 0 || v1 >= (int)mHeight || v2 < 0 || v2 >= (int)mHeight) continue;

    for (int i = -distance; i <= distance; i++) {
      if (i == 0 && j == 0) continue;
      u1 = (x1 + i);
      u2 = (x2 + i);
      if (u1 < 0 || u1 >= (int)mWidth || u2 < 0 || u2 >= (int)mWidth) continue;

      mult = max_mult - (abs(i) + abs(j));

      pixel.copy(*mOutput->getPixel(u1, v1));
      pixel.scale(mult);
      output_accum_1.add(pixel);

      pixel.copy(*mSrcImage->getPixel(u1, v1));
      pixel.scale(mult);
      source_accum_1.add(pixel);

      pixel.copy(*mOutput->getPixel(u2, v2));
      pixel.scale(mult);
      output_accum_2.add(pixel);

      pixel.copy(*mSrcImage->getPixel(u2, v2));
      pixel.scale(mult);
      source_accum_2.add(pixel);
    }
  }

  swap_accum_1.copy(output_accum_1);
  swap_accum_2.copy(output_accum_2);

  pixel.copy(*mOutput->getPixel(x1, y1));
  pixel.scale(max_mult);
  output_accum_1.add(pixel);
  swap_accum_2.add(pixel);

  pixel.copy(*mOutput->getPixel(x2, y2));
  pixel.scale(max_mult);
  output_accum_2.add(pixel);
  swap_accum_1.add(pixel);

  // this is for no dithering...
  // you can probably remove this when you stop being lazy
  // and write a single pixel checker
  if (distance == 0) {
    source_accum_1.copy(*mSrcImage->getPixel(x1, y1));
    source_accum_2.copy(*mSrcImage->getPixel(x2, y2));
  }

  cur_delta = deltaRgb(output_accum_1, source_accum_1) + deltaRgb(output_accum_2, source_accum_2);
  new_delta = deltaRgb(swap_accum_1, source_accum_1) + deltaRgb(swap_accum_2, source_accum_2);

  if (new_delta < cur_delta) {
    pixel.copy(*mOutput->getPixel(x1, y1));
    mOutput->setPixel(x1, y1, *mOutput->getPixel(x2, y2));
    mOutput->setPixel(x2, y2, pixel);
    return 1;
  }

  return 0;
}

unsigned PixelSwapper::deltaRgb(const Pixel& a, const Pixel& b) const {
  int deltaR = (a.mR - b.mR);
  int deltaG = (a.mG - b.mG);
  int deltaB = (a.mB - b.mB);
  return (deltaR * deltaR) + (deltaG * deltaG) + (deltaB * deltaB);
}

unsigned PixelSwapper::deltaLab(const Pixel& a, const Pixel& b) const {
  float aLab[3];
  float bLab[3];

  a.toLab(aLab);
  b.toLab(bLab);

  float deltaL = aLab[0] - bLab[0];
  float deltaA = aLab[1] - bLab[1];
  float deltaB = aLab[2] - bLab[2];

  return (deltaL * deltaL) + (deltaA * deltaA) + (deltaB * deltaB);
}
