ffmpeg 4.4

使用说明
1. 保存和运行脚本
# 保存脚本
nano ffmpeg-complete-benchmark.sh
# 粘贴上面的内容，保存退出

# 设置执行权限
chmod +x ffmpeg-complete-benchmark.sh

# 运行完整测试
./ffmpeg-complete-benchmark.sh
2. 配置参数
在脚本开头可以调整以下参数：
TEST_DURATION=10        # 每个测试时长
RESOLUTIONS="1920x1080" # 测试分辨率
BITRATES="2000k"        # 测试比特率
TEST_ITERATIONS=1       # 测试迭代次数
ENABLE_HARDWARE_TESTS=true  # 是否测试硬件加速
ENABLE_QUALITY_TESTS=true   # 是否测试质量
3. 对比测试
在不同系统上运行后，对比以下文件：
# 1. 系统配置对比
cat comparison_metrics.csv

# 2. 性能数据对比
cat benchmark_results.csv

# 3. 查看HTML报告
firefox report.html
4. 预期输出文件
输出目录/
├── benchmark_*.log              # 完整日志
├── benchmark_results.csv        # 性能数据
├── speed_results.csv            # 速度排名
├── quality_results.csv          # 质量分析
├── comparison_metrics.csv       # 对比指标
├── system_info.txt             # 系统信息
├── test_config.txt             # 测试配置
├── execution_summary.txt       # 执行摘要
├── detailed_report.txt         # 详细报告
├── report.html                 # HTML报告
├── logs/                       # 详细日志
│   ├── encode_*.log
│   └── decode_*.log
└── videos/                     # 测试视频
    └── quality_*.mp4
跨系统对比要点
保持测试环境一致：
相同的FFmpeg版本
相同的测试参数
相似的系统负载
记录环境差异：
CPU频率状态（性能模式/节能模式）
内存频率和时序
散热条件
多次测试取平均：
建议每个系统运行3次
取平均值进行比较
注意环境温度的差异
