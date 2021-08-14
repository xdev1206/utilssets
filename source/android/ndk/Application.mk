#ndk-build.cmd NDK_PROJECT_PATH=. APP_BUILD_SCRIPT=Android.mk NDK_APPLICATION_MK=Application.mk
APP_ABI := arm64-v8a
APP_STL := c++_shared

#if APP_PLATFORM<22, compiling will throw this issue
#./obj/local/arm64-v8a/libtensorflowlite.so: undefined reference to `__register_atfork@LIBC'
#./obj/local/arm64-v8a/libtensorflowlite.so: undefined reference to `stderr@LIBC'
APP_PLATFORM := android-28
