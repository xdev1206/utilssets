# UFS Versions and Interface Rates

## Summary

UFS version numbers describe more than interface speed. Several revisions keep the same physical link rate while adding features, power-management behavior, or host/device capabilities. The table below records the commonly used maximum theoretical link rates.

## Version and Rate

| UFS version | Typical M-PHY high-speed gear | Maximum per lane | Maximum for a 2-lane device | Approximate raw byte rate per lane |
| --- | --- | ---: | ---: | ---: |
| UFS 1.0/1.1 | HS-Gear2 | 2.9 Gbps | 5.8 Gbps | 362.5 MB/s |
| UFS 2.0/2.1/2.2 | HS-Gear3 | 5.8 Gbps | 11.6 Gbps | 725 MB/s |
| UFS 3.0/3.1 | HS-Gear4 | 11.6 Gbps | 23.2 Gbps | 1.45 GB/s |
| UFS 4.0/4.1 | HS-Gear5 | 23.2 Gbps | 46.4 Gbps | 2.9 GB/s |

The byte-rate column is calculated as `Gbps / 8` using decimal units. Protocol encoding, transport overhead, flash media behavior, controller limits, thermal throttling, and workload characteristics reduce usable throughput.

## Important Distinctions

### Interface rate versus storage read/write speed

The link-rate table describes the maximum physical interface bandwidth. It does not guarantee sequential read or write performance for a particular UFS package.

For example, Samsung reports for one UFS 4.0 product a sequential read speed of up to 4,200 MB/s and sequential write speed of up to 2,800 MB/s. These are product-level benchmark specifications, not direct conversions of the 46.4 Gbps two-lane link rate.

### Same rate does not mean same feature set

UFS 2.1 and UFS 2.2 remain in the UFS 2.x physical-speed group, while UFS 2.2 adds features such as WriteBooster. Similarly, UFS 3.1 adds features over UFS 3.0 without changing the commonly cited 11.6 Gbps-per-lane maximum.

### Full-duplex and lane terminology

UFS uses a full-duplex serial interface. “Per lane” is the safest comparison unit. “Per device” in vendor material commonly refers to the aggregate of two lanes; confirm the implementation and host configuration before comparing products.

## Practical Interpretation

When comparing phones or embedded devices:

1. Use the UFS version to identify the feature and capability generation.
2. Use the theoretical link rate only as an upper-bound interface comparison.
3. Check the exact storage component's sequential read/write specifications for expected performance.
4. Check the SoC, host controller, lane configuration, capacity, thermal state, and workload before treating two devices as directly comparable.

## Sources

- KIOXIA, [UFS 4.0/4.1 – Designed for Next Generation Mobile Storage](https://apac.kioxia.com/en-apac/business/memory/mlc-nand/ufs4.html), accessed 2026-09-21. It states 23.2 Gbps per lane and 46.4 Gbps per device for UFS 4.0/4.1 and describes the relationship to UFS 3.1.
- Samsung Semiconductor, [Samsung Develops First UFS 4.0 Storage Solution Compliant with New Industry Standard](https://semiconductor.samsung.com/news-events/tech-blog/samsung-develops-first-ufs-4-0-storage-solution-compliant-with-new-industry-standard/), accessed 2026-09-21. It states 23.2 Gbps per lane, twice the previous UFS 3.1 link rate, and gives product-level read/write figures.
- JEDEC, [Universal Flash Storage (UFS) Standard v2.0](https://www.jedec.org/standards-documents/docs/jesd220b), accessed 2026-09-21. The standard revision reference for UFS 2.0.
- Wikipedia, [Universal Flash Storage](https://en.wikipedia.org/wiki/Universal_Flash_Storage), accessed 2026-09-21. Secondary historical reference for the UFS version timeline and cited link-rate generations; use JEDEC/MIPI and vendor documentation as the authoritative basis.

## Uncertainty and Scope

The table is a standards-level comparison, not a complete list of every optional gear, host mode, or vendor-specific implementation. UFS 1.0/1.1 and some early device capabilities may vary by supported M-PHY gear. Verify the exact device datasheet when selecting hardware or interpreting benchmark results.
