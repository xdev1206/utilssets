double compareHistYofYUV()
{
    int dims = 1;  // 创建一维直方图
    int sizes[] = {256};  // 共有256个取值范围
    int type = CV_HIST_ARRAY; // 表示使用密集多维矩阵结构
    int uniform = 1;
    float range[] = {0, 255}; // 取值范围为0-255
    float *ranges[] = {range};

    CvHistogram *hist1 = cvCreateHist(dims, sizes, type, ranges, uniform); // 创建直方图
    CvHistogram *hist2 = cvCreateHist(dims, sizes, type, ranges, uniform);

    IplImage *iplImage = cvCreateImageHeader(cvSize(w, h), IPL_DEPTH_8U,, 1);
    cvSetData(iplImage, data, w);

    cvCalcHist(&iplImage, hist1, 0, NULL); // 统计直方图
    cvNormalizeHist(hist1, 1.0); // 归一化

    cvCalcHist(&iplImage, hist2, 0, NULL);
    cvNormalizeHist(hist2, 1.0);

    double sim = cvCompareHist(hist1, hist2, CV_COMP_CORREL);

    cvReleaseHist(&hist1);
    cvReleaseHist(&hist2);

    return sim;
}
