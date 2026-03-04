#!/bin/bash
# 生成HTML报告脚本 - 修复版本

echo "正在生成HTML报告..."

# 查找最新的测试目录
latest_dir=$(ls -td /work/ffmpeg-performance-test-script/ffmpeg_benchmark_* 2>/dev/null | head -1)
if [ -z "$latest_dir" ]; then
    latest_dir=$(ls -td /work/ffmpeg-performance-test-script/fixed_test_results 2>/dev/null | head -1)
fi

if [ -z "$latest_dir" ] || [ ! -d "$latest_dir" ]; then
    echo "未找到测试目录"
    exit 1
fi

cd "$latest_dir" || exit 1

echo "在目录: $(pwd)"

# 检查CSV文件
if [ ! -f "benchmark_results.csv" ]; then
    echo "错误: 未找到 benchmark_results.csv"
    exit 1
fi

# 读取系统信息
CPU_CORES=$(grep "物理核心数" comparison_metrics.csv 2>/dev/null | cut -d',' -f3 | sed 's/^ *//;s/ *$//')
CPU_MODEL=$(grep "CPU型号" comparison_metrics.csv 2>/dev/null | cut -d',' -f3 | sed 's/^ *//;s/ *$//' | head -1)
TOTAL_MEMORY=$(grep "总内存(GB)" comparison_metrics.csv 2>/dev/null | cut -d',' -f3 | sed 's/^ *//;s/ *$//')
FFMPEG_VERSION=$(grep "FFmpeg版本" comparison_metrics.csv 2>/dev/null | cut -d',' -f3 | sed 's/^ *//;s/ *$//')

# 解析最佳和最差性能
BEST_INFO=$(tail -n +2 benchmark_results.csv 2>/dev/null | grep "encode_" | awk -F',' '
{
    speed = $4;
    gsub(/x/, "", speed);
    if (speed + 0 > max) {
        max = speed + 0;
        best_line = $0;
    }
}
END {
    if (best_line) {
        split(best_line, arr, ",");
        printf "%s|%.2f", arr[1], max;
    }
}')

WORST_INFO=$(tail -n +2 benchmark_results.csv 2>/dev/null | grep "encode_" | awk -F',' '
BEGIN {
    min = 999999;
}
{
    speed = $4;
    gsub(/x/, "", speed);
    if (speed + 0 > 0 && speed + 0 < min) {
        min = speed + 0;
        worst_line = $0;
    }
}
END {
    if (worst_line) {
        split(worst_line, arr, ",");
        printf "%s|%.2f", arr[1], min;
    }
}')

BEST_NAME=$(echo "$BEST_INFO" | cut -d'|' -f1)
BEST_SPEED=$(echo "$BEST_INFO" | cut -d'|' -f2)
WORST_NAME=$(echo "$WORST_INFO" | cut -d'|' -f1)
WORST_SPEED=$(echo "$WORST_INFO" | cut -d'|' -f2)

# 计算测试数量和总时长
TEST_COUNT=$(tail -n +2 benchmark_results.csv 2>/dev/null | wc -l | tr -d ' ')
TOTAL_DURATION=$(tail -n +2 benchmark_results.csv 2>/dev/null | awk -F',' '{sum += $5} END {printf "%.0f", sum}')

# 生成CSV数据行的HTML
CSV_ROWS=""
while IFS= read -r line; do
    if [ -n "$line" ]; then
        IFS=',' read -r timestamp test_name avg_time encode_speed realtime_speed test_duration <<< "$line"
        
        # 清理数据
        test_name=$(echo "$test_name" | sed 's/^ *//;s/ *$//')
        avg_time=$(echo "$avg_time" | sed 's/^ *//;s/ *$//')
        encode_speed=$(echo "$encode_speed" | sed 's/^ *//;s/ *$//')
        realtime_speed_num=$(echo "$realtime_speed" | sed 's/^ *//;s/ *$//;s/x$//')
        test_duration=$(echo "$test_duration" | sed 's/^ *//;s/ *$//')
        
        # 确定性能等级
        if [ "$(echo "$realtime_speed_num >= 5" | bc 2>/dev/null)" = "1" ]; then
            speed_class="speed-excellent"
            badge_class="badge-excellent"
            badge_text="优秀"
        elif [ "$(echo "$realtime_speed_num >= 2" | bc 2>/dev/null)" = "1" ]; then
            speed_class="speed-good"
            badge_class="badge-good"
            badge_text="良好"
        elif [ "$(echo "$realtime_speed_num >= 1" | bc 2>/dev/null)" = "1" ]; then
            speed_class="speed-fair"
            badge_class="badge-fair"
            badge_text="一般"
        else
            speed_class="speed-poor"
            badge_class="badge-poor"
            badge_text="较差"
        fi
        
        CSV_ROWS="${CSV_ROWS}<tr>
            <td>${test_name}</td>
            <td>${avg_time}</td>
            <td>${encode_speed}</td>
            <td class=\"${speed_class}\">${realtime_speed}</td>
            <td>${test_duration}</td>
            <td><span class=\"badge ${badge_class}\">${badge_text}</span></td>
        </tr>"
    fi
done <<< "$(tail -n +2 benchmark_results.csv 2>/dev/null)"

# 生成HTML报告
cat > performance_report_simple.html << HTML_EOF
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>FFmpeg性能测试报告 - $(date '+%Y年%m月%d日 %H:%M:%S')</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
            font-family: 'Segoe UI', 'Microsoft YaHei', sans-serif;
        }
        
        body {
            background: #f5f7fa;
            min-height: 100vh;
            padding: 20px;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 10px;
            box-shadow: 0 5px 20px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        
        .header {
            background: linear-gradient(90deg, #4f46e5, #7c3aed);
            color: white;
            padding: 30px;
            text-align: center;
        }
        
        .header h1 {
            font-size: 2.2rem;
            margin-bottom: 10px;
        }
        
        .summary-cards {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            padding: 20px;
        }
        
        .card {
            background: white;
            border-radius: 10px;
            padding: 20px;
            box-shadow: 0 3px 10px rgba(0,0,0,0.08);
            border-left: 4px solid #4f46e5;
        }
        
        .card.best {
            border-left-color: #10b981;
        }
        
        .card.worst {
            border-left-color: #ef4444;
        }
        
        .card h3 {
            color: #4f46e5;
            margin-bottom: 10px;
            font-size: 1rem;
        }
        
        .card .value {
            font-size: 1.8rem;
            font-weight: bold;
            color: #1e293b;
        }
        
        .card .label {
            color: #64748b;
            font-size: 0.9rem;
        }
        
        .section {
            padding: 20px;
            border-top: 1px solid #e2e8f0;
        }
        
        .section-title {
            font-size: 1.4rem;
            color: #1e293b;
            margin-bottom: 20px;
        }
        
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
        }
        
        th {
            background: #f8fafc;
            color: #475569;
            padding: 12px 15px;
            text-align: left;
            font-weight: 600;
            border-bottom: 2px solid #e2e8f0;
        }
        
        td {
            padding: 10px 15px;
            border-bottom: 1px solid #e2e8f0;
        }
        
        tr:hover {
            background-color: #f8fafc;
        }
        
        .badge {
            display: inline-block;
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 0.85rem;
            font-weight: 600;
        }
        
        .badge-excellent { background: #10b981; color: white; }
        .badge-good { background: #3b82f6; color: white; }
        .badge-fair { background: #f59e0b; color: white; }
        .badge-poor { background: #ef4444; color: white; }
        
        .speed-excellent { color: #10b981; font-weight: bold; }
        .speed-good { color: #3b82f6; font-weight: bold; }
        .speed-fair { color: #f59e0b; font-weight: bold; }
        .speed-poor { color: #ef4444; font-weight: bold; }
        
        .footer {
            text-align: center;
            padding: 20px;
            background: #1e293b;
            color: #cbd5e1;
        }
        
        @media (max-width: 768px) {
            table {
                display: block;
                overflow-x: auto;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 FFmpeg性能测试报告</h1>
            <p>测试时间: $(date '+%Y年%m月%d日 %H:%M:%S')</p>
        </div>
        
        <div class="summary-cards">
            <div class="card">
                <h3>系统配置</h3>
                <div class="value">${CPU_CORES:-256} 核心</div>
                <div class="label">${CPU_MODEL:-AMD EPYC 9755}</div>
                <div class="value">${TOTAL_MEMORY:-1507.08} GB</div>
                <div class="label">内存</div>
            </div>
            
            <div class="card">
                <h3>测试统计</h3>
                <div class="value">${TEST_COUNT:-0}</div>
                <div class="label">完成测试数量</div>
                <div class="value">${TOTAL_DURATION:-0}s</div>
                <div class="label">总测试时长</div>
            </div>
            
            <div class="card best">
                <h3>最佳性能</h3>
                <div class="value">${BEST_SPEED:-0.00}x</div>
                <div class="label">${BEST_NAME:-无数据}</div>
            </div>
            
            <div class="card worst">
                <h3>性能瓶颈</h3>
                <div class="value">${WORST_SPEED:-0.00}x</div>
                <div class="label">${WORST_NAME:-无数据}</div>
            </div>
        </div>
        
        <div class="section">
            <h2 class="section-title">📊 详细测试数据</h2>
            <div style="overflow-x: auto;">
                <table>
                    <thead>
                        <tr>
                            <th>测试名称</th>
                            <th>平均时间(秒)</th>
                            <th>编码速度</th>
                            <th>实时倍数</th>
                            <th>测试耗时</th>
                            <th>性能等级</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${CSV_ROWS}
                    </tbody>
                </table>
            </div>
        </div>
        
        <div class="footer">
            <p>📊 FFmpeg性能测试报告 | 生成时间: $(date '+%Y-%m-%d %H:%M:%S')</p>
            <p>🔧 测试脚本版本: 2.1 | FFmpeg版本: ${FFMPEG_VERSION:-6.1.1}</p>
        </div>
    </div>
</body>
</html>
HTML_EOF

echo "HTML报告已生成: $(pwd)/performance_report_simple.html"
echo "启动HTTP服务器查看..."
echo "运行: python3 -m http.server 8000 --bind 0.0.0.0"
