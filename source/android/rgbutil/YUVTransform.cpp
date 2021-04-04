/*
 * copyright
 */

#include <YUVTransform.h>

int NV21ToBGR(unsigned char* srcYVU, unsigned char* dstBGR, int width, int height)
{
#ifdef YUV_TRANS_DEBUG
    std::cout << "nv21 to bgr start" << std::endl;
#endif
    unsigned char * srcVU = srcYVU + width * height;

    unsigned char Y, U, V;
    int B, G, R;

    for (int i = 0; i < height; i++) {
        for (int j = 0; j < width; j++) {
            Y = srcYVU[i * width + j];
            V = srcVU[(i / 2 * width / 2 + j / 2) * 2];
            U = srcVU[(i / 2 * width / 2 + j / 2) * 2 + 1];

            R = (1164 * (Y - 16) + 1596 * (V - 128)) / 1000;
            G = (1164 * (Y - 16) - 813 * (V - 128) - 392 * (U - 128)) / 1000;
            B = (1164 * (Y - 16) + 2017 * (U - 128)) / 1000;

            dstBGR[(i * width + j) * 3 + 0] = clamp(B, 0, 255);
            dstBGR[(i * width + j) * 3 + 1] = clamp(G, 0, 255);
            dstBGR[(i * width + j) * 3 + 2] = clamp(R, 0, 255);
        }
    }

#ifdef YUV_TRANS_DEBUG
    std::cout << "nv21 to bgr end" << std::endl;
#endif
    return 0;
}
