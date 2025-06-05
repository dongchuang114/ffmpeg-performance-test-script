# ffmpeg-performance-test-script

FFmpeg multi-memory-channel benchmark suite.

## Overview

This project contains two types of tools:

1. **Single-config benchmark scripts**: Run FFmpeg performance tests on the current system and generate per-config HTML reports.
2. **Multi-config comparison script** (`compare_channels_report.py`): Read results from multiple benchmark runs and generate a cross-channel comparison report with interactive SVG charts.

**Test background**: AMD EPYC 9T24 (384 threads) server with memory channels disabled via BIOS (DIMMs remain physically installed). Memory total capacity is used to infer the number of active channels (2 / 4 / 8 / 12 / 24), measuring the impact of memory bandwidth on FFmpeg encode/decode performance.

## Files

| File | Description |
|------|-------------|
| `ffmpeg-complete-benchmark.sh` | Main benchmark script — runs full FFmpeg test suite, outputs CSV results |
| `generate_html_report_universal.sh` | Single-config HTML report generator (Shell) |
| `compare_channels_report.py` | **Multi-config comparison report generator (Python)** |

### Result directory structure

```
ffmpeg_benchmark_<timestamp>_<config>/
├── benchmark_results.csv      # Performance data (encode speed, realtime multiplier)
├── speed_results.csv          # Speed summary
├── test_config.txt            # System config at test time (includes memory size in GB)
└── performance_report.html    # Single-config HTML report
```

## Quick Start

### Run a single benchmark

```bash
./ffmpeg-complete-benchmark.sh input.mp4 ./output_dir
cd ./output_dir
../generate_html_report_universal.sh
python3 -m http.server 8080
# Open http://localhost:8080/performance_report.html
```

### Generate a multi-config comparison report

Requirements: multiple `ffmpeg_benchmark_*` result directories already exist in the current directory.

```bash
python3 compare_channels_report.py
```

The script automatically:
- Scans all `ffmpeg_benchmark_*` subdirectories
- Infers the memory channel count from memory size recorded in `test_config.txt`
- Sorts configs from highest to lowest channel count (highest = baseline)
- Generates `multi_channel_report.html` with comparative SVG charts and tables

Serve and view the report:

```bash
python3 -m http.server 8080
# Open http://localhost:8080/multi_channel_report.html
```

Remote viewing via SSH tunnel:

```bash
ssh -N -L 8080:SERVER_IP:8080 user@SERVER_IP
# Open http://localhost:8080/multi_channel_report.html in local browser
```

## compare_channels_report.py Features

- **Auto channel detection**: Infers 2/4/8/12/24 channel from memory size in `test_config.txt`
- **Pure-Python SVG charts** — no external libraries or CDN required:
  - libx264 / libx265 / VP9 encode speed grouped bar charts (by resolution and bitrate)
  - Thread scaling line chart (1 to 64 threads)
  - Decode speed comparison (H.264 / H.265 / VP9)
  - Video filter processing speed comparison
- **Comparison tables**: Uses the highest-channel config as baseline, shows percentage difference for each config
- **Dark theme**: GitHub-style dark UI, suitable for technical reports
- **Navigation bar**: Jump to encode / decode / filter / thread sections

## Test Coverage

| Category | Tests |
|----------|-------|
| Encode | libx264 medium/slow, libx265 medium, libvpx-vp9 good |
| Resolution | 854x480, 1280x720, 1920x1080 |
| Bitrate | 2000k, 5000k |
| Decode | libx264, libx265, libvpx-vp9 |
| Filter | scale 720p/1080p, horizontal flip, vertical flip, boxblur |
| Thread scaling | 1, 2, 4, 8, 16, 32, 64 |

## Test Environment

- CPU: AMD EPYC 9T24 96-Core Processor (384 threads)
- Memory channels: 2 / 4 / 8 / 12 / 24 (controlled via BIOS, inferred from total memory size)
- FFmpeg: 4.4.2
- OS: Ubuntu 22.04 / Linux 6.8

## Dependencies

- FFmpeg 4.4+
- Python 3.8+ (standard library only: `os`, `csv` — no pip install required)
- `bc` (for Shell benchmark scripts)

## License

MIT License
