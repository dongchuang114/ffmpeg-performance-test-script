ffmpeg version 6.1.1-3ubuntu5

FFmpeg性能基准测试脚本 v2.1

一个全面的FFmpeg性能测试工具，用于评估视频编码、解码、滤镜处理和多线程性能。本版本修复了速度提取、CPU核心数计算和PSNR提取问题，并增加了HTML可视化报告功能。

主要改进

✅ 修复的问题

1. 速度提取修复：修复了编码速度显示为"x"的问题，现在正确显示实际速度值（如11.45x）
2. CPU核心数修复：修复了CPU核心数提取错误（从25653修复为正确的256）
3. PSNR提取修复：修复了质量测试中PSNR始终显示0.00dB的问题
4. 预计时间计算改进：改进了预计运行时间的计算逻辑
5. 多线程测试显示优化：优化了多线程测试结果的显示

✅ 新增功能

1. HTML可视化报告：生成交互式HTML报告，包含性能图表和数据分析
2. 文本摘要报告：生成简洁的文本摘要，快速查看关键性能指标
3. 性能等级自动标记：自动标记优秀(≥5x)、良好(≥2x)、一般(≥1x)、较差(<1x)性能等级
4. 优化建议：基于测试结果提供实用优化建议

使用说明

1. 保存和运行脚本

# 保存脚本
nano ffmpeg-complete-benchmark.sh
# 粘贴脚本内容，保存退出

# 设置执行权限
chmod +x ffmpeg-complete-benchmark.sh

# 运行完整测试
./ffmpeg-complete-benchmark.sh


2. 配置参数

在脚本开头可以调整以下参数：
# 基础测试配置
TEST_DURATION=10              # 每个测试时长（秒）
RESOLUTIONS="854x480 1280x720 1920x1080"  # 测试分辨率列表
BITRATES="2000k 5000k"        # 测试比特率列表
TEST_ITERATIONS=2             # 测试迭代次数（推荐2-3次取平均）
TIMEOUT_SECONDS=300           # 单个测试超时时间

# 功能开关
ENABLE_HARDWARE_TESTS=false   # 是否测试硬件加速
ENABLE_QUALITY_TESTS=true     # 是否测试质量
ENABLE_HTML_REPORT=true       # 是否生成HTML报告（新增）
SKIP_AV1=true                 # 是否跳过AV1编码测试


3. 命令行参数

脚本支持命令行参数，无需编辑脚本：
# 查看帮助
./ffmpeg-complete-benchmark.sh --help

# 查看版本
./ffmpeg-complete-benchmark.sh --version

# 使用自定义参数运行
./ffmpeg-complete-benchmark.sh \
  -d 30 \
  -i 3 \
  -r "1920x1080 3840x2160" \
  -b "5000k 10000k" \
  --enable-hardware \
  input.mp4 ./results


4. 对比测试

在不同系统上运行后，对比以下文件：
# 1. 系统配置对比
cat comparison_metrics.csv

# 2. 性能数据对比
cat benchmark_results.csv

# 3. 查看HTML报告
# 在服务器上启动HTTP服务器查看，在ffmpeg_benchmark_xxx中运行下面命令
python3 -m http.server 8000
# 浏览器访问: http://localhost:8000/performance_report.html
# 远端终端访问,先打通隧道：
ssh -N -L 18000:localhost:8000 user@server_ip
# 远端终端浏览器访问：http://localhost:18000/performance_report.html

预期输出文件


输出目录/
├── benchmark_results.csv      # 主要性能数据
├── comparison_metrics.csv     # 系统对比指标
├── system_info.txt           # 详细系统信息
├── execution_summary.txt     # 执行摘要
├── benchmark_*.log           # 完整日志文件
├── performance_report.html   # HTML可视化报告（新增）
├── summary_report.txt        # 文本摘要报告（新增）
├── logs/                     # 详细测试日志
│   ├── encode_*.log
│   ├── decode_*.log
│   └── filter_*.log
└── videos/                   # 质量测试视频
    └── quality_*.mp4


HTML报告功能

报告包含内容

1. 性能摘要卡片：系统配置、测试统计、最佳性能、性能瓶颈
2. 详细数据表格：所有测试结果的表格展示，带性能等级标记
3. 编码器性能排名：不同编码器、预设、分辨率的性能对比
4. 多线程性能分析：1-64线程的性能扩展曲线
5. 优化建议：基于测试结果的实用建议

查看报告的方法

方法1：SSH隧道（推荐，安全）

# 在服务器上启动HTTP服务器
cd ./ffmpeg_benchmark_20260304_120212
python3 -m http.server 8000 --bind 0.0.0.0

# 在Windows笔记本上建立SSH隧道
# 打开CMD或PowerShell，运行：
ssh -N -L 18000:localhost:8000 username@server_ip

# 在浏览器中访问
# http://localhost:18000/performance_report.html


方法2：PuTTY隧道

1. 在PuTTY中配置SSH隧道：Connection -> SSH -> Tunnels
2. 添加端口转发：Source: 18000, Destination: localhost:8000
3. 连接服务器，启动HTTP服务器
4. 在浏览器中访问：http://localhost:18000/performance_report.html

测试项目说明

脚本会自动运行以下测试：

1. 编码性能测试

• H.264编码：medium/slow预设

• H.265编码：medium预设

• VP9编码：good质量预设

• 测试分辨率：854x480, 1280x720, 1920x1080

• 测试比特率：2000k, 5000k

2. 解码性能测试

• H.264解码

• H.265解码

• VP9解码

3. 滤镜处理测试

• 缩放滤镜（720p, 1080p）

• 水平翻转

• 垂直翻转

• 盒式模糊

4. 多线程测试

• 测试1, 2, 4, 8, 16, 32, 64线程性能

5. 质量测试（可选）

• SSIM/PSNR质量指标

• 不同编码器和比特率的压缩效率对比

性能指标解读

指标 说明 理想值

平均时间(秒) 完成测试的平均时间 越小越好

编码速度(x) FFmpeg报告的编码速度 越大越好

实时倍数(x) 相对于实时播放的速度 >1表示快于实时

测试耗时(秒) 包括准备和清理的总时间 -
性能等级评估
实时倍数 性能等级 颜色标记 说明

≥5x 🟢 优秀 绿色 性能卓越

2-5x 🟡 良好 蓝色 性能良好

1-2x 🟠 一般 橙色 基本满足需求

<1x 🔴 较差 红色 低于实时速度

跨系统对比要点

保持测试环境一致：

• 相同的FFmpeg版本

• 相同的测试参数

• 相似的系统负载

记录环境差异：

• CPU频率状态（性能模式/节能模式）

• 内存频率和时序

• 散热条件

多次测试取平均：

• 建议每个系统运行3次

• 取平均值进行比较

• 注意环境温度的差异

故障排除

常见问题

1. HTML报告无法加载数据
   • 原因：浏览器安全限制，禁止加载本地文件

   • 解决：使用HTTP服务器查看，不要直接双击HTML文件

2. 速度值显示为"x"
   • 原因：FFmpeg输出格式变化

   • 解决：已修复，确保使用最新版本脚本

3. CPU核心数显示错误
   • 原因：lscpu输出解析问题

   • 解决：已修复，使用正确的提取逻辑

4. PSNR始终显示0.00dB
   • 原因：PSNR提取逻辑错误

   • 解决：已修复，正确解析FFmpeg输出

依赖检查

脚本需要以下工具：
• FFmpeg 4.4+：视频处理工具

• bc：数学计算工具

• python3：HTML报告查看（可选）

安装依赖：
# Ubuntu/Debian
sudo apt install ffmpeg bc python3

# CentOS/RHEL
sudo yum install ffmpeg bc python3


更新日志

版本 2.1 (2026-03-04)

• ✅ 新增HTML可视化报告功能

• ✅ 新增文本摘要报告

• ✅ 修复速度提取函数，正确显示编码速度

• ✅ 修复CPU核心数提取，正确显示256核

• ✅ 修复PSNR提取问题，正确显示质量指标

• ✅ 改进预计时间计算逻辑

• ✅ 优化多线程测试结果显示

• ✅ 增加性能等级自动标记

• ✅ 提供基于测试结果的优化建议

版本 1.0 (初始版本)

• ✅ 基础编码/解码性能测试

• ✅ 多分辨率、多比特率支持

• ✅ 系统信息收集

• ✅ CSV格式报告生成

许可证

本项目采用MIT许可证。详见LICENSE文件。

支持与反馈

• 问题报告：https://github.com/dongchuang114/ffmpeg-performance-test-script/issues

• 功能请求：通过Issues提交

• 贡献代码：欢迎Pull Requests

提示：运行完整测试可能需要30-60分钟，具体取决于系统性能。建议在系统空闲时运行以获得准确结果。HTML报告功能需要浏览器支持，建议使用Chrome、Firefox或Edge最新版本。

相关资源

• https://ffmpeg.org/documentation.html

• https://trac.ffmpeg.org/wiki/Encode/H.264

• https://trac.ffmpeg.org/wiki/HWAccelIntro


