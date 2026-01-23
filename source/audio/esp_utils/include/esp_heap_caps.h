#ifndef __ESP_HEAP_CAPS_H_
#define __ESP_HEAP_CAPS_H_

#include <stdlib.h>

/**
 * @brief Flags to indicate the capabilities of the various memory systems
 */
#define MALLOC_CAP_EXEC             (1<<0)  ///< Memory must be able to run executable code
#define MALLOC_CAP_32BIT            (1<<1)  ///< Memory must allow for aligned 32-bit data accesses
#define MALLOC_CAP_8BIT             (1<<2)  ///< Memory must allow for 8/16/...-bit data accesses
#define MALLOC_CAP_DMA              (1<<3)  ///< Memory must be able to accessed by DMA
#define MALLOC_CAP_PID2             (1<<4)  ///< Memory must be mapped to PID2 memory space (PIDs are not currently used)
#define MALLOC_CAP_PID3             (1<<5)  ///< Memory must be mapped to PID3 memory space (PIDs are not currently used)
#define MALLOC_CAP_PID4             (1<<6)  ///< Memory must be mapped to PID4 memory space (PIDs are not currently used)
#define MALLOC_CAP_PID5             (1<<7)  ///< Memory must be mapped to PID5 memory space (PIDs are not currently used)
#define MALLOC_CAP_PID6             (1<<8)  ///< Memory must be mapped to PID6 memory space (PIDs are not currently used)
#define MALLOC_CAP_PID7             (1<<9)  ///< Memory must be mapped to PID7 memory space (PIDs are not currently used)
#define MALLOC_CAP_SPIRAM           (1<<10) ///< Memory must be in SPI RAM
#define MALLOC_CAP_INTERNAL         (1<<11) ///< Memory must be internal; specifically it should not disappear when flash/spiram cache is switched off
#define MALLOC_CAP_DEFAULT          (1<<12) ///< Memory can be returned in a non-capability-specific memory allocation (e.g. malloc(), calloc()) call
#define MALLOC_CAP_IRAM_8BIT        (1<<13) ///< Memory must be in IRAM and allow unaligned access
#define MALLOC_CAP_RETENTION        (1<<14) ///< Memory must be able to accessed by retention DMA
#define MALLOC_CAP_RTCRAM           (1<<15) ///< Memory must be in RTC fast memory
#define MALLOC_CAP_TCM              (1<<16) ///< Memory must be in TCM memory
#define MALLOC_CAP_DMA_DESC_AHB     (1<<17) ///< Memory must be capable of containing AHB DMA descriptors
#define MALLOC_CAP_DMA_DESC_AXI     (1<<18) ///< Memory must be capable of containing AXI DMA descriptors
#define MALLOC_CAP_CACHE_ALIGNED    (1<<19) ///< Memory must be aligned to the cache line size of any intermediate caches
#define MALLOC_CAP_SIMD             (1<<20) ///< Memory must be capable of being used for SIMD instructions (i.e. allow for SIMD-specific-bit data accesses)

#define MALLOC_CAP_INVALID          (1<<31) ///< Memory can't be used / list end marker


#define heap_caps_malloc(size, caps) malloc(size)
#define heap_caps_free(ptr)          free(ptr)

static inline void *heap_caps_aligned_alloc(size_t alignment,
                                            size_t size,
                                            uint32_t caps)
{
    (void)caps;  // 忽略

    void *ptr = NULL;
    if (posix_memalign(&ptr, alignment, size) != 0) {
        return NULL;
    }
    return ptr;
}

#endif // __ESP_HEAP_CAPS_H_
