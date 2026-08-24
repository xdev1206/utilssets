/*
 * copyright
 */

#ifndef UTIL_TRANSFORM_BY_CV_H_
#define UTIL_TRANSFORM_BY_CV_H_

void rgbResizeByCv(unsigned char* src, unsigned char* dst,
                   unsigned int srcW, unsigned int srcH,
                   unsigned int dstW, unsigned int dstH,
                   unsigned int srcStep, unsigned int dstStep,
                   int depth, int channels);

#endif // UTIL_TRANSFORM_BY_CV_H_
