# cv_ocr_native Repository Reference

This repository is a C++17 OCR inference library with CMake projects for the shared library and command-line demos. Core OCR processing, backend executors, and the public API live in `cpp/`; `demo/` contains image and dataset runners. Model and dictionary files are under `assets/`, with additional dictionaries under `dicts/`; TensorFlow Lite headers and Android libraries are under `tflite/`.

Configure and build the library with `cmake -S cpp -B build/cpp && cmake --build build/cpp -j`. Configure demo executables separately with `cmake -S demo -B build/demo && cmake --build build/demo -j`. Both configurations default to MNN; choose `-DUSE_PADDLE_LITE=ON -DUSE_MNN=OFF` for Paddle Lite. CMake expects OpenCV, JSON headers, and selected inference backend dependencies in the paths named in the project CMake files, principally beneath `thirdparty/`.

There is no standalone unit-test framework or test target in the checked-in CMake files. Validation is through the `sample`, benchmark, and demo executables using a valid OCR configuration, model files, and input images or datasets. Dataset utilities expect their input and output paths as positional arguments, despite displaying option-like usage labels.

Recent commit history includes conventional prefixes such as `fix:` alongside older terse subjects. Prefer a short, descriptive `<type>: <summary>` subject. Pull requests should explain the OCR behavior or backend affected and report the build or image/dataset checks performed.
