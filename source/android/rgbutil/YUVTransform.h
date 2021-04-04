/*
 * copyright
 */

#ifndef UTIL_YUV_TRANSFORM_H_
#define UTIL_YUV_TRANSFORM_H_

static inline int clamp(int x, int min, int max)
{
    return x < min ? min : (x > max ? max : x);
}

/*
 * transform format from YVU to BGR
 */
int NV21ToBGR(unsigned char* srcYVU, unsigned char* dstBGR, int w, int h);

#endif // UTIL_YUV_TRANSFORM_H_
