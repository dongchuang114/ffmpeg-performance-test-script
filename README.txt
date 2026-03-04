ffmpeg version 6.1.1-3ubuntu5

根据您修复后的FFmpeg性能测试脚本，我为您编写了详细的README文档：

FFmpeg性能基准测试脚本

一个全面的FFmpeg性能测试工具，用于评估视频编码、解码、滤镜处理和多线程性能。

功能特点

• ✅ 全面的编码测试：支持H.264、H.265、VP9编码器

• ✅ 多分辨率测试：支持854x480、1280x720、1920x1080等分辨率

• ✅ 多比特率测试：支持2000k、5000k等不同比特率

• ✅ 解码性能测试：测试主流格式的解码性能

• ✅ 滤镜性能测试：缩放、翻转、模糊等滤镜处理测试

• ✅ 多线程测试：1-64线程性能对比

• ✅ 质量测试：PSNR、SSIM质量指标分析

• ✅ 系统信息收集：自动收集CPU、内存、FFmpeg版本等信息

• ✅ 详细报告生成：CSV、HTML、文本格式报告

系统要求

• 操作系统：Linux（Ubuntu/CentOS等）

• FFmpeg版本：4.4或更高版本

• 内存：至少2GB可用内存

• 存储空间：至少1GB可用空间

• 权限：需要执行权限和FFmpeg安装权限

快速开始

1. 安装依赖

# Ubuntu/Debian
sudo apt update
sudo apt install ffmpeg bc curl -y

# CentOS/RHEL
sudo yum install epel-release
sudo yum install ffmpeg bc curl -y


2. 获取脚本

# 克隆仓库
git clone https://github.com/dongchuang114/ffmpeg-performance-test-script.git
cd ffmpeg-performance-test-script

# 或直接下载脚本
wget https://raw.githubusercontent.com/dongchuang114/ffmpeg-performance-test-script/master/ffmpeg-complete-benchmark.sh
chmod +x ffmpeg-complete-benchmark.sh


3. 运行完整测试

# 基本测试（使用默认参数）
./ffmpeg-complete-benchmark.sh

# 指定输入视频文件
./ffmpeg-complete-benchmark.sh /path/to/input_video.mp4

# 指定输入视频和输出目录
./ffmpeg-complete-benchmark.sh /path/to/input_video.mp4 ./test_results


详细使用说明

配置参数

在运行前，您可以编辑脚本开头的配置参数：
# 主要配置参数（脚本第20-40行）
TEST_DURATION=10           # 每个测试的时长（秒）
RESOLUTIONS="854x480 1280x720 1920x1080"  # 测试分辨率
BITRATES="2000k 5000k"     # 测试比特率
TEST_ITERATIONS=2          # 每个测试的迭代次数
TIMEOUT_DURATION=300       # 单个测试超时时间（秒）
ENABLE_QUALITY_TESTS=true  # 是否启用质量测试
ENABLE_HARDWARE_TESTS=false # 是否启用硬件加速测试


测试项目说明

脚本会自动运行以下测试：

1. 编码性能测试：
   • H.264编码（medium/slow预设）

   • H.265编码（medium预设）

   • VP9编码（good质量预设）

2. 解码性能测试：
   • H.264解码

   • H.265解码

   • VP9解码

3. 滤镜性能测试：
   • 缩放滤镜（720p、1080p）

   • 水平翻转

   • 垂直翻转

   • 盒式模糊

4. 多线程测试：
   • 测试1、2、4、8、16、32、64线程性能

输出文件

测试完成后，会在输出目录生成以下文件：

输出目录/
├── benchmark_results.csv      # 主要性能数据
├── comparison_metrics.csv     # 系统对比指标
├── system_info.txt           # 详细系统信息
├── execution_summary.txt     # 执行摘要
├── benchmark_*.log           # 完整日志文件
├── logs/                     # 详细测试日志
│   ├── encode_*.log
│   ├── decode_*.log
│   └── filter_*.log
└── videos/                   # 质量测试视频（如果启用）
    └── quality_*.mp4


结果解读

性能指标说明

指标 说明 理想值

平均时间(秒) 完成测试的平均时间 越小越好

编码速度(x) FFmpeg报告的编码速度 越大越好

实时倍数(x) 相对于实时播放的速度 >1表示快于实时

测试耗时(秒) 包括准备和清理的总时间 -
性能等级评估
实时倍数 性能等级 说明

5x 🟢 优秀 性能卓越

2-5x 🟡 良好 性能良好

1-2x 🟠 一般 基本满足需求

<1x 🔴 较差 低于实时速度

示例结果分析

测试名称,平均时间(秒),编码速度(x),实时倍数(x),测试耗时(秒)
encode_libx264_medium_854x480_2000k,1.007,11.45x,9.93x,2.214894028


• 实时倍数9.93x：编码速度是实时播放的9.93倍

• 编码速度11.45x：FFmpeg内部报告的编码速度

• 平均时间1.007秒：处理10秒视频实际用时1.007秒

高级用法

自定义测试配置

# 只测试H.264编码
RESOLUTIONS="1920x1080" BITRATES="5000k" ./ffmpeg-complete-benchmark.sh

# 延长测试时间以获得更准确结果
TEST_DURATION=30 TEST_ITERATIONS=3 ./ffmpeg-complete-benchmark.sh

# 测试4K分辨率
RESOLUTIONS="3840x2160" ./ffmpeg-complete-benchmark.sh

# 禁用质量测试以加快速度
ENABLE_QUALITY_TESTS=false ./ffmpeg-complete-benchmark.sh


跨系统性能对比

1. 在不同系统上运行相同测试：
   # 系统A
   ./ffmpeg-complete-benchmark.sh input.mp4 ./results_system_a
   
   # 系统B
   ./ffmpeg-complete-benchmark.sh input.mp4 ./results_system_b
   

2. 对比结果：
   # 对比主要性能指标
   diff ./results_system_a/benchmark_results.csv ./results_system_b/benchmark_results.csv
   
   # 查看系统配置差异
   diff ./results_system_a/comparison_metrics.csv ./results_system_b/comparison_metrics.csv
   

批量测试脚本

创建批量测试脚本batch_test.sh：
#!/bin/bash
# 批量测试不同配置

CONFIGS=(
    "TEST_DURATION=10 RESOLUTIONS='854x480' BITRATES='2000k'"
    "TEST_DURATION=10 RESOLUTIONS='1280x720' BITRATES='5000k'"
    "TEST_DURATION=30 RESOLUTIONS='1920x1080' BITRATES='2000k 5000k'"
)

for i in "${!CONFIGS[@]}"; do
    echo "运行测试配置 $((i+1)): ${CONFIGS[$i]}"
    OUTPUT_DIR="./batch_test_$((i+1))"
    eval "${CONFIGS[$i]}" ./ffmpeg-complete-benchmark.sh input.mp4 "$OUTPUT_DIR"
done


故障排除

常见问题

1. FFmpeg未安装：
   # 检查FFmpeg版本
   ffmpeg -version
   
   # 如果未安装，使用包管理器安装
   sudo apt install ffmpeg  # Ubuntu/Debian
   sudo yum install ffmpeg  # CentOS/RHEL
   

2. 权限不足：
   # 添加执行权限
   chmod +x ffmpeg-complete-benchmark.sh
   
   # 确保有写入权限
   chmod 755 .
   

3. 输入视频文件不存在：
   # 使用示例视频
   wget http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4
   ./ffmpeg-complete-benchmark.sh BigBuckBunny.mp4
   

4. 内存不足：
   # 减少测试分辨率
   RESOLUTIONS="854x480" ./ffmpeg-complete-benchmark.sh
   
   # 减少测试时长
   TEST_DURATION=5 ./ffmpeg-complete-benchmark.sh
   

调试模式

# 启用详细日志
DEBUG=true ./ffmpeg-complete-benchmark.sh

# 查看实时进度
tail -f ./test_results/benchmark_*.log


性能优化建议

基于测试结果的优化

1. 编码器选择：
   • 实时编码：选择H.264 medium预设（性能最佳）

   • 高质量编码：选择H.265 slow预设（压缩率最高）

   • Web使用：选择VP9（专利免费）

2. 线程数优化：
   • 根据测试结果选择最佳线程数（通常是8-16线程）

   • 设置FFmpeg线程数：-threads 12

3. 分辨率选择：
   • 1080p：平衡质量和性能

   • 720p：适合流媒体和移动设备

   • 480p：最低带宽消耗

系统级优化

# 设置CPU性能模式
sudo cpupower frequency-set -g performance

# 提高进程优先级
nice -n -10 ./ffmpeg-complete-benchmark.sh

# 使用内存磁盘加速
mkdir /tmp/ffmpeg_test
TMPDIR=/tmp/ffmpeg_test ./ffmpeg-complete-benchmark.sh


更新日志

版本 1.1（当前版本）

• ✅ 修复速度提取函数，正确显示编码速度值

• ✅ 修复CPU核心数提取错误（25653 → 256）

• ✅ 修复PSNR提取问题，正确显示质量指标

• ✅ 改进预计时间计算逻辑

• ✅ 优化多线程测试结果显示

版本 1.0（初始版本）

• ✅ 基础编码/解码性能测试

• ✅ 多分辨率、多比特率支持

• ✅ 系统信息收集

• ✅ 详细报告生成

贡献指南

1. Fork本仓库
2. 创建功能分支：git checkout -b feature/your-feature
3. 提交更改：git commit -m 'Add some feature'
4. 推送到分支：git push origin feature/your-feature
5. 提交Pull Request

许可证

本项目采用MIT许可证。详见LICENSE文件。

支持与反馈

• 问题报告：https://github.com/dongchuang114/ffmpeg-performance-test-script/issues

• 功能请求：通过Issues提交

• 贡献代码：欢迎Pull Requests

相关资源

• https://ffmpeg.org/documentation.html

• https://trac.ffmpeg.org/wiki/Encode/H.264

• https://trac.ffmpeg.org/wiki/HWAccelIntro


