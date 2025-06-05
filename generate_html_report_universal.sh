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

# 在现有变量后添加以下代码

# ============ 新增：读取更多系统信息 ============
TOTAL_PHYSICAL_CORES=$(grep "总物理核心数" comparison_metrics.csv 2>/dev/null | cut -d',' -f3 | sed 's/^ *//;s/ *$//' || echo "未知")
CORES_PER_SOCKET=$(grep "每插槽核心数" comparison_metrics.csv 2>/dev/null | cut -d',' -f3 | sed 's/^ *//;s/ *$//' || echo "未知")
CPU_SOCKETS=$(grep "CPU插槽数" comparison_metrics.csv 2>/dev/null | cut -d',' -f3 | sed 's/^ *//;s/ *$//' || echo "未知")
OS_NAME=$(grep "操作系统" comparison_metrics.csv 2>/dev/null | cut -d',' -f3 | sed 's/^ *//;s/ *$//' || echo "未知")
OS_VERSION=$(grep "OS版本" comparison_metrics.csv 2>/dev/null | cut -d',' -f3 | sed 's/^ *//;s/ *$//' || echo "未知")
KERNEL_VERSION=$(grep "内核版本" comparison_metrics.csv 2>/dev/null | cut -d',' -f3 | sed 's/^ *//;s/ *$//' || echo "未知")
MEMORY_CHANNELS=$(grep "内存通道数" comparison_metrics.csv 2>/dev/null | cut -d',' -f3 | sed 's/^ *//;s/ *$//' || echo "未知")

# 清理变量值，确保是数字
CPU_CORES=$(echo "$CPU_CORES" | grep -oE '[0-9]+' || echo "0")
CPU_SOCKETS=$(echo "$CPU_SOCKETS" | grep -oE '[0-9]+' || echo "1")
TOTAL_PHYSICAL_CORES=$(echo "$TOTAL_PHYSICAL_CORES" | grep -oE '[0-9]+' || echo "0")
CORES_PER_SOCKET=$(echo "$CORES_PER_SOCKET" | grep -oE '[0-9]+' || echo "1")
MEMORY_CHANNELS=$(echo "$MEMORY_CHANNELS" | grep -oE '[0-9]+' || echo "0")
OS_VERSION=$(echo "$OS_VERSION" | grep -oE '[0-9.]+' || echo "")

# 如果总物理核心数为0，但CPU核心数有值，则尝试计算
if [ "$TOTAL_PHYSICAL_CORES" = "0" ] && [ "$CPU_CORES" != "0" ]; then
    if [ "$CPU_SOCKETS" != "0" ] && [ "$CORES_PER_SOCKET" != "0" ]; then
        TOTAL_PHYSICAL_CORES=$((CPU_SOCKETS * CORES_PER_SOCKET))
    else
        # 如果没有每插槽核心数，假设为单线程
        TOTAL_PHYSICAL_CORES="$CPU_CORES"
    fi
fi

# 如果CPU插槽数为0，设为1
if [ "$CPU_SOCKETS" = "0" ]; then
    CPU_SOCKETS="1"
fi

# 如果每插槽核心数为0，计算一个合理值
if [ "$CORES_PER_SOCKET" = "0" ] && [ "$TOTAL_PHYSICAL_CORES" != "0" ] && [ "$CPU_SOCKETS" != "0" ]; then
    CORES_PER_SOCKET=$((TOTAL_PHYSICAL_CORES / CPU_SOCKETS))
fi

# 格式化CPU信息
if [ "$CPU_SOCKETS" != "未知" ] && [ "$CPU_SOCKETS" -gt 1 ]; then
    CPU_DISPLAY="${CPU_CORES}线程 (${TOTAL_PHYSICAL_CORES}核心 × ${CPU_SOCKETS}P)"
else
    CPU_DISPLAY="${CPU_CORES}线程 (${TOTAL_PHYSICAL_CORES}核心)"
fi

# 格式化内存信息
if [ "$MEMORY_CHANNELS" != "未知" ]; then
    MEMORY_DISPLAY="${TOTAL_MEMORY}GB (${MEMORY_CHANNELS}通道)"
else
    MEMORY_DISPLAY="${TOTAL_MEMORY}GB"
fi

# 格式化OS信息
if [ "$OS_VERSION" != "未知" ]; then
    OS_DISPLAY="${OS_NAME} ${OS_VERSION}"
else
    OS_DISPLAY="${OS_NAME}"
fi

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
            padding: 20px 30px;
            text-align: center;
            position: relative;
            overflow: hidden;
        }

        .header h1 {
            font-size: 2rem;
            margin-bottom: 8px;
            font-weight: 700;
            text-shadow: 0 2px 4px rgba(0,0,0,0.2);
        }

        .header p {
            font-size: 0.9rem;
            opacity: 0.9;
            line-height: 1.4;
            margin: 5px 0;
        }        
        
        .summary-cards {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
            gap: 20px;
            padding: 25px;
            background: #f8fafc;
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
       
        /* 系统配置卡片特殊样式 */
        .system-config {
            grid-column: span 2;
            border-left-color: #4f46e5;
            background: linear-gradient(135deg, #f5f3ff, #ede9fe);
        }

        .system-details {
            display: flex;
            flex-direction: column;
            gap: 8px;
        }

        .system-row {
            display: flex;
            align-items: center;
            padding: 6px 0;
            border-bottom: 1px solid #e2e8f0;
        }

        .system-row:last-child {
            border-bottom: none;
        }

        .system-label {
            flex: 0 0 100px;
            font-size: 0.85rem;
            color: #64748b;
            font-weight: 500;
        }

        .system-value {
            flex: 1;
            font-size: 0.9rem;
            color: #1e293b;
            font-weight: 500;
            word-break: break-word;
        }

        /* 其他卡片优化 */
        .card.best {
            border-left-color: #10b981;
            background: linear-gradient(135deg, #f0fdf4, #dcfce7);
        }

        .card.worst {
            border-left-color: #ef4444;
            background: linear-gradient(135deg, #fef2f2, #fee2e2);
        }

        .card .value {
            font-size: 1.6rem;
            font-weight: bold;
            color: #1e293b;
            margin: 8px 0 4px 0;
        }

        .card .label {
            color: #64748b;
            font-size: 0.85rem;
            line-height: 1.4;
        }

    /* 响应式调整 */
    @media (max-width: 768px) {
        .system-config {
            grid-column: span 1;
        }
        
        .system-row {
            flex-direction: column;
            align-items: flex-start;
            gap: 4px;
        }
        
        .system-label {
            flex: none;
            width: 100%;
        }
    }
 
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
        /* 在现有CSS后添加以下样式 */
        .system-card {
            grid-column: span 2; /* 让系统配置卡片占两列宽度 */
        }

        .config-grid {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 10px;
            margin-top: 10px;
        }

        .config-item {
            display: flex;
            flex-direction: column;
            padding: 8px;
            background: #f8fafc;
            border-radius: 6px;
            border-left: 3px solid #4f46e5;
        }

        .config-label {
            font-size: 0.8rem;
            color: #64748b;
            margin-bottom: 4px;
            font-weight: 600;
        }

        .config-value {
            font-size: 0.9rem;
            color: #1e293b;
            font-weight: 500;
        }

    /* 响应式调整 */
    @media (max-width: 768px) {
        .system-card {
            grid-column: span 1;
        }
        
        .config-grid {
            grid-template-columns: 1fr;
        }
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
                <h3><i>⚙️</i> 系统配置详情</h3>
                <div class="config-grid">
                    <div class="config-item">
                        <div class="config-label">CPU架构</div>
                        <div class="config-value">${CPU_DISPLAY}</div>
                    </div>
                    <div class="config-item">
                        <div class="config-label">CPU型号</div>
                        <div class="config-value">${CPU_MODEL}</div>
                    </div>
                    <div class="config-item">
                        <div class="config-label">内存配置</div>
                        <div class="config-value">${MEMORY_DISPLAY}</div>
                    </div>
                    <div class="config-item">
                        <div class="config-label">操作系统</div>
                        <div class="config-value">${OS_DISPLAY}</div>
                    </div>
                    <div class="config-item">
                        <div class="config-label">内核版本</div>
                        <div class="config-value">${KERNEL_VERSION}</div>
                    </div>
                    <div class="config-item">
                        <div class="config-label">FFmpeg版本</div>
                        <div class="config-value">${FFMPEG_VERSION}</div>
                    </div>
                </div>
                </div>

            <div class="card">
                <h3><i>📊</i> 测试统计</h3>
                <div class="value">${TEST_COUNT}</div>
                <div class="label">测试数量</div>
                <div class="value">${TOTAL_DURATION}s</div>
                <div class="label">总测试时长</div>
            </div>

            <div class="card best">
                <h3><i>🏆</i> 最佳性能</h3>
                <div class="value">${BEST_SPEED:-0.00}x</div>
                <div class="label">${BEST_NAME:-无数据}</div>
            </div>

            <div class="card worst">
                <h3><i>⚠️</i> 性能瓶颈</h3>
                <div class="value">${WORST_SPEED:-0.00}x</div>
                <div class="label">${WORST_NAME:-无数据}</div>
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
