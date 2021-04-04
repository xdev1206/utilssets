LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_MODULE := yuvtobgr
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_MODULE_TAGS := optional eng

LOCAL_SRC_FILES := \
    main.cpp \
    TransformByCv.cpp \
    YUVTransform.cpp


LOCAL_C_INCLUDES_64 := \
        $(TOPDIR)external/opencv/cv/include \
        $(TOPDIR)external/opencv/cxcore/include \
        $(TOPDIR)external/opencv/otherlibs/highgui \

LOCAL_CPPFLAGS := -std=c++11 -fexceptions -fPIC -Wno-non-virtual-dtor -Wno-pessimizing-move -Wno-sign-compare

LOCAL_SHARED_LIBRARIES := libcutils
LOCAL_STATIC_LIBRARIES := libcvhighgui libcv libcxcore
#LOCAL_MULTILIB := both

include $(BUILD_EXECUTABLE)
