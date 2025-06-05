#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import os, csv

BASE = '/home/cdong/ffmpeg-performance-test-script'
OUT  = '/home/user/cdong/multi_channel_report.html'

DIRS_sorted = [
    'ffmpeg_benchmark_20250606_141724_24_channel',
    'ffmpeg_benchmark_20250604_222001_12_channel',
    'ffmpeg_benchmark_20250604_222750_8_channel',
    'ffmpeg_benchmark_20250604_221917_4_channel',
    'ffmpeg_benchmark_20250605_005634_2_channel',
]

LABEL_MAP = {
    '24_channel': '24-ch (1511GB)',
    '12_channel': '12-ch (755GB)',
    '8_channel':  '8-ch (503GB)',
    '4_channel':  '4-ch (251GB)',
    '2_channel':  '2-ch (126GB)',
}

# Memory hardware info (from dmidecode on 10.83.32.80)
# Samsung DDR5-4800 64GB RDIMM, 1.1V
# Theoretical BW per channel = 4800 MT/s x 8 bytes = 38.4 GB/s
MEM_HW = {
    'type':        'DDR5',
    'speed':       '4800 MT/s',
    'configured':  '4800 MT/s',
    'manufacturer':'Samsung',
    'part_number': 'M321R8GA0BB0-CQKVG',
    'dimm_size':   '64 GB',
    'voltage':     '1.1 V',
    'ecc':         'Multi-bit ECC',
    'form_factor': 'RDIMM (Registered Buffered)',
    'bw_per_ch':   38.4,   # GB/s per channel
}

# Channel count and DIMM count per config
CH_INFO = {
    '24_channel': {'ch': 24, 'dimms': 24},
    '12_channel': {'ch': 12, 'dimms': 12},
    '8_channel':  {'ch':  8, 'dimms':  8},
    '4_channel':  {'ch':  4, 'dimms':  4},
    '2_channel':  {'ch':  2, 'dimms':  2},
}

COLORS = ['#58a6ff', '#3fb950', '#f78166', '#d2a8ff', '#ffa657']


def infer_label(dirname):
    for k, v in LABEL_MAP.items():
        if k in dirname:
            return v
    return dirname


def infer_ch_key(dirname):
    for k in CH_INFO:
        if k in dirname:
            return k
    return None


def parse_speed(val):
    if not val:
        return 0.0
    try:
        return float(val.replace('x', '').strip())
    except:
        return 0.0


def load_csv(path):
    rows = {}
    if not os.path.exists(path):
        return rows
    with open(path, encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            name = row.get('测试名称', '').strip()
            if name:
                rows[name] = row
    return rows


configs = []
for d in DIRS_sorted:
    csv_path = os.path.join(BASE, d, 'benchmark_results.csv')
    data = load_csv(csv_path)
    ch_key = infer_ch_key(d)
    ch_info = CH_INFO.get(ch_key, {'ch': 0, 'dimms': 0})
    configs.append({
        'label':  infer_label(d),
        'data':   data,
        'ch':     ch_info['ch'],
        'dimms':  ch_info['dimms'],
        'bw':     round(ch_info['ch'] * MEM_HW['bw_per_ch'], 1),
    })

cfg_labels = [c['label'] for c in configs]


def get_speed(data, name):
    row = data.get(name)
    if not row:
        return 0.0
    return parse_speed(row.get('编码速度(x)', '0'))


def get_realtime(data, name):
    row = data.get(name)
    if not row:
        return 0.0
    return parse_speed(row.get('实时倍数(x)', '0'))


def pct(val, base):
    if base == 0:
        return 'N/A'
    p = (val - base) / base * 100
    return f'{p:+.1f}%'


def pct_color(val, base):
    if base == 0:
        return '#8b949e'
    return '#3fb950' if val >= base else '#f78166'


# ---- SVG grouped bar ----
def svg_grouped_bar(groups, x_labels, series_labels, colors, width=980, height=380, ylabel='编码速度 (x)'):
    PL, PR, PT, PB = 70, 20, 30, 90
    W = width - PL - PR
    H = height - PT - PB
    n_groups = len(x_labels)
    n_series = len(groups)
    all_vals = [v for g in groups for v in g if v > 0]
    max_v = max(all_vals) * 1.15 if all_vals else 1
    gw = W / max(n_groups, 1)
    bw = gw * 0.8 / max(n_series, 1)
    gap = gw * 0.1

    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" style="background:#161b22;border-radius:8px">']
    ticks = 5
    for i in range(ticks + 1):
        yv = max_v * i / ticks
        yp = PT + H - H * i / ticks
        out.append(f'<line x1="{PL}" y1="{yp:.1f}" x2="{PL+W}" y2="{yp:.1f}" stroke="#30363d" stroke-width="1"/>')
        out.append(f'<text x="{PL-5}" y="{yp+4:.1f}" text-anchor="end" fill="#8b949e" font-size="11">{yv:.2f}</text>')
    out.append(f'<text transform="rotate(-90 14 {PT+H//2})" x="14" y="{PT+H//2}" text-anchor="middle" fill="#8b949e" font-size="12">{ylabel}</text>')

    for gi in range(n_groups):
        gx = PL + gi * gw
        for si in range(n_series):
            val = groups[si][gi] if si < len(groups) and gi < len(groups[si]) else 0
            if val <= 0:
                continue
            bh = H * val / max_v
            bx = gx + gap + si * bw
            by = PT + H - bh
            c = colors[si % len(colors)]
            out.append(f'<rect x="{bx:.1f}" y="{by:.1f}" width="{bw:.1f}" height="{bh:.1f}" fill="{c}" rx="2"/>')
            if bh > 14:
                out.append(f'<text x="{bx+bw/2:.1f}" y="{by+bh-3:.1f}" text-anchor="middle" fill="#fff" font-size="8">{val:.2f}</text>')
        lx = gx + gw / 2
        ly = PT + H + 14
        lbl = x_labels[gi]
        out.append(f'<text x="{lx:.1f}" y="{ly:.1f}" text-anchor="middle" fill="#c9d1d9" font-size="9" transform="rotate(-35 {lx:.1f} {ly:.1f})">{lbl}</text>')

    lx0 = PL
    for si, cl in enumerate(series_labels):
        lx = lx0 + si * 150
        c = colors[si % len(colors)]
        out.append(f'<rect x="{lx}" y="{height-18}" width="12" height="12" fill="{c}" rx="2"/>')
        out.append(f'<text x="{lx+16}" y="{height-7}" fill="#c9d1d9" font-size="11">{cl}</text>')
    out.append('</svg>')
    return ''.join(out)


# ---- SVG multi-line ----
def svg_line_multi(series_list, x_labels, series_labels, colors, width=700, height=300, ylabel='编码速度 (x)'):
    PL, PR, PT, PB = 65, 20, 20, 65
    W = width - PL - PR
    H = height - PT - PB
    all_vals = [v for s in series_list for v in s if v > 0]
    max_v = max(all_vals) * 1.1 if all_vals else 1
    min_v = min(all_vals) * 0.9 if all_vals else 0
    rng = max_v - min_v or 1
    n = len(x_labels)

    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" style="background:#161b22;border-radius:8px">']
    ticks = 5
    for i in range(ticks + 1):
        yv = min_v + rng * i / ticks
        yp = PT + H - H * i / ticks
        out.append(f'<line x1="{PL}" y1="{yp:.1f}" x2="{PL+W}" y2="{yp:.1f}" stroke="#30363d" stroke-width="1"/>')
        out.append(f'<text x="{PL-5}" y="{yp+4:.1f}" text-anchor="end" fill="#8b949e" font-size="10">{yv:.2f}</text>')
    out.append(f'<text transform="rotate(-90 14 {PT+H//2})" x="14" y="{PT+H//2}" text-anchor="middle" fill="#8b949e" font-size="11">{ylabel}</text>')

    for xi, xl in enumerate(x_labels):
        xp = PL + xi * W / max(n - 1, 1)
        out.append(f'<line x1="{xp:.1f}" y1="{PT}" x2="{xp:.1f}" y2="{PT+H}" stroke="#21262d" stroke-width="1"/>')
        out.append(f'<text x="{xp:.1f}" y="{PT+H+15}" text-anchor="middle" fill="#c9d1d9" font-size="11">{xl}</text>')

    for si, series in enumerate(series_list):
        col = colors[si % len(colors)]
        pts = []
        for xi, v in enumerate(series):
            if v > 0:
                xp = PL + xi * W / max(n - 1, 1)
                yp = PT + H - H * (v - min_v) / rng
                pts.append((xp, yp, v))
        if len(pts) > 1:
            d = 'M ' + ' L '.join(f'{p[0]:.1f},{p[1]:.1f}' for p in pts)
            out.append(f'<path d="{d}" stroke="{col}" stroke-width="2.5" fill="none"/>')
        for p in pts:
            out.append(f'<circle cx="{p[0]:.1f}" cy="{p[1]:.1f}" r="4" fill="{col}" stroke="#161b22" stroke-width="1.5"/>')

    for si, cl in enumerate(series_labels):
        lx = PL + si * 120
        c = colors[si % len(colors)]
        out.append(f'<rect x="{lx}" y="{height-16}" width="10" height="10" fill="{c}" rx="2"/>')
        out.append(f'<text x="{lx+14}" y="{height-6}" fill="#c9d1d9" font-size="10">{cl}</text>')
    out.append('</svg>')
    return ''.join(out)


# ---- Comparison table ----
def build_table(test_name, display_name):
    base_v = get_speed(configs[0]['data'], test_name)
    rows_html = ''
    for c in configs:
        v = get_speed(c['data'], test_name)
        p = pct(v, base_v)
        color = pct_color(v, base_v)
        rows_html += f'<tr><td>{c["label"]}</td><td style="font-family:monospace">{v:.2f}x</td><td style="color:{color};font-family:monospace">{p}</td></tr>\n'
    return f'''<table>
<thead><tr><th>内存配置</th><th>{display_name}</th><th>vs 24-ch 基准</th></tr></thead>
<tbody>{rows_html}</tbody>
</table>'''


# ---- Generate charts ----
res_x264 = [
    ('480p 2M', 'encode_libx264_medium_854x480_2000k'),
    ('480p 5M', 'encode_libx264_medium_854x480_5000k'),
    ('720p 2M', 'encode_libx264_medium_1280x720_2000k'),
    ('720p 5M', 'encode_libx264_medium_1280x720_5000k'),
    ('1080p 2M', 'encode_libx264_medium_1920x1080_2000k'),
    ('1080p 5M', 'encode_libx264_medium_1920x1080_5000k'),
]
chart_x264 = svg_grouped_bar(
    [[get_speed(c['data'], t[1]) for t in res_x264] for c in configs],
    [t[0] for t in res_x264], cfg_labels, COLORS)

res_x265 = [
    ('480p 2M', 'encode_libx265_medium_854x480_2000k'),
    ('480p 5M', 'encode_libx265_medium_854x480_5000k'),
    ('720p 2M', 'encode_libx265_medium_1280x720_2000k'),
    ('720p 5M', 'encode_libx265_medium_1280x720_5000k'),
    ('1080p 2M', 'encode_libx265_medium_1920x1080_2000k'),
    ('1080p 5M', 'encode_libx265_medium_1920x1080_5000k'),
]
chart_x265 = svg_grouped_bar(
    [[get_speed(c['data'], t[1]) for t in res_x265] for c in configs],
    [t[0] for t in res_x265], cfg_labels, COLORS)

res_vp9 = [
    ('480p 2M', 'encode_libvpx-vp9_good_854x480_2000k'),
    ('480p 5M', 'encode_libvpx-vp9_good_854x480_5000k'),
    ('720p 2M', 'encode_libvpx-vp9_good_1280x720_2000k'),
    ('720p 5M', 'encode_libvpx-vp9_good_1280x720_5000k'),
    ('1080p 2M', 'encode_libvpx-vp9_good_1920x1080_2000k'),
    ('1080p 5M', 'encode_libvpx-vp9_good_1920x1080_5000k'),
]
chart_vp9 = svg_grouped_bar(
    [[get_speed(c['data'], t[1]) for t in res_vp9] for c in configs],
    [t[0] for t in res_vp9], cfg_labels, COLORS)

dec_names = ['decode_libx264', 'decode_libx265', 'decode_libvpx-vp9']
chart_dec = svg_grouped_bar(
    [[get_speed(c['data'], t) for t in dec_names] for c in configs],
    ['H.264', 'H.265', 'VP9'], cfg_labels, COLORS,
    width=700, height=320, ylabel='解码速度 (x)')

flt_names = ['filter_scale_720p', 'filter_scale_1080p', 'filter_horizontal_flip', 'filter_vertical_flip', 'filter_boxblur']
chart_flt = svg_grouped_bar(
    [[get_speed(c['data'], t) for t in flt_names] for c in configs],
    ['Scale 720p', 'Scale 1080p', 'H-Flip', 'V-Flip', 'Boxblur'], cfg_labels, COLORS,
    width=900, height=340, ylabel='速度 (x)')

thread_keys = ['threads_1', 'threads_2', 'threads_4', 'threads_8', 'threads_16', 'threads_32', 'threads_64']
chart_threads = svg_line_multi(
    [[get_speed(c['data'], k) for k in thread_keys] for c in configs],
    ['1', '2', '4', '8', '16', '32', '64'], cfg_labels, COLORS)

tbl_x264_480  = build_table('encode_libx264_medium_854x480_2000k',  'libx264 480p 2Mbps 编码速度')
tbl_x264_720  = build_table('encode_libx264_medium_1280x720_2000k', 'libx264 720p 2Mbps 编码速度')
tbl_x264_1080 = build_table('encode_libx264_medium_1920x1080_2000k', 'libx264 1080p 2Mbps 编码速度')
tbl_x265_1080 = build_table('encode_libx265_medium_1920x1080_2000k', 'libx265 1080p 2Mbps 编码速度')
tbl_dec_264   = build_table('decode_libx264', 'H.264 解码速度')
tbl_dec_265   = build_table('decode_libx265', 'H.265 解码速度')
tbl_threads64 = build_table('threads_64', 'threads=64 1080p 编码速度')

# Summary values
base_data = configs[0]['data']
b_x264_1080 = get_speed(base_data, 'encode_libx264_medium_1920x1080_2000k')
b_dec_264   = get_speed(base_data, 'decode_libx264')
b_dec_265   = get_speed(base_data, 'decode_libx265')
worst_data  = configs[-1]['data']
w_x264_1080 = get_speed(worst_data, 'encode_libx264_medium_1920x1080_2000k')

# Build memory config table rows
mem_config_rows = ''
for c in configs:
    bw_str = f'{c["bw"]:.1f} GB/s'
    base_bw = configs[0]['bw']
    bw_pct = pct(c['bw'], base_bw)
    bw_color = pct_color(c['bw'], base_bw)
    mem_config_rows += f'''<tr>
      <td><strong>{c["label"]}</strong></td>
      <td style="text-align:center">{c["ch"]}</td>
      <td style="text-align:center">{c["dimms"]}</td>
      <td style="text-align:center">{c["dimms"]} x {MEM_HW["dimm_size"]}</td>
      <td style="font-family:monospace;text-align:center">{bw_str}</td>
      <td style="color:{bw_color};font-family:monospace;text-align:center">{bw_pct}</td>
    </tr>'''

html = f'''<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<title>FFmpeg 内存 Channel 配置性能对比报告</title>
<style>
* {{ box-sizing: border-box; margin: 0; padding: 0; }}
body {{ background: #0d1117; color: #c9d1d9; font-family: -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif; line-height: 1.5; }}
.header {{ background: linear-gradient(135deg,#161b22,#0d1117); padding: 40px 48px; border-bottom: 1px solid #30363d; }}
.header h1 {{ font-size: 1.9rem; color: #58a6ff; margin-bottom: 10px; }}
.header .meta {{ color: #8b949e; font-size: 0.9rem; line-height: 1.8; }}
nav {{ background: #161b22; border-bottom: 1px solid #30363d; padding: 0 48px; display: flex; gap: 0; overflow-x: auto; }}
nav a {{ color: #8b949e; text-decoration: none; padding: 14px 20px; font-size: 0.88rem; white-space: nowrap; border-bottom: 2px solid transparent; }}
nav a:hover {{ color: #58a6ff; border-bottom-color: #58a6ff; }}
.section {{ padding: 36px 48px; border-bottom: 1px solid #21262d; }}
.section h2 {{ font-size: 1.25rem; color: #e6edf3; margin-bottom: 20px; padding-bottom: 10px; border-bottom: 2px solid #58a6ff; }}
.section h3 {{ font-size: 1rem; color: #79c0ff; margin: 24px 0 12px; }}
.chart-wrap {{ overflow-x: auto; margin-bottom: 20px; }}
table {{ width: 100%; border-collapse: collapse; font-size: 0.88rem; margin: 12px 0 20px; }}
th {{ background: #161b22; color: #58a6ff; padding: 10px 14px; text-align: left; border: 1px solid #30363d; font-weight: 600; }}
td {{ padding: 8px 14px; border: 1px solid #21262d; }}
tr:nth-child(even) td {{ background: #161b22; }}
tr:hover td {{ background: #1c2128; }}
.summary-grid {{ display: grid; grid-template-columns: repeat(auto-fill,minmax(230px,1fr)); gap: 16px; margin-bottom: 24px; }}
.card {{ background: #161b22; border: 1px solid #30363d; border-radius: 8px; padding: 18px; }}
.card h4 {{ color: #8b949e; font-size: 0.82rem; margin-bottom: 8px; text-transform: uppercase; letter-spacing: 0.05em; }}
.card .val {{ font-size: 1.8rem; font-weight: 700; color: #58a6ff; font-family: monospace; }}
.card .sub {{ color: #8b949e; font-size: 0.8rem; margin-top: 6px; }}
.hw-grid {{ display: grid; grid-template-columns: repeat(auto-fill,minmax(200px,1fr)); gap: 12px; margin: 16px 0 24px; }}
.hw-item {{ background: #161b22; border: 1px solid #30363d; border-radius: 6px; padding: 12px 16px; }}
.hw-item .label {{ color: #8b949e; font-size: 0.78rem; text-transform: uppercase; letter-spacing: 0.04em; margin-bottom: 4px; }}
.hw-item .value {{ color: #e6edf3; font-size: 0.95rem; font-family: monospace; font-weight: 600; }}
.two-col {{ display: grid; grid-template-columns: 1fr 1fr; gap: 28px; }}
.bw-badge {{ display: inline-block; padding: 2px 8px; border-radius: 4px; font-size: 0.8rem; font-family: monospace; font-weight: 600; }}
@media(max-width:900px) {{ .two-col {{ grid-template-columns: 1fr; }} .section {{ padding: 24px; }} }}
</style>
</head>
<body>

<div class="header">
  <h1>FFmpeg 内存 Channel 配置性能对比报告</h1>
  <div class="meta">
    <div>CPU: AMD EPYC 9T24 96-Core Processor &nbsp;|&nbsp; 线程数: 384 &nbsp;|&nbsp; NUMA: 2 节点</div>
    <div>内存: Samsung DDR5-4800 64GB RDIMM &nbsp;|&nbsp; ECC: Multi-bit &nbsp;|&nbsp; 电压: 1.1V</div>
    <div>测试配置: 2-ch / 4-ch / 8-ch / 12-ch / 24-ch &nbsp;|&nbsp; 通过 BIOS 关闭内存通道</div>
    <div>基准配置: 24-channel (1511.33 GB, 921.6 GB/s 理论带宽) &nbsp;|&nbsp; FFmpeg 4.4.2</div>
  </div>
</div>

<nav>
  <a href="#hw">硬件规格</a>
  <a href="#overview">总览</a>
  <a href="#x264">libx264</a>
  <a href="#x265">libx265</a>
  <a href="#vp9">VP9</a>
  <a href="#decode">解码</a>
  <a href="#filter">滤镜</a>
  <a href="#threads">线程扩展</a>
</nav>

<div class="section" id="hw">
  <h2>内存硬件规格</h2>

  <h3>DIMM 规格参数</h3>
  <div class="hw-grid">
    <div class="hw-item"><div class="label">内存类型</div><div class="value">{MEM_HW["type"]}</div></div>
    <div class="hw-item"><div class="label">速率</div><div class="value">{MEM_HW["speed"]}</div></div>
    <div class="hw-item"><div class="label">配置速率</div><div class="value">{MEM_HW["configured"]}</div></div>
    <div class="hw-item"><div class="label">厂商</div><div class="value">{MEM_HW["manufacturer"]}</div></div>
    <div class="hw-item"><div class="label">料号 (Part Number)</div><div class="value">{MEM_HW["part_number"]}</div></div>
    <div class="hw-item"><div class="label">单条容量</div><div class="value">{MEM_HW["dimm_size"]}</div></div>
    <div class="hw-item"><div class="label">工作电压</div><div class="value">{MEM_HW["voltage"]}</div></div>
    <div class="hw-item"><div class="label">ECC 类型</div><div class="value">{MEM_HW["ecc"]}</div></div>
    <div class="hw-item"><div class="label">形态</div><div class="value">{MEM_HW["form_factor"]}</div></div>
    <div class="hw-item"><div class="label">单 Channel 理论带宽</div><div class="value">{MEM_HW["bw_per_ch"]} GB/s</div></div>
  </div>

  <h3>各配置内存通道与理论带宽</h3>
  <p style="color:#8b949e;font-size:0.85rem;margin-bottom:12px">
    理论带宽 = Channel 数 &times; 4800 MT/s &times; 8 bytes = Channel 数 &times; 38.4 GB/s
  </p>
  <table>
    <thead>
      <tr>
        <th>配置</th>
        <th style="text-align:center">激活 Channel 数</th>
        <th style="text-align:center">安装 DIMM 数</th>
        <th style="text-align:center">总容量</th>
        <th style="text-align:center">理论峰值带宽</th>
        <th style="text-align:center">vs 24-ch 带宽</th>
      </tr>
    </thead>
    <tbody>
      {mem_config_rows}
    </tbody>
  </table>
</div>

<div class="section" id="overview">
  <h2>性能总览</h2>
  <div class="summary-grid">
    <div class="card">
      <h4>24-ch 基准 libx264 1080p</h4>
      <div class="val">{b_x264_1080:.2f}x</div>
      <div class="sub">实时速度 {get_realtime(base_data,"encode_libx264_medium_1920x1080_2000k"):.2f}x &nbsp;|&nbsp; BW: {configs[0]["bw"]:.1f} GB/s</div>
    </div>
    <div class="card">
      <h4>2-ch 最低 libx264 1080p</h4>
      <div class="val" style="color:#f78166">{w_x264_1080:.2f}x</div>
      <div class="sub">vs 24-ch: {pct(w_x264_1080, b_x264_1080)} &nbsp;|&nbsp; BW: {configs[-1]["bw"]:.1f} GB/s</div>
    </div>
    <div class="card">
      <h4>24-ch H.264 解码速度</h4>
      <div class="val">{b_dec_264:.2f}x</div>
      <div class="sub">实时速度 {get_realtime(base_data,"decode_libx264"):.2f}x</div>
    </div>
    <div class="card">
      <h4>24-ch H.265 解码速度</h4>
      <div class="val">{b_dec_265:.2f}x</div>
      <div class="sub">实时速度 {get_realtime(base_data,"decode_libx265"):.2f}x</div>
    </div>
  </div>
  <h3>libx264 1080p 2Mbps 综合对比</h3>
  {tbl_x264_1080}
</div>

<div class="section" id="x264">
  <h2>libx264 编码性能（medium preset）</h2>
  <div class="chart-wrap">{chart_x264}</div>
  <div class="two-col">
    <div>
      <h3>480p 2Mbps 对比</h3>
      {tbl_x264_480}
    </div>
    <div>
      <h3>720p 2Mbps 对比</h3>
      {tbl_x264_720}
    </div>
  </div>
</div>

<div class="section" id="x265">
  <h2>libx265 编码性能（medium preset）</h2>
  <div class="chart-wrap">{chart_x265}</div>
  <h3>1080p 2Mbps 对比</h3>
  {tbl_x265_1080}
</div>

<div class="section" id="vp9">
  <h2>libvpx-vp9 编码性能（good quality）</h2>
  <div class="chart-wrap">{chart_vp9}</div>
</div>

<div class="section" id="decode">
  <h2>解码性能</h2>
  <div class="chart-wrap">{chart_dec}</div>
  <div class="two-col">
    <div>
      <h3>H.264 解码对比</h3>
      {tbl_dec_264}
    </div>
    <div>
      <h3>H.265 解码对比</h3>
      {tbl_dec_265}
    </div>
  </div>
</div>

<div class="section" id="filter">
  <h2>视频滤镜处理性能</h2>
  <div class="chart-wrap">{chart_flt}</div>
</div>

<div class="section" id="threads">
  <h2>线程扩展性（libx264 medium 1080p 2Mbps）</h2>
  <p style="color:#8b949e;font-size:0.88rem;margin-bottom:16px">各内存通道配置下，编码速度随线程数（1→64）的变化趋势</p>
  <div class="chart-wrap">{chart_threads}</div>
  <h3>threads=64 各配置对比</h3>
  {tbl_threads64}
</div>

</body>
</html>'''

with open(OUT, 'w', encoding='utf-8') as f:
    f.write(html)
print(f'Done: {OUT}  ({len(html):,} bytes)')
