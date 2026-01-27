#include "kaldi-native-fbank/csrc/rfft.h"

#include <algorithm>
#include <vector>
#include <cstdlib>
#include <cstdio>

#include "kaldi-native-fbank/csrc/log.h"
#include "dl_rfft.h"

namespace knf {

class Rfft::RfftImpl {
 public:
  RfftImpl(int32_t n, bool inverse)
      : n_(n), inverse_(inverse) {
    if (n_ <= 0 || (n_ & 1) != 0 || (n_ & (n_ - 1)) != 0) {
      fprintf(stderr,
              "Rfft: n must be positive, even and power of two. Given: %d\n",
              n_);
      std::abort();
    }

    fft_ = dl_rfft_f32_init(n_, MALLOC_CAP_INTERNAL);
    if (!fft_) {
      fprintf(stderr, "dl_rfft_f32_init failed\n");
      std::abort();
    }
  }

  ~RfftImpl() {
    if (fft_) {
      dl_rfft_f32_deinit(fft_);
      fft_ = nullptr;
    }
  }

  void Compute(float *in_out) {
    if (!inverse_) {
      Forward(in_out);
    } else {
      Reverse(in_out);
    }
  }

  void Compute(double *in_out) {
    std::vector<float> f(in_out, in_out + n_);
    Compute(f.data());
    std::copy(f.begin(), f.end(), in_out);
  }

 private:
  // =========================================================
  // Forward RFFT
  // in_out: real input  -> Kaldi packed RFFT (in-place)
  // =========================================================
  void Forward(float *in_out) {
    // In-place RFFT, output format == Kaldi format
    dl_rfft_f32_run(fft_, in_out);
  }

  // =========================================================
  // Inverse RFFT
  // in_out: Kaldi packed RFFT -> real signal
  // =========================================================
  void Reverse(float *in_out) {
    dl_irfft_f32_run(fft_, in_out);

    // ⚠️ ESP-DSP irfft 不做 1/N 归一化
    for (int32_t i = 0; i < n_; ++i) {
      in_out[i] /= n_;
    }
  }

 private:
  int32_t n_;
  bool inverse_ = false;
  dl_fft_f32_t *fft_ = nullptr;
};

// ===== public wrapper =====

Rfft::Rfft(int32_t n, bool inverse /*=false*/)
    : impl_(std::make_unique<RfftImpl>(n, inverse)) {}

Rfft::~Rfft() = default;

void Rfft::Compute(float *in_out) {
  impl_->Compute(in_out);
}

void Rfft::Compute(double *in_out) {
  impl_->Compute(in_out);
}

}  // namespace knf
