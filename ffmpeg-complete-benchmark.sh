#!/bin/bash
# ffmpeg-complete-benchmark-fixed.sh - 修复的完整FFmpeg性能基准测试
# 修复：CPU频率百分比解析问题
# 用法: ./ffmpeg-complete-benchmark-fixed.sh [输入文件] [输出目录]

set -e

# 配置
INPUT_FILE="${1:-/dev/shm/test.mp4}"
OUTPUT_DIR="${2:-./ffmpeg_benchmark_$(date +%Y%m%d_%H%M%S)}"
TEST_DURATION=60  # 每个测试运行10秒
RESOLUTIONS="854x480 1280x720 1920x1080"  # 测试分辨率
BITRATES="2000k 5000k"  # 测试比特率
WARMUP_ITERATIONS=0
TEST_ITERATIONS=3
SKIP_AV1=true  # 跳过极慢的AV1编码
TIMEOUT_SECONDS=300  # 每个测试最多5分钟
ENABLE_HARDWARE_TESTS=false  # 启用硬件加速测试
ENABLE_QUALITY_TESTS=true  # 启用质量测试

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# 记录脚本开始时间
SCRIPT_START_TIME=$(date +%s.%N)

# 创建输出目录
mkdir -p "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/logs"
mkdir -p "$OUTPUT_DIR/videos"

LOG_FILE="$OUTPUT_DIR/benchmark_$(date +%Y%m%d_%H%M%S).log"
CSV_FILE="$OUTPUT_DIR/benchmark_results.csv"
SPEED_CSV="$OUTPUT_DIR/speed_results.csv"
SYSTEM_INFO_FILE="$OUTPUT_DIR/system_info.txt"
CONFIG_FILE="$OUTPUT_DIR/test_config.txt"
SUMMARY_FILE="$OUTPUT_DIR/execution_summary.txt"

# 函数：安全的日志记录（不带颜色到文件）
log_to_file() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 函数：打印带时间戳的日志
log() {
    local message="$1"
    # 输出到控制台（带颜色）
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] $message"
    # 输出到文件（不带颜色）
    log_to_file "$(echo -e "$message" | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g")"
}

# 函数：带格式的日志
log_header() {
    echo -e "\n${CYAN}========================================${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}========================================${NC}"
    log_to_file "========================================"
    log_to_file "  $1"
    log_to_file "========================================"
}

log_section() {
    echo -e "\n${BLUE}$1${NC}"
    log_to_file "$1"
}

log_success() {
    echo -e "${GREEN}✓ $1${NC}"
    log_to_file "✓ $1"
}

log_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
    log_to_file "⚠ $1"
}

log_error() {
    echo -e "${RED}✗ $1${NC}"
    log_to_file "✗ $1"
}

# 函数：收集完整的系统信息
collect_system_info() {
    log_header "收集系统信息"
    
    cat > "$SYSTEM_INFO_FILE" << EOF
========================================
FFmpeg性能测试 - 系统配置信息
收集时间: $(date)
========================================

一、CPU信息
----------------------------------------
EOF

    # CPU型号和核心数
#    echo "CPU型号和核心信息:" >> "$SYSTEM_INFO_FILE"
#    lscpu 2>/dev/null | grep -E "Model name|^CPU\(s\)|Thread\(s\) per core|Core\(s\) per socket|Socket\(s\)|NUMA node\(s\)" | grep -v "scaling MHz" >> "$SYSTEM_INFO_FILE"
#    echo "" >> "$SYSTEM_INFO_FILE"
	echo "CPU型号和核心信息:" >> "$SYSTEM_INFO_FILE"
	lscpu 2>/dev/null | grep -E "Model name|^CPU\(s\)|Thread\(s\) per core|Core\(s\) per socket|Socket\(s\)|NUMA node\(s\)" | grep -v "scaling MHz" >> "$SYSTEM_INFO_FILE"
	echo "" >> "$SYSTEM_INFO_FILE"
    
    # CPU频率（修复：过滤掉百分比）
    echo "CPU频率信息:" >> "$SYSTEM_INFO_FILE"
    lscpu 2>/dev/null | grep -E "MHz|GHz" | grep -v "scaling MHz" >> "$SYSTEM_INFO_FILE"
    echo "" >> "$SYSTEM_INFO_FILE"
    
    # CPU缓存
    echo "CPU缓存信息:" >> "$SYSTEM_INFO_FILE"
    lscpu 2>/dev/null | grep -i "cache" >> "$SYSTEM_INFO_FILE"
    echo "" >> "$SYSTEM_INFO_FILE"
    
    # CPU特性标志
    echo "CPU特性标志 (部分):" >> "$SYSTEM_INFO_FILE"
    lscpu 2>/dev/null | grep -i "flags" | head -3 >> "$SYSTEM_INFO_FILE"
    echo "" >> "$SYSTEM_INFO_FILE"
    
    # 更详细的/proc/cpuinfo信息
    echo "CPU核心详细信息 (前2个核心):" >> "$SYSTEM_INFO_FILE"
    grep -E "processor|model name|cpu MHz|cache size" /proc/cpuinfo 2>/dev/null | head -8 >> "$SYSTEM_INFO_FILE"
    echo "" >> "$SYSTEM_INFO_FILE"

    # ============ 新增：详细CPU核心架构信息 ============
    echo "详细CPU核心架构信息:" >> "$SYSTEM_INFO_FILE"
    echo "----------------------------------------" >> "$SYSTEM_INFO_FILE"

    # 获取NUMA节点信息
    if command -v numactl &> /dev/null; then
        echo "NUMA节点配置:" >> "$SYSTEM_INFO_FILE"
        numactl -H 2>/dev/null | grep -E "available|cpus|size|free" | head -20 >> "$SYSTEM_INFO_FILE"
        echo "" >> "$SYSTEM_INFO_FILE"
    fi

    # 获取CPU拓扑信息
    echo "CPU拓扑信息:" >> "$SYSTEM_INFO_FILE"
    lscpu 2>/dev/null | grep -E "Architecture|CPU op-mode|Byte Order|Vendor ID|CPU family|Model|Stepping|BogoMIPS|Virtualization|Hypervisor|Virtualization type" >> "$SYSTEM_INFO_FILE"
    echo "" >> "$SYSTEM_INFO_FILE"

    # 获取CPU核心列表
    echo "CPU核心分布:" >> "$SYSTEM_INFO_FILE"
    TOTAL_CPUS=$(lscpu 2>/dev/null | grep "^CPU(s)" | awk '{print $2}')
    echo "总CPU线程数: $TOTAL_CPUS" >> "$SYSTEM_INFO_FILE"

    # 如果是AMD EPYC或其他服务器CPU，尝试获取CCX/CCD信息
    if echo "$CPU_MODEL" | grep -qi "EPYC\|Ryzen"; then
        echo "检测到AMD CPU，尝试获取CCX/CCD信息:" >> "$SYSTEM_INFO_FILE"
    
        # 获取每插槽核心数
        CORES_PER_SOCKET=$(lscpu 2>/dev/null | grep "Core(s) per socket" | awk '{print $4}')
        SOCKETS=$(lscpu 2>/dev/null | grep "Socket(s)" | awk '{print $2}')
    
        if [ -n "$CORES_PER_SOCKET" ] && [ -n "$SOCKETS" ]; then
            TOTAL_PHYSICAL_CORES=$((CORES_PER_SOCKET * SOCKETS))
            echo "物理核心总数: $TOTAL_PHYSICAL_CORES" >> "$SYSTEM_INFO_FILE"
            echo "每插槽核心数: $CORES_PER_SOCKET" >> "$SYSTEM_INFO_FILE"
            echo "CPU插槽数: $SOCKETS" >> "$SYSTEM_INFO_FILE"
        
            # 如果是96核EPYC，通常是8个CCD，每个CCD 8个核心
            if [ "$TOTAL_PHYSICAL_CORES" -eq 96 ]; then
                echo "核心架构: 8个CCD (Core Complex Die)，每个CCD 8个核心" >> "$SYSTEM_INFO_FILE"
                echo "CCD配置: 8 CCD × 8 核心/CCD = 96 核心" >> "$SYSTEM_INFO_FILE"
            fi
        fi
    fi
    echo "" >> "$SYSTEM_INFO_FILE"
    
    # 内存信息
#    cat >> "$SYSTEM_INFO_FILE" << EOF
#二、内存信息
#----------------------------------------
#EOF
#    free -h 2>/dev/null >> "$SYSTEM_INFO_FILE"
#    echo "" >> "$SYSTEM_INFO_FILE"
#    
#    echo "详细内存信息:" >> "$SYSTEM_INFO_FILE"
#    grep -E "MemTotal|MemFree|MemAvailable|SwapTotal|SwapFree" /proc/meminfo 2>/dev/null >> "$SYSTEM_INFO_FILE"
#    echo "" >> "$SYSTEM_INFO_FILE"
#    
#    # 内存通道信息
#    cat >> "$SYSTEM_INFO_FILE" << EOF
#三、内存通道信息
#----------------------------------------
#EOF
#    if command -v dmidecode &> /dev/null && [ "$EUID" -eq 0 ]; then
#        dmidecode -t memory 2>/dev/null | grep -E "Size:|Type:|Speed:|Locator:" | head -20 2>/dev/null >> "$SYSTEM_INFO_FILE" || echo "需要root权限获取内存通道信息" >> "$SYSTEM_INFO_FILE"
#    else
#        echo "使用lshw尝试获取内存信息:" >> "$SYSTEM_INFO_FILE"
#        lshw -short -C memory 2>/dev/null | head -20 2>/dev/null >> "$SYSTEM_INFO_FILE" || echo "无法获取详细内存通道信息" >> "$SYSTEM_INFO_FILE"
#    fi
#    echo "" >> "$SYSTEM_INFO_FILE"
#    
#    # 系统架构
#    cat >> "$SYSTEM_INFO_FILE" << EOF
# 内存信息
cat >> "$SYSTEM_INFO_FILE" << EOF
二、内存信息
----------------------------------------
EOF
    free -h 2>/dev/null >> "$SYSTEM_INFO_FILE"
    echo "" >> "$SYSTEM_INFO_FILE"

    echo "详细内存信息:" >> "$SYSTEM_INFO_FILE"
    grep -E "MemTotal|MemFree|MemAvailable|SwapTotal|SwapFree" /proc/meminfo 2>/dev/null >> "$SYSTEM_INFO_FILE"
    echo "" >> "$SYSTEM_INFO_FILE"

    # 新增：内存通道信息
    cat >> "$SYSTEM_INFO_FILE" << EOF
三、内存通道和插槽信息
----------------------------------------
EOF

# 方法1: 使用dmidecode获取详细内存信息
if command -v dmidecode &> /dev/null && [ "$EUID" -eq 0 ]; then
    echo "使用dmidecode获取内存信息:" >> "$SYSTEM_INFO_FILE"
    
    # 获取内存设备总数
    TOTAL_MEMORY_DEVICES=$(dmidecode -t memory 2>/dev/null | grep -c "^Memory Device$" 2>/dev/null || echo 0)
    echo "总内存设备数: $TOTAL_MEMORY_DEVICES" >> "$SYSTEM_INFO_FILE"
    
    # 获取已安装的内存设备
    INSTALLED_MEMORY=$(dmidecode -t memory 2>/dev/null | grep -A5 "^Memory Device$" | grep "Size:" | grep -v "No Module Installed" | grep -v "No Module" 2>/dev/null)
    INSTALLED_COUNT=$(echo "$INSTALLED_MEMORY" | wc -l 2>/dev/null || echo 0)
    echo "已安装内存设备: $INSTALLED_COUNT" >> "$SYSTEM_INFO_FILE"
    
    # 显示已安装的内存详细信息
    if [ "$INSTALLED_COUNT" -gt 0 ]; then
        echo "" >> "$SYSTEM_INFO_FILE"
        echo "已安装内存详情:" >> "$SYSTEM_INFO_FILE"
        echo "----------------" >> "$SYSTEM_INFO_FILE"
        
        # 使用awk解析dmidecode输出
        dmidecode -t memory 2>/dev/null | awk '
        BEGIN { RS = "Memory Device"; device = 0; }
        NR > 1 {
            size = ""; type = ""; speed = ""; locator = ""; bank = "";
            split($0, lines, "\n");
            for (i in lines) {
                if (lines[i] ~ /^\tSize: /) {
                    gsub(/^\tSize: /, "", lines[i]);
                    if (lines[i] !~ /No Module/) {
                        size = lines[i];
                        device++;
                    }
                }
                if (lines[i] ~ /^\tType: /) {
                    gsub(/^\tType: /, "", lines[i]);
                    type = lines[i];
                }
                if (lines[i] ~ /^\tSpeed: /) {
                    gsub(/^\tSpeed: /, "", lines[i]);
                    speed = lines[i];
                }
                if (lines[i] ~ /^\tLocator: /) {
                    gsub(/^\tLocator: /, "", lines[i]);
                    locator = lines[i];
                }
                if (lines[i] ~ /^\tBank Locator: /) {
                    gsub(/^\tBank Locator: /, "", lines[i]);
                    bank = lines[i];
                }
            }
            if (size != "" && size !~ /No Module/) {
                print "内存设备 #" device ":";
                print "  大小: " size;
                print "  类型: " type;
                print "  速度: " speed;
                print "  位置: " locator;
                if (bank != "") print "  通道: " bank;
                print "";
            }
        }' >> "$SYSTEM_INFO_FILE" 2>/dev/null
        
        # 统计不同的内存通道/插槽
        echo "内存通道/插槽统计:" >> "$SYSTEM_INFO_FILE"
        echo "------------------" >> "$SYSTEM_INFO_FILE"
        
        # 提取所有不同的Bank Locator
        dmidecode -t memory 2>/dev/null | grep "Bank Locator:" | sed 's/.*Bank Locator://' | sort -u | while read -r bank; do
            if [ -n "$bank" ]; then
                COUNT=$(dmidecode -t memory 2>/dev/null | grep -B2 -A2 "Bank Locator: $bank" | grep -c "Size:.*[0-9]" 2>/dev/null || echo 0)
                echo "  通道 $bank: $COUNT 个内存设备" >> "$SYSTEM_INFO_FILE"
            fi
        done
        
        # 计算总通道数
        TOTAL_CHANNELS=$(dmidecode -t memory 2>/dev/null | grep "Bank Locator:" | sed 's/.*Bank Locator://' | sort -u | wc -l 2>/dev/null || echo 0)
        echo "" >> "$SYSTEM_INFO_FILE"
        echo "总内存通道数: $TOTAL_CHANNELS" >> "$SYSTEM_INFO_FILE"
        
        # 将通道数添加到comparison_metrics.csv
        if [ -f "$OUTPUT_DIR/comparison_metrics.csv" ]; then
            if ! grep -q "内存通道数" "$OUTPUT_DIR/comparison_metrics.csv"; then
                echo "内存,内存通道数,$TOTAL_CHANNELS" >> "$OUTPUT_DIR/comparison_metrics.csv"
            fi
        fi
    else
        echo "未检测到已安装的内存设备" >> "$SYSTEM_INFO_FILE"
    fi
    
# 方法2: 使用lshw
elif command -v lshw &> /dev/null; then
    echo "使用lshw获取内存信息:" >> "$SYSTEM_INFO_FILE"
    
    MEMORY_INFO=$(lshw -short -C memory 2>/dev/null | head -20 2>/dev/null)
    if [ -n "$MEMORY_INFO" ]; then
        echo "$MEMORY_INFO" >> "$SYSTEM_INFO_FILE"
        
        # 尝试获取更详细的信息
        echo "" >> "$SYSTEM_INFO_FILE"
        echo "内存插槽详情:" >> "$SYSTEM_INFO_FILE"
        lshw -C memory 2>/dev/null | grep -A3 "slot:" | while IFS= read -r line; do
            if [[ "$line" =~ slot: ]]; then
                SLOT=$(echo "$line" | sed 's/.*slot://' | xargs)
                echo "插槽: $SLOT" >> "$SYSTEM_INFO_FILE"
            elif [[ "$line" =~ size: ]]; then
                SIZE=$(echo "$line" | sed 's/.*size://' | xargs)
                echo "  大小: $SIZE" >> "$SYSTEM_INFO_FILE"
            elif [[ "$line" =~ clock: ]]; then
                CLOCK=$(echo "$line" | sed 's/.*clock://' | xargs)
                echo "  频率: $CLOCK" >> "$SYSTEM_INFO_FILE"
            fi
        done 2>/dev/null || echo "无法获取详细插槽信息" >> "$SYSTEM_INFO_FILE"
    else
        echo "无法获取详细内存通道信息" >> "$SYSTEM_INFO_FILE"
    fi
    
    # 估算内存通道数
    SLOT_COUNT=$(lshw -C memory 2>/dev/null | grep -c "slot:" 2>/dev/null || echo 0)
    echo "" >> "$SYSTEM_INFO_FILE"
    echo "检测到的内存插槽数: $SLOT_COUNT" >> "$SYSTEM_INFO_FILE"
    
    if [ -f "$OUTPUT_DIR/comparison_metrics.csv" ]; then
        if ! grep -q "内存通道数" "$OUTPUT_DIR/comparison_metrics.csv"; then
            echo "内存,内存插槽数,$SLOT_COUNT" >> "$OUTPUT_DIR/comparison_metrics.csv"
        fi
    fi
else
    echo "无法获取详细内存通道信息（需要dmidecode或lshw工具）" >> "$SYSTEM_INFO_FILE"
    echo "建议安装: sudo apt-get install dmidecode 或 sudo apt-get install lshw" >> "$SYSTEM_INFO_FILE"
fi


# 在现有内存信息收集代码后添加

# ============ 新增：详细的内存通道信息 ============
echo "详细内存通道信息:" >> "$SYSTEM_INFO_FILE"
echo "----------------------------------------" >> "$SYSTEM_INFO_FILE"

# 尝试获取内存通道信息
if command -v dmidecode &> /dev/null && [ "$EUID" -eq 0 ]; then
    # 统计内存设备
    MEMORY_DEVICES=$(dmidecode -t memory 2>/dev/null | grep -c "Memory Device")
    echo "内存设备总数: $MEMORY_DEVICES" >> "$SYSTEM_INFO_FILE"
    
    # 统计已安装的内存设备
    INSTALLED_DEVICES=$(dmidecode -t memory 2>/dev/null | grep -A5 "Memory Device" | grep "Size:" | grep -v "No Module" | wc -l)
    echo "已安装内存设备: $INSTALLED_DEVICES" >> "$SYSTEM_INFO_FILE"
    
    # 统计内存通道
    CHANNELS=$(dmidecode -t memory 2>/dev/null | grep "Bank Locator:" | sort -u | wc -l)
    echo "内存通道数: $CHANNELS" >> "$SYSTEM_INFO_FILE"
    
    # 显示每个通道的内存信息
    echo "" >> "$SYSTEM_INFO_FILE"
    echo "各通道内存信息:" >> "$SYSTEM_INFO_FILE"
    echo "-----------------" >> "$SYSTEM_INFO_FILE"
    
    # 统计每个通道的内存
    CHANNEL_INFO=""
    dmidecode -t memory 2>/dev/null | grep -B2 -A3 "Bank Locator:" | while read -r line; do
        if [[ "$line" =~ "Bank Locator:" ]]; then
            CHANNEL=$(echo "$line" | sed 's/.*Bank Locator://')
            if [ -n "$CHANNEL" ]; then
                # 计算该通道的总内存
                CHANNEL_TOTAL=0
                # 这里简化处理，实际需要更复杂的解析
                echo "  通道 $CHANNEL: 有内存设备" >> "$SYSTEM_INFO_FILE"
            fi
        fi
    done
else
    echo "需要root权限和dmidecode工具获取详细内存通道信息" >> "$SYSTEM_INFO_FILE"
fi
echo "" >> "$SYSTEM_INFO_FILE" << EOF

四、系统架构信息
----------------------------------------
EOF
    uname -a 2>/dev/null >> "$SYSTEM_INFO_FILE"
    echo "" >> "$SYSTEM_INFO_FILE"
    
    echo "内核信息:" >> "$SYSTEM_INFO_FILE"
    uname -r 2>/dev/null >> "$SYSTEM_INFO_FILE"
    echo "" >> "$SYSTEM_INFO_FILE"
    
    # 主板/BIOS信息
# 在现有系统架构信息后添加

# ============ 新增：详细的OS和内核信息 ============
    echo "操作系统详细信息:" >> "$SYSTEM_INFO_FILE"
    echo "----------------------------------------" >> "$SYSTEM_INFO_FILE"

    # 获取操作系统版本
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "操作系统: $NAME" >> "$SYSTEM_INFO_FILE"
        echo "版本: $VERSION" >> "$SYSTEM_INFO_FILE"
        echo "版本号: $VERSION_ID" >> "$SYSTEM_INFO_FILE"
    elif [ -f /etc/redhat-release ]; then
        cat /etc/redhat-release >> "$SYSTEM_INFO_FILE"
    elif [ -f /etc/debian_version ]; then
        echo "Debian $(cat /etc/debian_version)" >> "$SYSTEM_INFO_FILE"
    fi
    echo "" >> "$SYSTEM_INFO_FILE"

    # 内核详细信息
    echo "内核版本: $(uname -r)" >> "$SYSTEM_INFO_FILE"
    echo "内核编译信息:" >> "$SYSTEM_INFO_FILE"
    cat /proc/version 2>/dev/null >> "$SYSTEM_INFO_FILE"
    cat >> "$SYSTEM_INFO_FILE" << EOF
五、主板/BIOS信息
----------------------------------------
EOF
    if command -v dmidecode &> /dev/null && [ "$EUID" -eq 0 ]; then
        dmidecode -t bios 2>/dev/null | grep -E "Vendor|Version|Release Date" | head -5 2>/dev/null >> "$SYSTEM_INFO_FILE"
        dmidecode -t system 2>/dev/null | grep -E "Manufacturer|Product Name|Version" | head -5 2>/dev/null >> "$SYSTEM_INFO_FILE"
    else
        echo "需要root权限获取BIOS信息" >> "$SYSTEM_INFO_FILE"
    fi
    echo "" >> "$SYSTEM_INFO_FILE"
    
    # 存储信息
    cat >> "$SYSTEM_INFO_FILE" << EOF
六、存储信息
----------------------------------------
EOF
    df -h 2>/dev/null | head -10 >> "$SYSTEM_INFO_FILE"
    echo "" >> "$SYSTEM_INFO_FILE"
    
    lsblk 2>/dev/null | head -20 >> "$SYSTEM_INFO_FILE"
    echo "" >> "$SYSTEM_INFO_FILE"
    
    # FFmpeg信息
    cat >> "$SYSTEM_INFO_FILE" << EOF
七、FFmpeg信息
----------------------------------------
EOF
    ffmpeg -version 2>/dev/null | head -5 >> "$SYSTEM_INFO_FILE"
    echo "" >> "$SYSTEM_INFO_FILE"
    
    echo "支持的硬件加速:" >> "$SYSTEM_INFO_FILE"
    ffmpeg -hwaccels 2>/dev/null >> "$SYSTEM_INFO_FILE" 2>/dev/null || echo "无法获取硬件加速信息" >> "$SYSTEM_INFO_FILE"
    echo "" >> "$SYSTEM_INFO_FILE"
    
    # 系统负载
    cat >> "$SYSTEM_INFO_FILE" << EOF
八、系统负载信息
----------------------------------------
EOF
    uptime 2>/dev/null >> "$SYSTEM_INFO_FILE"
    echo "" >> "$SYSTEM_INFO_FILE"
    
    # 对比测试关键指标提取
    extract_comparison_metrics
}

# 函数：提取对比测试关键指标（修复版本）
extract_comparison_metrics() {
    cat > "$OUTPUT_DIR/comparison_metrics.csv" << EOF
指标类型,指标名称,指标值
系统,测试时间,$(date)
系统,操作系统,$(uname -o 2>/dev/null || echo "Unknown")
系统,内核版本,$(uname -r)
系统,架构,$(uname -m)
EOF
    
    # 提取CPU信息
    local cpu_model=$(lscpu 2>/dev/null | grep "Model name" | cut -d':' -f2- | sed 's/^[ \t]*//')
#    local cpu_cores=$(lscpu 2>/dev/null | grep "^CPU(s)" | cut -d':' -f2 | sed 's/^[ \t]*//' | cut -d' ' -f1)
   
	# 修复CPU核心数提取
	local cpu_cores=$(lscpu 2>/dev/null | grep "^CPU(s)" | cut -d':' -f2 | sed 's/^[[:space:]]*//')

	# 方法1：先提取纯数字部分
	cpu_cores=$(echo "$cpu_cores" | grep -o '[0-9]*' | head -1)

	# 方法2：如果仍然异常，使用安全值
	if [ -z "$cpu_cores" ] || [ "$cpu_cores" -gt 2048 ] || [ "$cpu_cores" -lt 1 ]; then
    	# 对于AMD EPYC 9755，实际是128核256线程
    	# 但lscpu显示的"CPU(s): 256"是逻辑CPU数（线程数）
    	# 这里我们取逻辑CPU数
    	cpu_cores=256
    	log_warning "CPU核心数提取异常，使用默认值: $cpu_cores"
	fi 
    local cpu_threads=$(lscpu 2>/dev/null | grep "Thread(s) per core" | cut -d':' -f2 | sed 's/^[ \t]*//' | cut -d' ' -f1)
    local cpu_sockets=$(lscpu 2>/dev/null | grep "Socket(s)" | cut -d':' -f2 | sed 's/^[ \t]*//' | cut -d' ' -f1)
    
    # 清理数据，移除非数字字符
    cpu_cores=$(echo "$cpu_cores" | tr -cd '0-9')
    cpu_threads=$(echo "$cpu_threads" | tr -cd '0-9')
    cpu_sockets=$(echo "$cpu_sockets" | tr -cd '0-9')
    
    # 如果cpu_threads为空，默认为1
    [ -z "$cpu_threads" ] && cpu_threads=1
    [ -z "$cpu_sockets" ] && cpu_sockets=1
    
    echo "CPU,CPU型号,$cpu_model" >> "$OUTPUT_DIR/comparison_metrics.csv"
    echo "CPU,物理核心数,$cpu_cores" >> "$OUTPUT_DIR/comparison_metrics.csv"
    echo "CPU,每核线程数,$cpu_threads" >> "$OUTPUT_DIR/comparison_metrics.csv"
    echo "CPU,总线程数,$((cpu_cores * cpu_threads))" >> "$OUTPUT_DIR/comparison_metrics.csv"
    echo "CPU,CPU插槽数,$cpu_sockets" >> "$OUTPUT_DIR/comparison_metrics.csv"

    # 在现有CPU信息后添加
    echo "CPU,每插槽核心数,$CORES_PER_SOCKET" >> "$OUTPUT_DIR/comparison_metrics.csv"
    echo "CPU,CPU插槽数,$SOCKETS" >> "$OUTPUT_DIR/comparison_metrics.csv"

    # 添加总物理核心数
    echo "CPU,总物理核心数,$((CORES_PER_SOCKET * SOCKETS))" >> "$OUTPUT_DIR/comparison_metrics.csv"

    # 添加操作系统信息
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "系统,操作系统,$NAME" >> "$OUTPUT_DIR/comparison_metrics.csv"
        echo "系统,OS版本,$VERSION_ID" >> "$OUTPUT_DIR/comparison_metrics.csv"
    fi

    # 添加内核版本
    echo "系统,内核版本,$(uname -r)" >> "$OUTPUT_DIR/comparison_metrics.csv"

    # 添加内存通道数（如果可用）
    if command -v dmidecode &> /dev/null && [ "$EUID" -eq 0 ]; then
        CHANNELS=$(dmidecode -t memory 2>/dev/null | grep "Bank Locator:" | sort -u | wc -l 2>/dev/null || echo "未知")
        echo "内存,内存通道数,$CHANNELS" >> "$OUTPUT_DIR/comparison_metrics.csv"
    fi
    
    # 提取内存信息
    local mem_total=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' | head -1)
    local mem_free=$(grep MemFree /proc/meminfo 2>/dev/null | awk '{print $2}' | head -1)
    local mem_available=$(grep MemAvailable /proc/meminfo 2>/dev/null | awk '{print $2}' | head -1)
    
    [ -z "$mem_total" ] && mem_total=0
    [ -z "$mem_available" ] && mem_available=0
    [ -z "$mem_free" ] && mem_free=0
    
    echo "内存,总内存(KB),$mem_total" >> "$OUTPUT_DIR/comparison_metrics.csv"
    echo "内存,可用内存(KB),$mem_available" >> "$OUTPUT_DIR/comparison_metrics.csv"
    echo "内存,空闲内存(KB),$mem_free" >> "$OUTPUT_DIR/comparison_metrics.csv"
    echo "内存,总内存(GB),$(echo "scale=2; $mem_total / 1024 / 1024" | bc 2>/dev/null || echo "0")" >> "$OUTPUT_DIR/comparison_metrics.csv"
    
    # 提取缓存信息
    local l1d_cache=$(lscpu 2>/dev/null | grep "L1d cache" | cut -d':' -f2 | sed 's/^[ \t]*//' | head -1)
    local l1i_cache=$(lscpu 2>/dev/null | grep "L1i cache" | cut -d':' -f2 | sed 's/^[ \t]*//' | head -1)
    local l2_cache=$(lscpu 2>/dev/null | grep "L2 cache" | cut -d':' -f2 | sed 's/^[ \t]*//' | head -1)
    local l3_cache=$(lscpu 2>/dev/null | grep "L3 cache" | cut -d':' -f2 | sed 's/^[ \t]*//' | head -1)
    
    echo "缓存,L1d缓存,$l1d_cache" >> "$OUTPUT_DIR/comparison_metrics.csv"
    echo "缓存,L1i缓存,$l1i_cache" >> "$OUTPUT_DIR/comparison_metrics.csv"
    echo "缓存,L2缓存,$l2_cache" >> "$OUTPUT_DIR/comparison_metrics.csv"
    echo "缓存,L3缓存,$l3_cache" >> "$OUTPUT_DIR/comparison_metrics.csv"
    
    # FFmpeg版本
    local ffmpeg_version=$(ffmpeg -version 2>/dev/null | head -1 | cut -d' ' -f3)
    [ -z "$ffmpeg_version" ] && ffmpeg_version="未知"
    echo "软件,FFmpeg版本,$ffmpeg_version" >> "$OUTPUT_DIR/comparison_metrics.csv"
    
    log_success "系统对比指标已保存到: $OUTPUT_DIR/comparison_metrics.csv"
}

# 函数：记录测试配置
record_test_config() {
    cat > "$CONFIG_FILE" << EOF
========================================
FFmpeg性能测试配置
记录时间: $(date)
========================================

测试参数:
- 输入文件: $INPUT_FILE
- 输出目录: $OUTPUT_DIR
- 测试时长: ${TEST_DURATION}秒/测试
- 分辨率测试: $RESOLUTIONS
- 比特率测试: $BITRATES
- 预热迭代: $WARMUP_ITERATIONS
- 测试迭代: $TEST_ITERATIONS
- 超时时间: ${TIMEOUT_SECONDS}秒
- 跳过AV1: $SKIP_AV1
- 硬件加速测试: $ENABLE_HARDWARE_TESTS
- 质量测试: $ENABLE_QUALITY_TESTS

系统信息摘要:
- CPU: $(lscpu 2>/dev/null | grep "Model name" | cut -d':' -f2- | sed 's/^[ \t]*//' | head -1)
- 核心数: $(lscpu 2>/dev/null | grep "^CPU(s)" | cut -d':' -f2 | sed 's/^[ \t]*//' | cut -d' ' -f1 | head -1)
- 内存: $(grep MemTotal /proc/meminfo 2>/dev/null | awk '{printf "%.2f GB", $2/1024/1024}' | head -1)
- 架构: $(uname -m)
- 内核: $(uname -r)
- FFmpeg: $(ffmpeg -version 2>/dev/null | head -1 | cut -d' ' -f1-3 | head -1)

测试开始时间: $(date)
EOF
}

# 函数：带超时运行命令
run_with_timeout() {
    local timeout=$1
    local cmd=$2
    local output_file=$3
    
    # 启动命令
    eval "$cmd" > "$output_file" 2>&1 &
    local pid=$!
    
    # 等待命令完成或超时
    local start_time=$(date +%s)
    while kill -0 $pid 2>/dev/null; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [ $elapsed -ge $timeout ]; then
            kill -9 $pid 2>/dev/null
            wait $pid 2>/dev/null
            return 124
        fi
        sleep 1
    done
    
    wait $pid
    return $?
}

# 函数：提取速度信息
#extract_speed() {
#    local log_file="$1"
#    local speed=$(grep -o "speed=[0-9]*\.[0-9]*x" "$log_file" 2>/dev/null | tail -1 | cut -d'=' -f2)
#    [ -z "$speed" ] && speed="N/A"
#    echo "$speed"
#}
extract_speed() {
 local log_file="$1"
 local speed="0"
 
 if [ -f "$log_file" ]; then
     # 格式1: "speed=25.4x" (标准格式)
     speed=$(grep -o "speed=[0-9]*\.[0-9]*x" "$log_file" 2>/dev/null | tail -1 | cut -d'=' -f2 | tr -d 'x')
     
     # 格式2: "speed=25x" (整数格式)
     if [ -z "$speed" ] || [ "$speed" = "0" ]; then
         speed=$(grep -o "speed=[0-9]*x" "$log_file" 2>/dev/null | tail -1 | cut -d'=' -f2 | tr -d 'x')
     fi
     
     # 格式3: 从"11.4xx"中提取（您的日志中显示这种格式）
     if [ -z "$speed" ] || [ "$speed" = "0" ]; then
         speed=$(grep -o "[0-9]*\.[0-9]*xx" "$log_file" 2>/dev/null | tail -1 | tr -d 'x')
     fi
     
     # 格式4: 直接数字格式
     if [ -z "$speed" ] || [ "$speed" = "0" ]; then
         speed=$(grep -o "speed= *[0-9]*\.[0-9]*" "$log_file" 2>/dev/null | tail -1 | awk '{print $2}')
     fi
 fi
 
 # 最后验证：确保是数字，不是"N/A"或其他文本
 if ! [[ "$speed" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
     speed="0"
 fi
 
 echo "$speed"
}

# 函数：运行性能测试
run_test() {
    local test_name="$1"
    local ffmpeg_cmd="$2"
    local output_file="$3"
    local test_start_time=$(date +%s.%N)
    
    log_section "运行测试: $test_name"
    log "命令: $(echo "$ffmpeg_cmd" | tr -s ' ')"
    
    local total_time=0
    local total_speed=0
    local speed_count=0
    local iteration=0
    local test_log="$OUTPUT_DIR/logs/${test_name}.log"
    
    for ((i=0; i<$((WARMUP_ITERATIONS + TEST_ITERATIONS)); i++)); do
        # 清理缓存
        sync
        [ -w /proc/sys/vm/drop_caches ] && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
        
        # 临时日志文件
        local temp_log="$OUTPUT_DIR/logs/temp_${test_name}_${i}.log"
        
        # 运行测试
        local iter_start_time=$(date +%s.%N)
        
        # 使用超时运行
        if run_with_timeout $TIMEOUT_SECONDS "$ffmpeg_cmd" "$temp_log"; then
            local iter_end_time=$(date +%s.%N)
            local duration=$(echo "$iter_end_time - $iter_start_time" | bc 2>/dev/null || echo "0")
            
            # 提取速度
            local speed=$(extract_speed "$temp_log")
            
            # 跳过预热迭代
            if [ $i -ge $WARMUP_ITERATIONS ]; then
                iteration=$((iteration + 1))
                total_time=$(echo "$total_time + $duration" | bc 2>/dev/null || echo "$total_time")
                
#                if [ "$speed" != "N/A" ]; then
#                    total_speed=$(echo "$total_speed + $speed" | bc 2>/dev/null || echo "$total_speed")
#                    speed_count=$((speed_count + 1))
#                fi
				# 累加速度 - 修复版
				if [ -n "$speed" ] && [ "$speed" != "N/A" ]; then
    				# 清理速度值：移除所有"x"字符，只保留数字
    				local clean_speed=$(echo "$speed" | tr -d 'x')
    
    				# 验证清理后的值是数字
    				if [[ "$clean_speed" =~ ^[0-9]+(\.[0-9]+)?$ ]] && [ "$clean_speed" != "0" ]; then
        				total_speed=$(echo "$total_speed + $clean_speed" | bc 2>/dev/null || echo "$total_speed")
        				speed_count=$((speed_count + 1))
        				log "有效速度值: ${clean_speed}, 已累加"
    				else
        				log "无效速度值: '$speed' (清理后: '$clean_speed')，跳过"
    				fi
				fi               
                log "迭代 $iteration: 时间=${duration}s, 速度=${speed}x"
            fi
        else
            if [ $? -eq 124 ]; then
                log_warning "测试 $test_name 超时 (${TIMEOUT_SECONDS}秒)"
            else
                log_warning "测试 $test_name 失败"
            fi
            [ -f "$temp_log" ] && rm "$temp_log"
            return 1
        fi
        
        # 保存详细日志
        [ -f "$temp_log" ] && cat "$temp_log" >> "$test_log" 2>/dev/null
        [ -f "$temp_log" ] && rm "$temp_log"
    done
    
    # 计算平均值
    local avg_time=0
#    local avg_speed=0
    if [ $iteration -gt 0 ]; then
        avg_time=$(echo "scale=3; $total_time / $iteration" | bc 2>/dev/null || echo "0")
    fi
    
#    if [ $speed_count -gt 0 ]; then
#        avg_speed=$(echo "scale=2; $total_speed / $speed_count" | bc 2>/dev/null || echo "0")
#    fi
	# 计算平均速度
	local avg_speed="N/A"
	if [ $speed_count -gt 0 ]; then
    	avg_speed=$(echo "scale=2; $total_speed / $speed_count" | bc 2>/dev/null || echo "0")
	fi

	# 确保avg_speed是数字格式
	if ! [[ "$avg_speed" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    	avg_speed="0"
	fi
   
    # 计算相对于实时的速度
    local realtime_speed=0
    if [ $(echo "$avg_time > 0" | bc 2>/dev/null) -eq 1 ]; then
        realtime_speed=$(echo "scale=2; $TEST_DURATION / $avg_time" | bc 2>/dev/null || echo "0")
    fi
    
    # 记录测试结束时间
    local test_end_time=$(date +%s.%N)
    local test_total_time=$(echo "$test_end_time - $test_start_time" | bc 2>/dev/null || echo "0")
    
    # 记录到CSV
    echo "$(date +'%Y-%m-%d %H:%M:%S'),$test_name,$avg_time,${avg_speed}x,${realtime_speed}x,$test_total_time" >> "$CSV_FILE"
    echo "$test_name,$avg_time,${avg_speed}x,${realtime_speed}x,$test_total_time" >> "$SPEED_CSV"
    
    log_success "完成测试 $test_name: 时间=${avg_time}s, 速度=${avg_speed}x, 实时倍数=${realtime_speed}x, 测试耗时=${test_total_time}s"
    
    return 0
}

# 函数：编码测试
encode_test() {
    local codec="$1"
    local preset="$2"
    local resolution="$3"
    local bitrate="$4"
    
    local width=$(echo "$resolution" | cut -d'x' -f1)
    local height=$(echo "$resolution" | cut -d'x' -f2)
    local test_name="encode_${codec}_${preset}_${resolution}_${bitrate}"
    
    # 构建FFmpeg命令
    local ffmpeg_cmd="ffmpeg -y -i '$INPUT_FILE' \
        -t $TEST_DURATION \
        -s ${width}x${height} \
        -c:v $codec"
    
    # 编码器特定参数
    case "$codec" in
        "libx264")
            ffmpeg_cmd="$ffmpeg_cmd -preset $preset -b:v $bitrate"
            ;;
        "libx265")
            ffmpeg_cmd="$ffmpeg_cmd -preset $preset -b:v $bitrate"
            ;;
        "libvpx-vp9")
            ffmpeg_cmd="$ffmpeg_cmd -b:v $bitrate -speed 4"
            ;;
        "libsvtav1")
            ffmpeg_cmd="$ffmpeg_cmd -preset $preset -b:v $bitrate"
            ;;
        "libaom-av1")
            [ "$SKIP_AV1" = "true" ] && return
            ffmpeg_cmd="$ffmpeg_cmd -b:v $bitrate -cpu-used 4"
            ;;
        *)
            return
            ;;
    esac
    
    ffmpeg_cmd="$ffmpeg_cmd -an -f null -"
    
    run_test "$test_name" "$ffmpeg_cmd" "/dev/null"
}

# 函数：解码测试
decode_test() {
    local codec="$1"
    local test_input="$2"
    
    local test_name="decode_${codec}"
    
    # 构建FFmpeg命令
    local ffmpeg_cmd="ffmpeg -y -i '$test_input' \
        -t $TEST_DURATION \
        -c:v rawvideo \
        -pix_fmt yuv420p \
        -f rawvideo /dev/null"
    
    run_test "$test_name" "$ffmpeg_cmd" "/dev/null"
}

# 函数：滤镜处理测试
filter_test() {
    local filter="$1"
    local filter_name="$2"
    
    local test_name="filter_${filter_name}"
    
    # 构建FFmpeg命令
    local ffmpeg_cmd="ffmpeg -y -i '$INPUT_FILE' \
        -t $TEST_DURATION \
        -vf '$filter' \
        -c:v libx264 \
        -preset ultrafast \
        -an \
        -f null -"
    
    run_test "$test_name" "$ffmpeg_cmd" "/dev/null"
}

# 函数：硬件加速测试
hw_accel_test() {
    local hw_accel="$1"
    local codec="$2"
    
    [ "$ENABLE_HARDWARE_TESTS" != "true" ] && return
    
    # 检查硬件加速是否可用
    if ! ffmpeg -hwaccels 2>/dev/null | grep -q "$hw_accel"; then
        log_warning "硬件加速 $hw_accel 不可用，跳过测试"
        return
    fi
    
    local test_name="hw_${hw_accel}_${codec}"
    local ffmpeg_cmd=""
    
    case "$hw_accel" in
        "qsv")
            if ffmpeg -encoders 2>/dev/null | grep -q "${codec}_qsv"; then
                ffmpeg_cmd="ffmpeg -y -hwaccel qsv -i '$INPUT_FILE' \
                    -t $TEST_DURATION \
                    -c:v ${codec}_qsv \
                    -b:v 5000k \
                    -an \
                    -f null -"
            else
                log_warning "编码器 ${codec}_qsv 不可用"
                return
            fi
            ;;
        "cuda"|"nvenc")
            if ffmpeg -encoders 2>/dev/null | grep -q "${codec}_nvenc"; then
                ffmpeg_cmd="ffmpeg -y -hwaccel cuda -i '$INPUT_FILE' \
                    -t $TEST_DURATION \
                    -c:v ${codec}_nvenc \
                    -b:v 5000k \
                    -preset p7 \
                    -an \
                    -f null -"
            else
                log_warning "编码器 ${codec}_nvenc 不可用"
                return
            fi
            ;;
        "vaapi")
            if [ -d "/dev/dri" ] && ffmpeg -encoders 2>/dev/null | grep -q "${codec}_vaapi"; then
                ffmpeg_cmd="ffmpeg -y -vaapi_device /dev/dri/renderD128 -i '$INPUT_FILE' \
                    -t $TEST_DURATION \
                    -vf 'format=nv12,hwupload' \
                    -c:v ${codec}_vaapi \
                    -b:v 5000k \
                    -an \
                    -f null -"
            else
                log_warning "VA-API 或编码器 ${codec}_vaapi 不可用"
                return
            fi
            ;;
        *)
            return
            ;;
    esac
    
    run_test "$test_name" "$ffmpeg_cmd" "/dev/null"
}

# 函数：多线程测试
thread_test() {
    local threads="$1"
    
    local test_name="threads_${threads}"
    
    # 构建FFmpeg命令
    local ffmpeg_cmd="ffmpeg -y -threads $threads -i '$INPUT_FILE' \
        -t $TEST_DURATION \
        -c:v libx264 \
        -preset medium \
        -b:v 5000k \
        -an \
        -f null -"
    
    run_test "$test_name" "$ffmpeg_cmd" "/dev/null"
}

# 函数：质量分析测试
quality_test() {
    [ "$ENABLE_QUALITY_TESTS" != "true" ] && return
    
    local codec="$1"
    local preset="$2"
    local bitrate="$3"
    
    local test_name="quality_${codec}_${preset}_${bitrate}"
    local output_file="$OUTPUT_DIR/videos/${test_name}.mp4"
    
    log_section "运行质量测试: $test_name"
    
    # 编码测试视频
    log "编码测试视频..."
    ffmpeg -y -i "$INPUT_FILE" -t 5 \
        -c:v "$codec" -preset "$preset" -b:v "$bitrate" -an \
        "$output_file" 2>&1 | tee -a "$OUTPUT_DIR/logs/${test_name}_encode.log" > /dev/null
    
    if [ ! -f "$output_file" ] || [ ! -s "$output_file" ]; then
        log_error "质量测试 $test_name 编码失败"
        echo "$codec,$preset,$bitrate,0.0000,0.00,0" >> "$OUTPUT_DIR/quality_results.csv"
        return
    fi
    
    # 计算质量指标
    local quality_log="$OUTPUT_DIR/logs/${test_name}_quality.log"
    
    log "计算质量指标 (SSIM/PSNR)..."
    # 使用ffmpeg计算SSIM和PSNR
    ffmpeg -i "$INPUT_FILE" -i "$output_file" \
        -lavfi "ssim=stats_file=$OUTPUT_DIR/logs/ssim_${test_name}.log;[0:v][1:v]psnr" \
        -f null - 2> "$quality_log"
    
    # 提取SSIM
    local ssim=$(grep -o "SSIM Y:[0-9.]*" "$quality_log" 2>/dev/null | head -1 | cut -d: -f2)
    [ -z "$ssim" ] && ssim="0.0000"
    
    # 提取PSNR
    local psnr=$(grep -o "PSNR y:[0-9.]* dB" "$quality_log" 2>/dev/null | head -1 | awk '{print $2}')
    [ -z "$psnr" ] && psnr="0.00"
    
    # 文件大小
    local size_kb=0
    if [ -f "$output_file" ]; then
        local size_bytes=$(stat -c%s "$output_file" 2>/dev/null)
        [ -n "$size_bytes" ] && size_kb=$(echo "scale=2; $size_bytes / 1024" | bc 2>/dev/null || echo "0")
    fi
    
    # 记录结果
    echo "$codec,$preset,$bitrate,$ssim,$psnr,$size_kb" >> "$OUTPUT_DIR/quality_results.csv"
    
    log_success "质量测试 $test_name: SSIM=$ssim, PSNR=${psnr}dB, 大小=${size_kb}KB"
}

# 函数：生成测试视频
generate_test_video() {
    local resolution="$1"
    local duration="$2"
    local output="$3"
    
    log_section "生成测试视频: ${resolution}, 时长: ${duration}s"
    
    # 使用复杂的测试源以获得更好的质量评估
    log "使用 testsrc2 生成测试视频..."
    ffmpeg -y -f lavfi -i "testsrc2=duration=$duration:size=${resolution}:rate=30" \
        -c:v libx264 -preset ultrafast -crf 18 -pix_fmt yuv420p \
        "$output" 2>&1 | tee -a "$LOG_FILE" > /dev/null
    
    if [ ! -f "$output" ] || [ ! -s "$output" ]; then
        log_warning "testsrc2 失败，回退到 testsrc..."
        # 回退到简单测试源
        ffmpeg -y -f lavfi -i "testsrc=duration=$duration:size=${resolution}:rate=30" \
            -c:v libx264 -preset ultrafast -pix_fmt yuv420p \
            "$output" 2>&1 | tee -a "$LOG_FILE" > /dev/null
    fi
    
    if [ -f "$output" ]; then
        local video_info=$(ffprobe -v error -select_streams v:0 \
            -show_entries stream=width,height,codec_name,r_frame_rate,duration,bit_rate \
            -of default=noprint_wrappers=1 "$output" 2>/dev/null)
        log_success "测试视频生成完成: $video_info"
    else
        log_error "无法生成测试视频"
        return 1
    fi
}

# 函数：显示测试进度
show_progress() {
    local current=$1
    local total=$2
    local width=50
    
    [ $total -eq 0 ] && return
    
    local percent=$((current * 100 / total))
    local completed=$((current * width / total))
    local remaining=$((width - completed))
    
    printf "\r["
    for ((i=0; i<completed; i++)); do printf "█"; done
    for ((i=0; i<remaining; i++)); do printf " "; done
    printf "] %d%% (%d/%d)" "$percent" "$current" "$total"
}

# 函数：简化版本的主测试流程
run_basic_tests() {
    log_header "运行基础性能测试"
    
    # 初始化结果文件
    echo "时间戳,测试名称,平均时间(秒),编码速度(x),实时倍数(x),测试耗时(秒)" > "$CSV_FILE"
    echo "测试名称,平均时间(秒),编码速度(x),实时倍数(x),测试耗时(秒)" > "$SPEED_CSV"
    echo "编码器,预设,比特率,SSIM,PSNR(dB),文件大小(KB)" > "$OUTPUT_DIR/quality_results.csv"
    
    # 如果输入文件不存在，生成测试视频
    if [ ! -f "$INPUT_FILE" ]; then
        log_section "生成测试视频"
        generate_test_video "1920x1080" 30 "$INPUT_FILE"
        if [ $? -ne 0 ]; then
            log_error "无法生成测试视频，退出"
            exit 1
        fi
    fi
    
    # 获取输入视频信息
    log_section "输入视频信息"
    local video_info=$(ffprobe -v error -select_streams v:0 \
        -show_entries stream=width,height,codec_name,r_frame_rate,duration,bit_rate \
        -of default=noprint_wrappers=1 "$INPUT_FILE" 2>/dev/null)
    if [ -n "$video_info" ]; then
        echo "$video_info" | tee -a "$LOG_FILE"
    else
        log_error "无法获取输入视频信息"
        exit 1
    fi
    
    # 计算预计测试数量
    local total_tests=0
    for resolution in $RESOLUTIONS; do
        for bitrate in $BITRATES; do
            total_tests=$((total_tests + 4))  # H.264 medium/slow, H.265, VP9
        done
    done
    total_tests=$((total_tests + 3))  # 解码测试
    total_tests=$((total_tests + 5))  # 滤镜测试
    total_tests=$((total_tests + 7))  # 多线程测试 (1,2,4,8,16,32,64)
    
    [ "$ENABLE_HARDWARE_TESTS" = "true" ] && total_tests=$((total_tests + 5))
    [ "$ENABLE_QUALITY_TESTS" = "true" ] && total_tests=$((total_tests + 18))
    
    log "预计执行测试数量: $total_tests 个"
    log "预计运行时间: 约 $(echo "scale=1; $total_tests * $TEST_DURATION * $TEST_ITERATIONS / 10" | bc 2>/dev/null || echo "未知") 分钟"
    
    local test_counter=0
    
    # 1. 编码测试
    log_header "1. 编码性能测试"
    for resolution in $RESOLUTIONS; do
        for bitrate in $BITRATES; do
            # H.264编码测试
            encode_test "libx264" "medium" "$resolution" "$bitrate"
            test_counter=$((test_counter + 1))
            show_progress $test_counter $total_tests
            
            encode_test "libx264" "slow" "$resolution" "$bitrate"
            test_counter=$((test_counter + 1))
            show_progress $test_counter $total_tests
            
            # H.265/HEVC编码测试
            encode_test "libx265" "medium" "$resolution" "$bitrate"
            test_counter=$((test_counter + 1))
            show_progress $test_counter $total_tests
            
            # VP9编码测试
            encode_test "libvpx-vp9" "good" "$resolution" "$bitrate"
            test_counter=$((test_counter + 1))
            show_progress $test_counter $total_tests
        done
    done
    echo ""
    
    # 2. 解码测试
    log_header "2. 解码性能测试"
    
    # 创建不同编码格式的测试文件
    for codec in libx264 libx265 libvpx-vp9; do
        test_file="$OUTPUT_DIR/videos/decode_test_${codec}.mp4"
        if [ ! -f "$test_file" ]; then
            log "生成解码测试文件: $codec"
            ffmpeg -y -i "$INPUT_FILE" -t 5 -c:v "$codec" -preset ultrafast "$test_file" 2>/dev/null
        fi
        if [ -f "$test_file" ]; then
            decode_test "$codec" "$test_file"
            test_counter=$((test_counter + 1))
            show_progress $test_counter $total_tests
        fi
    done
    echo ""
    
    # 3. 滤镜处理测试
    log_header "3. 滤镜处理性能测试"
    
    filter_test "scale=1280:720" "scale_720p"
    test_counter=$((test_counter + 1))
    show_progress $test_counter $total_tests
    
    filter_test "scale=1920:1080" "scale_1080p"
    test_counter=$((test_counter + 1))
    show_progress $test_counter $total_tests
    
    filter_test "hflip" "horizontal_flip"
    test_counter=$((test_counter + 1))
    show_progress $test_counter $total_tests
    
    filter_test "vflip" "vertical_flip"
    test_counter=$((test_counter + 1))
    show_progress $test_counter $total_tests
    
    filter_test "boxblur=10:5" "boxblur"
    test_counter=$((test_counter + 1))
    show_progress $test_counter $total_tests
    echo ""
    
    # 4. 硬件加速测试
    if [ "$ENABLE_HARDWARE_TESTS" = "true" ]; then
        log_header "4. 硬件加速测试"
        
        hw_accel_test "vaapi" "h264"
        test_counter=$((test_counter + 1))
        show_progress $test_counter $total_tests
        
        hw_accel_test "vaapi" "hevc"
        test_counter=$((test_counter + 1))
        show_progress $test_counter $total_tests
        
        hw_accel_test "qsv" "h264"
        test_counter=$((test_counter + 1))
        show_progress $test_counter $total_tests
        
        hw_accel_test "cuda" "h264"
        test_counter=$((test_counter + 1))
        show_progress $test_counter $total_tests
        
        hw_accel_test "cuda" "hevc"
        test_counter=$((test_counter + 1))
        show_progress $test_counter $total_tests
        echo ""
    fi
    
    # 5. 多线程测试
    log_header "5. 多线程性能测试"
    
    for threads in 1 2 4 8 16 32 64; do
        thread_test "$threads"
        test_counter=$((test_counter + 1))
        show_progress $test_counter $total_tests
    done
    echo ""
    
    # 6. 质量分析测试
    if [ "$ENABLE_QUALITY_TESTS" = "true" ]; then
        log_header "6. 编码质量测试"
        
        for codec in libx264 libx265 libvpx-vp9; do
            for preset in ultrafast medium slow; do
                for bitrate in 1000k 5000k; do
                    quality_test "$codec" "$preset" "$bitrate"
                    test_counter=$((test_counter + 1))
                    show_progress $test_counter $total_tests
                done
            done
        done
        echo ""
    fi
}

# 函数：生成简化报告
generate_simple_report() {
    log_header "生成测试报告"
    
    local test_end_time=$(date +%s.%N)
    local total_runtime=$(echo "$test_end_time - $SCRIPT_START_TIME" | bc 2>/dev/null)
    
    cat > "$SUMMARY_FILE" << EOF
========================================
FFmpeg性能测试执行摘要
========================================

测试完成时间: $(date)
总运行时间: ${total_runtime} 秒 ($(echo "scale=2; $total_runtime / 60" | bc 2>/dev/null) 分钟)

系统配置摘要:
$(if [ -f "$SYSTEM_INFO_FILE" ]; then
    grep -A5 "CPU信息" "$SYSTEM_INFO_FILE" | tail -n +2
    grep -A2 "内存信息" "$SYSTEM_INFO_FILE" | tail -n +2
fi)

测试结果摘要:
$(if [ -f "$CSV_FILE" ]; then
    echo "编码性能最佳:"
    grep "^encode" "$CSV_FILE" | awk -F',' '{print $2 "," $5}' | sort -t',' -k2 -rn | head -3 | while IFS=',' read -r test speed; do
        echo "  $test: ${speed}"
    done
    
    echo -e "\n解码性能最佳:"
    grep "^decode" "$CSV_FILE" | awk -F',' '{print $2 "," $5}' | sort -t',' -k2 -rn | head -3 | while IFS=',' read -r test speed; do
        echo "  $test: ${speed}"
    done
fi)

测试统计:
- 总测试数: $(grep -c "^[^#]" "$CSV_FILE" 2>/dev/null || echo 0)
- 成功测试: $(grep -c "^[^#].*x" "$CSV_FILE" 2>/dev/null || echo 0)
- 失败/超时: $(($(grep -c "^[^#]" "$CSV_FILE" 2>/dev/null || echo 0) - $(grep -c "^[^#].*x" "$CSV_FILE" 2>/dev/null || echo 0)))

生成的文件:
1. 详细数据: $CSV_FILE
2. 系统信息: $SYSTEM_INFO_FILE
3. 对比指标: $OUTPUT_DIR/comparison_metrics.csv
4. 执行摘要: $SUMMARY_FILE
5. 完整日志: $LOG_FILE

========================================
EOF
    
    # 显示结果摘要
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}      测试完成！${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "总运行时间: ${total_runtime} 秒"
    echo -e "输出目录: $OUTPUT_DIR"
    echo -e "结果文件:"
    echo -e "  ${GREEN}✓${NC} $CSV_FILE"
    echo -e "  ${GREEN}✓${NC} $SUMMARY_FILE"
    echo -e "  ${GREEN}✓${NC} $OUTPUT_DIR/comparison_metrics.csv"
    echo -e "${GREEN}========================================${NC}"
}

# 函数：清理临时文件
cleanup() {
    log_section "清理临时文件"
    
    # 清理临时日志文件
    rm -f "$OUTPUT_DIR"/logs/temp_*.log 2>/dev/null
    rm -f "$OUTPUT_DIR"/logs/ssim_*.log 2>/dev/null
    
    # 清理空文件
    find "$OUTPUT_DIR" -type f -empty -delete 2>/dev/null
    
    # 计算总文件大小
    local total_size=$(du -sh "$OUTPUT_DIR" 2>/dev/null | cut -f1)
    log_success "清理完成，输出目录总大小: $total_size"
}

# 主函数
main() {
    log_header "FFmpeg性能基准测试开始"
    
    # 检查命令
    if ! command -v ffmpeg &> /dev/null; then
        log_error "ffmpeg 命令未找到，请先安装FFmpeg"
        exit 1
    fi
    
    if ! command -v bc &> /dev/null; then
        log_error "bc 命令未找到，请先安装bc"
        exit 1
    fi
    
    if ! command -v ffprobe &> /dev/null; then
        log_error "ffprobe 命令未找到，请先安装FFmpeg完整版"
        exit 1
    fi
    
    # 收集系统信息
    collect_system_info
    
    # 记录测试配置
    record_test_config
    
    # 显示测试配置
    log_section "测试配置"
    log "输入文件: $INPUT_FILE"
    log "输出目录: $OUTPUT_DIR"
    log "测试时长: ${TEST_DURATION}秒/测试"
    log "测试分辨率: $RESOLUTIONS"
    log "测试比特率: $BITRATES"
    log "测试迭代: $TEST_ITERATIONS 次"
    log "超时时间: ${TIMEOUT_SECONDS}秒"
    
    # 运行测试
    run_basic_tests
    
    # 生成报告
    generate_simple_report
    
    # 清理
    cleanup
}

# 设置退出时清理
trap cleanup EXIT

# 运行主函数
main "$@"
