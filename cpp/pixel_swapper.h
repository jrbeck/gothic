#pragma once

#include "image_buffer.h"
#include "pseudo_random.h"

class PixelSwapper {
public:
  PixelSwapper(ImageBuffer* colorSource, ImageBuffer* imageSource);
  ~PixelSwapper();

  void perform(int workUnits, int distance);
  unsigned performUnit(int iterations, int distance);
  void printResults();
  void saveOutput();

  ImageBuffer* getOutput();

private:
  ImageBuffer* mSrcImage;
  ImageBuffer* mOutput;
  PseudoRandom mPrng;

  unsigned mTotalFrames;
  unsigned mTotalSwaps;
  unsigned mWidth, mHeight;

  unsigned checkSwapDither(int x1, int y1, int x2, int y2, int distance);
  unsigned deltaRgb(const Pixel& a, const Pixel& b) const;
  unsigned deltaLab(const Pixel& a, const Pixel& b) const;
};
