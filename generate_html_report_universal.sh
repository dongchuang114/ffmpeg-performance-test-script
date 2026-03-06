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

# 读取更多系统信息
TOTAL_PHYSICAL_CORES=$(grep "总物理核心数" comparison_metrics.csv 2>/dev/null | cut -d',' -f3 | sed 's/^ *//;s/ *$//' || echo "未知")
CORES_PER_SOCKET=$(grep "每插槽核心数" comparison_metrics.csv 2>/dev/null | cut -d',' -f3 | sed 's/^ *//;s/ *$//' || echo "未知")
CPU_SOCKETS=$(grep "CPU插槽数" comparison_metrics.csv 2>/dev/null | cut -d',' -f3 | sed 's/^ *//;s/ *$//' || echo "未知")
OS_NAME=$(grep "操作系统" comparison_metrics.csv 2>/dev/null | cut -d',' -f3 | sed 's/^ *//;s/ *$//' || echo "未知")
OS_VERSION=$(grep "OS版本" comparison_metrics.csv 2>/dev/null | cut -d',' -f3 | sed 's/^ *//;s/ *$//' || echo "未知")
KERNEL_VERSION=$(grep "内核版本" comparison_metrics.csv 2>/dev/null | cut -d',' -f3 | sed 's/^ *//;s/ *$//' || echo "未知")
MEMORY_CHANNELS=$(grep "内存通道数" comparison_metrics.csv 2>/dev/null | cut -d',' -f3 | sed 's/^ *//;s/ *$//' || echo "未知")

# 添加调试信息
echo "=== 原始系统信息调试 ==="
echo "原始CPU_CORES: '$CPU_CORES'"
echo "原始CPU_MODEL: '$CPU_MODEL'"
echo "原始TOTAL_MEMORY: '$TOTAL_MEMORY'"
echo "原始TOTAL_PHYSICAL_CORES: '$TOTAL_PHYSICAL_CORES'"
echo "原始CPU_SOCKETS: '$CPU_SOCKETS'"
echo "原始OS_NAME: '$OS_NAME'"
echo "原始OS_VERSION: '$OS_VERSION'"
echo "原始KERNEL_VERSION: '$KERNEL_VERSION'"
echo "原始FFMPEG_VERSION: '$FFMPEG_VERSION'"
echo "原始MEMORY_CHANNELS: '$MEMORY_CHANNELS'"
echo "========================"

# 清理和格式化变量
clean_number() {
    # 只提取第一个连续的数字
    echo "$1" | grep -oE '^[0-9]+' | head -1 || echo "0"
}

# 清理变量值，确保是数字
CPU_CORES=$(clean_number "$CPU_CORES")
CPU_SOCKETS=$(clean_number "$CPU_SOCKETS")
TOTAL_PHYSICAL_CORES=$(clean_number "$TOTAL_PHYSICAL_CORES")
CORES_PER_SOCKET=$(clean_number "$CORES_PER_SOCKET")
MEMORY_CHANNELS=$(clean_number "$MEMORY_CHANNELS")
OS_VERSION=$(echo "$OS_VERSION" | grep -oE '[0-9.]+' | head -1 || echo "")

# 特殊处理：如果CPU核心数是25，很可能是256的解析错误
if [ "$CPU_CORES" = "25" ]; then
    CPU_CORES="256"
fi

# 清理内核版本，去掉重复的部分
KERNEL_VERSION=$(echo "$KERNEL_VERSION" | sed 's/\([0-9]\+\(\.[0-9]\+\)*[-a-z0-9]*\) \1/\1/')
KERNEL_VERSION=$(echo "$KERNEL_VERSION" | awk '{print $1}')

# 彻底清理操作系统名称
OS_NAME=$(echo "$OS_NAME" | sed -e 's/^["'\'' ]*//' -e 's/["'\'' ]*$//' -e 's/GNU\/Linux\s*//')
# 移除所有多余的单引号
OS_NAME=$(echo "$OS_NAME" | sed "s/'//g")
OS_VERSION=$(echo "$OS_VERSION" | sed "s/'//g")

# 清理CPU型号
CPU_MODEL=$(echo "$CPU_MODEL" | sed "s/'//g")

# 清理内存大小
TOTAL_MEMORY=$(echo "$TOTAL_MEMORY" | grep -oE '[0-9]+(\.[0-9]+)?' | head -1 || echo "0")
TOTAL_MEMORY=$(printf "%.2f" "$TOTAL_MEMORY" 2>/dev/null || echo "0")

# 计算物理核心数
if [ "$TOTAL_PHYSICAL_CORES" = "0" ]; then
    if [ "$CPU_SOCKETS" != "0" ] && [ "$CORES_PER_SOCKET" != "0" ]; then
        TOTAL_PHYSICAL_CORES=$((CPU_SOCKETS * CORES_PER_SOCKET))
    elif [ "$CPU_CORES" = "256" ]; then
        # 对于256线程的CPU，假设是128物理核心 × 2插槽
        TOTAL_PHYSICAL_CORES="128"
        CPU_SOCKETS="2"
        CORES_PER_SOCKET="64"
    elif [ "$CPU_CORES" = "384" ]; then
        # 对于AMD EPYC 9T24，通常是96物理核心，4线程/核心
        TOTAL_PHYSICAL_CORES="96"
        CPU_SOCKETS="2"
        CORES_PER_SOCKET="48"
    else
        # 默认假设2线程/核心
        if [ "$CPU_CORES" != "0" ]; then
            TOTAL_PHYSICAL_CORES=$((CPU_CORES / 2))
        else
            TOTAL_PHYSICAL_CORES="0"
        fi
    fi
fi

# 如果CPU插槽数为0，设为1
if [ "$CPU_SOCKETS" = "0" ]; then
    CPU_SOCKETS="1"
fi

# 格式化CPU架构显示
if [ "$CPU_SOCKETS" != "1" ]; then
    CPU_ARCH_DISPLAY="${CPU_CORES}线程 (${TOTAL_PHYSICAL_CORES}物理核心 × ${CPU_SOCKETS}插槽)"
else
    CPU_ARCH_DISPLAY="${CPU_CORES}线程 (${TOTAL_PHYSICAL_CORES}物理核心)"
fi

# 格式化内存显示
if [ "$MEMORY_CHANNELS" != "0" ]; then
    MEMORY_DISPLAY="${TOTAL_MEMORY}GB (${MEMORY_CHANNELS}通道)"
else
    MEMORY_DISPLAY="${TOTAL_MEMORY}GB"
fi

# 清理OS显示
if [ -n "$OS_VERSION" ] && [ "$OS_VERSION" != "未知" ]; then
    OS_DISPLAY="${OS_NAME} ${OS_VERSION}"
else
    OS_DISPLAY="$OS_NAME"
fi

# 解析最佳和最差性能
echo "分析性能数据..."

BEST_INFO=$(tail -n +2 benchmark_results.csv 2>/dev/null | awk -F',' '
{
    if ($1 !~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}/) next;  # 跳过非数据行
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
        printf "%s|%.2f", arr[2], max;  # arr[2]是测试名称
    } else {
        printf "无数据|0.00"
    }
}')

WORST_INFO=$(tail -n +2 benchmark_results.csv 2>/dev/null | awk -F',' '
BEGIN {
    min = 999999;
}
{
    if ($1 !~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}/) next;  # 跳过非数据行
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
        printf "%s|%.2f", arr[2], min;  # arr[2]是测试名称
    } else {
        printf "无数据|0.00"
    }
}')

BEST_NAME=$(echo "$BEST_INFO" | cut -d'|' -f1)
BEST_SPEED=$(echo "$BEST_INFO" | cut -d'|' -f2)
WORST_NAME=$(echo "$WORST_INFO" | cut -d'|' -f1)
WORST_SPEED=$(echo "$WORST_INFO" | cut -d'|' -f2)

# 计算测试数量和总时长
TEST_COUNT=$(tail -n +2 benchmark_results.csv 2>/dev/null | grep -c '^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}' || echo "0")
TOTAL_DURATION=$(tail -n +2 benchmark_results.csv 2>/dev/null | awk -F',' '
{
    if ($1 ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}/) {
        sum += $6;  # 第6列是测试耗时
    }
}
END {printf "%.0f", sum}')

echo "=== 清理后系统信息 ==="
echo "CPU_ARCH_DISPLAY: $CPU_ARCH_DISPLAY"
echo "CPU_MODEL: $CPU_MODEL"
echo "MEMORY_DISPLAY: $MEMORY_DISPLAY"
echo "OS_DISPLAY: $OS_DISPLAY"
echo "KERNEL_VERSION: $KERNEL_VERSION"
echo "FFMPEG_VERSION: $FFMPEG_VERSION"
echo "======================"

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
        encode_speed_num=$(echo "$encode_speed" | sed 's/^ *//;s/ *$//;s/x$//' 2>/dev/null || echo "0")
        realtime_speed=$(echo "$realtime_speed" | sed 's/^ *//;s/ *$//')
        test_duration=$(echo "$test_duration" | sed 's/^ *//;s/ *$//')
        
        # 确定性能等级 - 基于编码速度而不是实时倍数
        speed_class="speed-fair"
        badge_class="badge-fair"
        badge_text="一般"
        
        if [ -n "$encode_speed_num" ] && [ "$encode_speed_num" != "N/A" ]; then
            if [ "$(echo "$encode_speed_num >= 5" 2>/dev/null | bc 2>/dev/null || echo "0")" = "1" ]; then
                speed_class="speed-excellent"
                badge_class="badge-excellent"
                badge_text="优秀"
            elif [ "$(echo "$encode_speed_num >= 2" 2>/dev/null | bc 2>/dev/null || echo "0")" = "1" ]; then
                speed_class="speed-good"
                badge_class="badge-good"
                badge_text="良好"
            elif [ "$(echo "$encode_speed_num >= 1" 2>/dev/null | bc 2>/dev/null || echo "0")" = "1" ]; then
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
            <td class=\"${speed_class}\">${encode_speed}</td>
            <td>${realtime_speed}</td>
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
            max-width: 1400px;
            margin: 0 auto;
            background: white;
            border-radius: 12px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        
        .header {
            background: linear-gradient(90deg, #4f46e5, #7c3aed);
            color: white;
            padding: 20px 30px;
            text-align: center;
        }
        
        .header h1 {
            font-size: 2rem;
            margin-bottom: 8px;
        }
        
        .header p {
            font-size: 0.9rem;
            opacity: 0.9;
        }
        
        .summary-cards {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
            gap: 20px;
            padding: 25px;
        }
        
        .card {
            background: white;
            border-radius: 10px;
            padding: 20px;
            box-shadow: 0 3px 10px rgba(0,0,0,0.08);
            border-left: 4px solid #4f46e5;
            height: auto;
            min-height: 0;
        }
        
        /* 系统配置卡片特殊样式 */
        .system-card {
            grid-column: span 2;
            border-left-color: #4f46e5;
            background: linear-gradient(135deg, #f5f3ff, #ede9fe);
        }
        
        .hardware-section, .software-section {
            margin-bottom: 15px;
            padding: 12px;
            background: rgba(255, 255, 255, 0.5);
            border-radius: 8px;
            border: 1px solid #e2e8f0;
        }
        
        .hardware-section h4, .software-section h4 {
            color: #475569;
            font-size: 0.9rem;
            font-weight: 600;
            margin-bottom: 10px;
            display: flex;
            align-items: center;
            gap: 8px;
        }
        
        .hardware-section h4 i, .software-section h4 i {
            color: #4f46e5;
            font-size: 1rem;
        }
        
        .info-grid {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 10px;
        }
        
        .info-item {
            display: flex;
            flex-direction: column;
            padding: 8px;
            background: white;
            border-radius: 6px;
            border-left: 3px solid #4f46e5;
        }
        
        .info-label {
            font-size: 0.8rem;
            color: #64748b;
            font-weight: 500;
            margin-bottom: 4px;
        }
        
        .info-value {
            font-size: 0.9rem;
            color: #1e293b;
            font-weight: 500;
            line-height: 1.4;
            word-break: break-word;
        }
        
        .card.best {
            border-left-color: #10b981;
            background: linear-gradient(135deg, #f0fdf4, #dcfce7);
        }
        
        .card.worst {
            border-left-color: #ef4444;
            background: linear-gradient(135deg, #fef2f2, #fee2e2);
        }
        
        .card h3 {
            color: #4f46e5;
            margin-bottom: 15px;
            font-size: 0.95rem;
            font-weight: 600;
            display: flex;
            align-items: center;
            gap: 8px;
        }
        
        .card h3 i {
            font-size: 1.1rem;
        }
        
        .card .value {
            font-size: 1.6rem;
            font-weight: bold;
            color: #1e293b;
            margin-bottom: 5px;
        }
        
        .card.best .value {
            color: #10b981;
        }
        
        .card.worst .value {
            color: #ef4444;
        }
        
        .card .label {
            color: #64748b;
            font-size: 0.85rem;
            line-height: 1.4;
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
        
        /* 响应式调整 */
        @media (max-width: 1024px) {
            .system-card {
                grid-column: span 1;
            }
            
            .info-grid {
                grid-template-columns: 1fr;
            }
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
            <div class="card system-card">
                <h3><i>⚙️</i> 系统配置详情</h3>
                
                <div class="hardware-section">
                    <h4><i>💻</i> 硬件信息</h4>
                    <div class="info-grid">
                        <div class="info-item">
                            <span class="info-label">CPU架构</span>
                            <span class="info-value">$CPU_ARCH_DISPLAY</span>
                        </div>
                        <div class="info-item">
                            <span class="info-label">CPU型号</span>
                            <span class="info-value">$CPU_MODEL</span>
                        </div>
                        <div class="info-item">
                            <span class="info-label">内存配置</span>
                            <span class="info-value">$MEMORY_DISPLAY</span>
                        </div>
                    </div>
                </div>
                
                <div class="software-section">
                    <h4><i>🖥️</i> 软件信息</h4>
                    <div class="info-grid">
                        <div class="info-item">
                            <span class="info-label">操作系统</span>
                            <span class="info-value">$OS_DISPLAY</span>
                        </div>
                        <div class="info-item">
                            <span class="info-label">内核版本</span>
                            <span class="info-value">$KERNEL_VERSION</span>
                        </div>
                        <div class="info-item">
                            <span class="info-label">FFmpeg版本</span>
                            <span class="info-value">$FFMPEG_VERSION</span>
                        </div>
                    </div>
                </div>
            </div>
            
            <div class="card">
                <h3><i>📊</i> 测试统计</h3>
                <div class="value">$TEST_COUNT</div>
                <div class="label">测试数量</div>
                <div class="value">${TOTAL_DURATION}s</div>
                <div class="label">总测试时长</div>
            </div>

            <div class="card best">
                <h3><i>🏆</i> 最佳性能</h3>
                <div class="value">${BEST_SPEED}x</div>
                <div class="label">${BEST_NAME}</div>
            </div>

            <div class="card worst">
                <h3><i>⚠️</i> 性能瓶颈</h3>
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
            <p>📊 FFmpeg性能测试报告 | 版本: 3.1 (修复版)</p>
            <p>🔧 FFmpeg版本: ${FFMPEG_VERSION}</p>
            <p>📁 目录: $(pwd)</p>
        </div>
    </div>
</body>
</html>
HTML_EOF

echo ""
echo "✅ HTML报告已生成: $(pwd)/$OUTPUT_FILE"
echo "📊 包含 $ROW_COUNT 个测试结果"
echo ""
echo "💡 查看报告的方法:"
echo " 1. 在当前目录启动HTTP服务器: python3 -m http.server 8000"
echo " 2. 在浏览器中访问: http://localhost:8000/$OUTPUT_FILE"
echo ""
echo "🔄 完成!"
