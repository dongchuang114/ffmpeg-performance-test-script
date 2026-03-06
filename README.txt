ffmpeg-performance-test-script

一个全面的FFmpeg性能测试工具套件，包含主测试脚本和HTML报告生成器。

【脚本说明】

1. ffmpeg-complete-benchmark.sh
   - 功能：运行完整的FFmpeg性能测试
   - 测试项目：编码、解码、滤镜处理、多线程性能
   - 输出：CSV格式的测试结果和系统信息

2. generate_html_report_universal.sh
   - 功能：生成交互式HTML性能报告
   - 输入：benchmark_results.csv 和 comparison_metrics.csv
   - 输出：performance_report.html（可视化报告）

【快速开始】

1. 运行性能测试：
   ./ffmpeg-complete-benchmark.sh [输入文件] [输出目录]

   示例：
   ./ffmpeg-complete-benchmark.sh input.mp4 ./test_results

2. 生成HTML报告：
   cd ./test_results
   ../generate_html_report_universal.sh

3. 查看报告：
   python3 -m http.server 8000
   浏览器访问：http://localhost:8000/performance_report.html

【主要功能】

- 多编码器测试：H.264、H.265、VP9
- 多分辨率测试：480p、720p、1080p
- 多比特率测试：2000k、5000k
- 解码性能测试
- 滤镜处理测试
- 多线程扩展测试（1-64线程）
- 自动性能等级标记（优秀/良好/一般/较差）
- 系统配置信息收集

【报告特性】

- 系统配置概览（CPU、内存、OS、FFmpeg版本）
- 测试统计摘要
- 最佳性能/性能瓶颈识别
- 详细测试数据表格（编码速度颜色标记）
- 响应式设计，支持移动设备查看

【使用示例】

# 完整测试流程
./ffmpeg-complete-benchmark.sh test.mp4 ./my_test
cd ./my_test
../generate_html_report_universal.sh
python3 -m http.server 8000

# 远程查看（SSH隧道）
ssh -N -L 18000:localhost:8000 user@server_ip
# 本地浏览器访问：http://localhost:18000/performance_report.html

【输出文件】

test_results/
├── benchmark_results.csv      # 主要性能数据
├── comparison_metrics.csv     # 系统配置信息
├── performance_report.html    # HTML可视化报告
├── system_info.txt           # 详细系统信息
├── logs/                     # 测试日志
└── videos/                   # 测试视频样本

【依赖要求】

- FFmpeg 4.4+
- bc（数学计算工具）
- 现代浏览器（查看HTML报告）

【故障排除】

1. 报告显示变量名而非实际值
   - 确保使用正确的脚本版本
   - 检查CSV文件是否存在且格式正确

2. CPU核心数显示错误
   - 脚本已包含修复逻辑
   - 可手动检查 comparison_metrics.csv

3. 无测试数据显示
   - 确认 benchmark_results.csv 文件存在且非空
   - 检查文件读取权限

【版本信息】

当前版本：v3.1
更新日期：2026-03-05
主要特性：修复版，改进变量显示和性能计算

【许可证】

MIT License
