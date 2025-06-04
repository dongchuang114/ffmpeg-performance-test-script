#!/bin/bash
# 通用HTML报告生成脚本
# 用法: ./generate_html_report_universal.sh [测试目录]

set -e

echo "正在生成HTML报告..."

# 参数处理
if [ $# -ge 1 ] && [ -d "$1" ]; then
    # 如果指定了目录，使用该目录
    REPORT_DIR="$1"
    echo "使用指定目录: $REPORT_DIR"
else
    # 否则在当前目录查找最新的测试目录
    echo "在当前目录查找测试目录..."
    
    # 先检查当前目录是否是测试目录
    if [ -f "benchmark_results.csv" ]; then
        REPORT_DIR="."
        echo "当前目录包含测试数据"
    else
        # 查找最近的测试目录
        REPORT_DIR=$(find . -maxdepth 1 -type d -name "ffmpeg_benchmark_*" -o -name "*_test_results" 2>/dev/null | sort -r | head -1)
        
        if [ -z "$REPORT_DIR" ]; then
            echo "错误: 未找到测试目录"
            echo "请执行以下操作之一:"
            echo "1. 在测试目录中运行此脚本"
            echo "2. 指定测试目录路径: $0 /path/to/test/dir"
            echo ""
            echo "可用的测试目录:"
            find . -maxdepth 2 -type d -name "ffmpeg_benchmark_*" -o -name "*_test_results" 2>/dev/null || true
            exit 1
        fi
        
        echo "找到测试目录: $REPORT_DIR"
    fi
fi

cd "$REPORT_DIR" || {
    echo "无法进入目录: $REPORT_DIR"
    exit 1
}

echo "在目录: $(pwd)"

# 检查必要文件
check_file() {
    if [ ! -f "$1" ]; then
        echo "警告: 未找到 $1，某些功能可能受限"
        return 1
    fi
    return 0
}

check_file "benchmark_results.csv" || {
    echo "错误: benchmark_results.csv 是必需的"
    exit 1
}

# 读取系统信息
CPU_CORES=$(grep "物理核心数" comparison_metrics.csv 2>/dev/null | cut -d',' -f3 | sed 's/^ *//;s/ *$//' || echo "未知")
CPU_MODEL=$(grep "CPU型号" comparison_metrics.csv 2>/dev/null | cut -d',' -f3 | sed 's/^ *//;s/ *$//' | head -1 || echo "未知")
TOTAL_MEMORY=$(grep "总内存(GB)" comparison_metrics.csv 2>/dev/null | cut -d',' -f3 | sed 's/^ *//;s/ *$//' || echo "未知")
FFMPEG_VERSION=$(grep "FFmpeg版本" comparison_metrics.csv 2>/dev/null | cut -d',' -f3 | sed 's/^ *//;s/ *$//' || echo "未知")

# 解析最佳和最差性能
echo "分析性能数据..."

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
    } else {
        printf "无数据|0.00"
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
    } else {
        printf "无数据|0.00"
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
echo "生成HTML表格数据..."
CSV_ROWS=""
ROW_COUNT=0

while IFS= read -r line; do
    if [ -n "$line" ]; then
        IFS=',' read -r timestamp test_name avg_time encode_speed realtime_speed test_duration <<< "$line"
        
        # 清理数据
        test_name=$(echo "$test_name" | sed 's/^ *//;s/ *$//')
        avg_time=$(echo "$avg_time" | sed 's/^ *//;s/ *$//')
        encode_speed=$(echo "$encode_speed" | sed 's/^ *//;s/ *$//')
        realtime_speed_num=$(echo "$realtime_speed" | sed 's/^ *//;s/ *$//;s/x$//' 2>/dev/null || echo "0")
        test_duration=$(echo "$test_duration" | sed 's/^ *//;s/ *$//')
        
        # 确定性能等级
        speed_class="speed-fair"
        badge_class="badge-fair"
        badge_text="一般"
        
        if [ -n "$realtime_speed_num" ] && [ "$realtime_speed_num" != "N/A" ]; then
            if [ "$(echo "$realtime_speed_num >= 5" 2>/dev/null | bc)" = "1" ]; then
                speed_class="speed-excellent"
                badge_class="badge-excellent"
                badge_text="优秀"
            elif [ "$(echo "$realtime_speed_num >= 2" 2>/dev/null | bc)" = "1" ]; then
                speed_class="speed-good"
                badge_class="badge-good"
                badge_text="良好"
            elif [ "$(echo "$realtime_speed_num >= 1" 2>/dev/null | bc)" = "1" ]; then
                speed_class="speed-fair"
                badge_class="badge-fair"
                badge_text="一般"
            else
                speed_class="speed-poor"
                badge_class="badge-poor"
                badge_text="较差"
            fi
        fi
        
        CSV_ROWS="${CSV_ROWS}<tr>
            <td>${test_name}</td>
            <td>${avg_time}</td>
            <td>${encode_speed}</td>
            <td class=\"${speed_class}\">${realtime_speed}</td>
            <td>${test_duration}</td>
            <td><span class=\"badge ${badge_class}\">${badge_text}</span></td>
        </tr>"
        
        ROW_COUNT=$((ROW_COUNT + 1))
    fi
done <<< "$(tail -n +2 benchmark_results.csv 2>/dev/null)"

# 生成HTML报告
OUTPUT_FILE="performance_report.html"
echo "生成HTML文件: $OUTPUT_FILE"

cat > "$OUTPUT_FILE" << HTML_EOF
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
        
        .empty-message {
            text-align: center;
            padding: 40px;
            color: #64748b;
            font-style: italic;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 FFmpeg性能测试报告</h1>
            <p>生成时间: $(date '+%Y年%m月%d日 %H:%M:%S')</p>
            <p>测试目录: $(basename "$(pwd)")</p>
        </div>
        
        <div class="summary-cards">
            <div class="card">
                <h3>系统配置</h3>
                <div class="value">${CPU_CORES}</div>
                <div class="label">CPU核心</div>
                <div class="value">${CPU_MODEL}</div>
                <div class="label">CPU型号</div>
            </div>
            
            <div class="card">
                <h3>测试统计</h3>
                <div class="value">${TEST_COUNT}</div>
                <div class="label">测试数量</div>
                <div class="value">${TOTAL_DURATION}s</div>
                <div class="label">总测试时长</div>
            </div>
            
            <div class="card best">
                <h3>最佳性能</h3>
                <div class="value">${BEST_SPEED}x</div>
                <div class="label">${BEST_NAME}</div>
            </div>
            
            <div class="card worst">
                <h3>性能瓶颈</h3>
                <div class="value">${WORST_SPEED}x</div>
                <div class="label">${WORST_NAME}</div>
            </div>
        </div>
        
        <div class="section">
            <h2 class="section-title">📊 详细测试数据 (${ROW_COUNT}个测试)</h2>
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
                        ${CSV_ROWS:-<tr><td colspan="6" class="empty-message">无测试数据</td></tr>}
                    </tbody>
                </table>
            </div>
        </div>
        
        <div class="footer">
            <p>📊 FFmpeg性能测试报告 | 版本: 2.2</p>
            <p>🔧 FFmpeg版本: ${FFMPEG_VERSION}</p>
            <p>📁 目录: $(pwd)</p>
        </div>
    </div>
</body>
</html>
HTML_EOF

echo ""
echo "✅ HTML报告已生成: $(pwd)/$OUTPUT_FILE"
echo "📊 包含 ${ROW_COUNT} 个测试结果"
echo ""
echo "💡 查看报告的方法:"
echo "   1. 在当前目录启动HTTP服务器: python3 -m http.server 8000"
echo "   2. 在浏览器中访问: http://localhost:8000/$OUTPUT_FILE"
echo "   3. 或通过SSH隧道访问（如果从远程连接）"
echo ""
echo "🔄 完成!"
