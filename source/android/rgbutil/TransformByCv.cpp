/*
 * copyright
 */

#include <TransformByCv.h>

#include <cv.h>
#include <highgui.h>

/*
 * cxcore/include/cxtypes.h
 * #define IPL_DEPTH_8U     8
 *
 * cxcore/include/cxcore.h
 * CVAPI(IplImage*)  cvCreateImageHeader(CvSize size, int depth, int channels);
 *
 * cxcore/include/cxcore.h
 * cxcore/src/cxarray.cpp
 * CVAPI(void) cvSetData(CvArr* arr, void* data, int step);
 *
 * cv/include/cv.h
 * cv/src/cvimgwarp.cpp
 * CV_IMPL void cvResize(const CvArr* srcarr, CvArr* dstarr, int method)
 * cxcore/src/cxarray.cpp:3435
 * cvReleaseImageHeader(IplImage** image)
 */
void rgbResizeByCv(unsigned char* src, unsigned char* dst,
                   unsigned int srcW, unsigned int srcH,
                   unsigned int dstW, unsigned int dstH,
                   unsigned int srcStep, unsigned int dstStep,
                   int depth, int channels)
{
    IplImage *iplImageSrc = cvCreateImageHeader(cvSize(srcW, srcH), depth, channels);
    IplImage *iplImageDes = cvCreateImageHeader(cvSize(dstW, dstH), depth, channels);
    cvSetData(iplImageSrc, src, srcStep);
    cvSetData(iplImageDes, dst, dstStep);

    // doResize
    cvResize(iplImageSrc, iplImageDes);

    cvReleaseImageHeader(&iplImageSrc);
    cvReleaseImageHeader(&iplImageDes);
}
