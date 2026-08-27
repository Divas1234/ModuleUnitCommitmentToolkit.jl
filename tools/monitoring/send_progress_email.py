"""
PCM Benchmark Detailed Progress Monitor & Email Notifier
--------------------------------------------------------
Automatically collects comprehensive benchmark progress, metrics, solver logs,
and system resource stats, formats a rich engineering HTML report, and dispatches
it to 1570364925@qq.com via SMTP.
Active window: 08:00 to 22:00 (every 3 hours: 08:00, 11:00, 14:00, 17:00, 20:00).
"""

import os
import re
import sys
import glob
import json
import ssl
import smtplib
import datetime
import subprocess
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from pathlib import Path

RECIPIENT_EMAIL = "1570364925@qq.com"
PROJECT_ROOT = Path(__file__).resolve().parents[2]
CONFIG_FILE = PROJECT_ROOT / "tools" / "monitoring" / "email_config.json"


def is_in_active_window() -> bool:
    """Check if current time is within active broadcast hours (08:00 - 22:00)."""
    now = datetime.datetime.now().time()
    start_time = datetime.time(8, 0, 0)
    end_time = datetime.time(22, 0, 0)
    return start_time <= now <= end_time


def load_smtp_config():
    default_config = {
        "smtp_server": "smtp.qq.com",
        "smtp_port": 465,
        "use_ssl": True,
        "sender_email": "1570364925@qq.com",
        "sender_password": "zedxnxmyyooxgcah",
    }
    if CONFIG_FILE.exists():
        try:
            with open(CONFIG_FILE, "r", encoding="utf-8") as f:
                cfg = json.load(f)
                default_config.update(cfg)
        except Exception:
            pass
    return default_config


def get_process_summary():
    """Extract detailed status for Julia and Gurobi solver processes."""
    processes = []
    try:
        cmd = 'Get-Process julia, gurobi* -ErrorAction SilentlyContinue | Select-Object Id, ProcessName, CPU, WorkingSet64 | ConvertTo-Json'
        res = subprocess.run(["powershell", "-NoProfile", "-Command", cmd], capture_output=True, text=True)
        if res.stdout.strip():
            data = json.loads(res.stdout)
            if isinstance(data, dict):
                data = [data]
            for p in data:
                cpu_sec = float(p.get("CPU", 0) or 0)
                mem_mb = float(p.get("WorkingSet64", 0) or 0) / (1024 * 1024)
                processes.append({
                    "id": p.get("Id"),
                    "name": p.get("ProcessName"),
                    "cpu_hours": f"{cpu_sec / 3600:.2f} 核·时",
                    "mem_mb": f"{mem_mb:.1f} MB",
                })
    except Exception as e:
        print(f"Process check error: {e}")
    return processes


def parse_task_details(label: str, root_dir: Path, scale_desc: str):
    """Parse complete metrics, intermediate progress, and latest solver actions."""
    task_info = {
        "label": label,
        "scale_desc": scale_desc,
        "dir_name": root_dir.name if root_dir.exists() else "Not Found",
        "status": "进行中",
        "last_update": "无数据",
        "completed_items": [],
        "running_item": "空闲 / 全部完成",
        "solver_details": "",
        "summary_table": [],
        "tail_log": "",
    }

    if not root_dir.exists():
        task_info["status"] = "未启动"
        return task_info

    # 1. Parse comparison.csv if exists
    comp_file = root_dir / "comparison.csv"
    if comp_file.exists():
        try:
            with open(comp_file, "r", encoding="utf-8", errors="ignore") as f:
                lines = f.readlines()
                if len(lines) > 1:
                    headers = [h.strip() for h in lines[0].split(",")]
                    for l in lines[1:]:
                        cols = [c.strip() for c in l.split(",")]
                        if len(cols) >= 6:
                            task_info["summary_table"].append(dict(zip(headers, cols)))
        except Exception:
            pass

    # 2. Find all metrics.csv
    metrics_files = sorted(list(root_dir.glob("*/*/metrics.csv")))
    for mf in metrics_files:
        try:
            parts = mf.relative_to(root_dir).parts
            prof, meth = parts[0], parts[1]
            with open(mf, "r", encoding="utf-8", errors="ignore") as f:
                content = f.read()
                status_match = re.search(r",([^,]+),gurobi,", content)
                status_str = status_match.group(1) if status_match else "OK"
                cost_match = re.search(r",([0-9\.]+e\+[0-9]+|[0-9\.]+),([^,]*)$", content.strip())
                cost_val = f"{float(cost_match.group(1)):,.2f}" if cost_match and float(cost_match.group(1)) > 0 else "-"
                task_info["completed_items"].append({
                    "profile": prof,
                    "method": meth,
                    "status": status_str,
                    "cost": cost_val,
                })
        except Exception:
            pass

    # 3. Check latest run.log
    log_files = list(root_dir.glob("*/*/run.log"))
    if log_files:
        latest_log = max(log_files, key=lambda p: p.stat().st_mtime)
        mtime = datetime.datetime.fromtimestamp(latest_log.stat().st_mtime)
        task_info["last_update"] = mtime.strftime("%Y-%m-%d %H:%M:%S")
        
        parts = latest_log.relative_to(root_dir).parts
        task_info["running_item"] = f"{parts[0]} 场景 / {parts[1]} 方法"
        
        try:
            with open(latest_log, "r", encoding="utf-8", errors="ignore") as f:
                log_lines = f.readlines()
                task_info["tail_log"] = "".join(log_lines[-6:]) if log_lines else ""
                
                # Extract solver solve_time and relative_gap
                full_text = "".join(log_lines[-200:])
                times = re.findall(r"solve_time \(sec\)\s+:\s+([0-9\.e\+\-]+)", full_text)
                gaps = re.findall(r"relative_gap\s+:\s+([0-9\.e\+\-]+)", full_text)
                objs = re.findall(r"objective_value\s+:\s+([0-9\.e\+\-]+)", full_text)
                if times and gaps:
                    last_time = float(times[-1])
                    last_gap = float(gaps[-1]) * 100
                    last_obj = float(objs[-1]) if objs else 0.0
                    task_info["solver_details"] = (
                        f"最新子问题耗时: {last_time:.1f}s ({last_time/60:.1f}min) | "
                        f"MIP Gap: {last_gap:.3f}% | 目标值: {last_obj:,.0f}"
                    )
        except Exception:
            pass

    return task_info


def collect_all_tasks():
    tasks = []
    
    # 1. 108 机组 72h (已完成基准)
    h72_108_dirs = sorted(glob.glob(str(PROJECT_ROOT / "output" / "pcm_com4_loadall_h72_20260822_092947")), reverse=True)
    if h72_108_dirs:
        tasks.append(parse_task_details("118母线 / 108机组 72h 算例", Path(h72_108_dirs[0]), "3个滚动区间 (3×24h)，4方案×3场景共12组"))

    # 2. 1080 机组 72h (后台进行中)
    h72_1080_dirs = sorted(glob.glob(str(PROJECT_ROOT / "output" / "pcm_com4_loadall_h72_20260822_094655")), reverse=True)
    if h72_1080_dirs:
        tasks.append(parse_task_details("118母线 / 1080机组 (10x规模) 72h 算例", Path(h72_1080_dirs[0]), "超大规模 1080 台机组全时域 MILP 滚动调度"))

    # 3. 108 机组 168h (Worktree 已完成基准)
    wt_dirs = sorted(glob.glob(str(PROJECT_ROOT / ".worktrees" / "108_168h" / "output" / "pcm_com4_loadall_h168_*")), reverse=True)
    if wt_dirs:
        tasks.append(parse_task_details("118母线 / 108机组 168h (周级) 算例", Path(wt_dirs[0]), "7个滚动区间 (7×24h=168h)，周级全周期调度"))

    # 4. 1080 机组 168h (Worktree 进行中)
    wt_1080_dirs = sorted(glob.glob(str(PROJECT_ROOT / ".worktrees" / "1080_168h" / "output" / "pcm_com4_loadall_h168_*")), reverse=True)
    if wt_1080_dirs:
        tasks.append(parse_task_details("118母线 / 1080机组 (10x规模) 168h (周级) 算例", Path(wt_1080_dirs[0]), "7个滚动区间 (7×24h=168h)，超大规模1080机组周级全周期调度"))

    return tasks


def generate_html_email(processes, tasks):
    now_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    # Process table rows
    proc_html = ""
    for p in processes:
        proc_html += f"""
        <tr style="border-bottom: 1px solid #e2e8f0;">
            <td style="padding: 10px; font-family: monospace;">{p['id']}</td>
            <td style="padding: 10px; font-weight: bold; color: #2b6cb0;">{p['name']}</td>
            <td style="padding: 10px; color: #c53030; font-weight: bold;">{p['cpu_hours']}</td>
            <td style="padding: 10px;">{p['mem_mb']}</td>
        </tr>
        """
    if not proc_html:
        proc_html = "<tr><td colspan='4' style='padding: 12px; text-align: center; color: #a0aec0;'>暂无活跃求解器进程</td></tr>"

    # Tasks HTML cards
    cards_html = ""
    for t in tasks:
        # Completed items tags
        items_html = ""
        if t["completed_items"]:
            for it in t["completed_items"]:
                badge_bg = "#c6f6d5" if it["status"] in ("OK", "100.0", "SUCCESS") else "#fed7d7"
                badge_color = "#22543d" if it["status"] in ("OK", "100.0", "SUCCESS") else "#742a2a"
                items_html += f"""
                <span style="display: inline-block; background: {badge_bg}; color: {badge_color}; padding: 3px 8px; border-radius: 4px; margin: 3px; font-size: 12px;">
                    <b>{it['profile']}/{it['method']}</b>: {it['status']} (成本: {it['cost']})
                </span>
                """
        else:
            items_html = "<span style='color: #a0aec0; font-size: 13px;'>正在计算首个子算例中...</span>"

        solver_box = ""
        if t["solver_details"]:
            solver_box = f"""
            <div style="background: #edf2f7; border-left: 4px solid #3182ce; padding: 8px 12px; margin: 8px 0; border-radius: 0 4px 4px 0; font-size: 13px; color: #2d3748;">
                ⚙️ <b>求解器实时遥测：</b> {t['solver_details']}
            </div>
            """

        log_box = ""
        if t["tail_log"]:
            safe_log = t["tail_log"].replace("<", "&lt;").replace(">", "&gt;").replace("\n", "<br>")
            log_box = f"""
            <div style="margin-top: 10px; background: #1a202c; color: #cbd5e0; padding: 10px 12px; border-radius: 6px; font-family: Consolas, monospace; font-size: 11px; line-height: 1.5; overflow-x: auto;">
                <b>最新计算日志截选：</b><br>{safe_log}
            </div>
            """

        cards_html += f"""
        <div style="background: #ffffff; border: 1px solid #cbd5e0; border-radius: 10px; padding: 18px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.02);">
            <div style="display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #e2e8f0; padding-bottom: 10px; margin-bottom: 12px;">
                <h3 style="margin: 0; color: #1a365d; font-size: 16px;">📌 {t['label']}</h3>
            </div>
            <p style="margin: 4px 0; font-size: 13px; color: #4a5568;"><b>算例规模描述：</b>{t['scale_desc']}</p>
            <p style="margin: 4px 0; font-size: 13px; color: #4a5568;"><b>目录标识：</b><code>{t['dir_name']}</code></p>
            <p style="margin: 4px 0; font-size: 13px; color: #4a5568;"><b>最近落盘时间：</b><span style="color: #2b6cb0; font-weight: bold;">{t['last_update']}</span></p>
            <p style="margin: 6px 0; font-size: 13px;"><b>当前推进阶段：</b><span style="background: #bee3f8; color: #2c5282; padding: 3px 10px; border-radius: 4px; font-weight: bold;">{t['running_item']}</span></p>
            
            {solver_box}
            
            <div style="margin: 10px 0 6px 0;">
                <b style="font-size: 13px; color: #4a5568;">已归档子算例：</b><br>
                <div style="margin-top: 4px;">{items_html}</div>
            </div>
            {log_box}
        </div>
        """

    html = f"""
    <!DOCTYPE html>
    <html>
    <head><meta charset="utf-8"></head>
    <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f7fafc; padding: 20px; color: #2d3748; margin: 0;">
        <div style="max-width: 780px; margin: 0 auto; background: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 10px rgba(0,0,0,0.06); border: 1px solid #e2e8f0;">
            
            <!-- Header -->
            <div style="background: linear-gradient(135deg, #1e3a8a 0%, #3b82f6 100%); color: white; padding: 26px 30px;">
                <h1 style="margin: 0; font-size: 22px; letter-spacing: 0.5px;">⚡ ModuleUnitCommitment 自动化基准测试进度看板</h1>
                <p style="margin: 8px 0 0 0; opacity: 0.9; font-size: 13px;">播报时间：{now_str} ｜ 定时频率：每日 08:00 - 22:00 (每 3 小时一次)</p>
            </div>

            <div style="padding: 24px 30px;">
                
                <!-- System Processes -->
                <div style="margin-bottom: 24px;">
                    <h3 style="margin-top: 0; color: #2d3748; font-size: 15px; border-left: 4px solid #3182ce; padding-left: 8px;">🖥️ 计算引擎活跃度与求解负载</h3>
                    <table style="width: 100%; border-collapse: collapse; text-align: left; font-size: 13px; margin-top: 8px; background: #f8fafc; border-radius: 6px; overflow: hidden; border: 1px solid #e2e8f0;">
                        <thead>
                            <tr style="background: #edf2f7; color: #4a5568;">
                                <th style="padding: 10px;">PID</th>
                                <th style="padding: 10px;">进程名称</th>
                                <th style="padding: 10px;">CPU 累计算力耗时</th>
                                <th style="padding: 10px;">内存使用</th>
                            </tr>
                        </thead>
                        <tbody>
                            {proc_html}
                        </tbody>
                    </table>
                </div>

                <!-- Tasks Details -->
                <div>
                    <h3 style="color: #2d3748; font-size: 15px; border-left: 4px solid #38a169; padding-left: 8px; margin-bottom: 12px;">📊 算例执行全景与细分进度</h3>
                    {cards_html}
                </div>

                <!-- Footer -->
                <div style="margin-top: 28px; padding-top: 16px; border-top: 1px solid #e2e8f0; color: #718096; font-size: 12px; line-height: 1.6; text-align: center;">
                    💡 <b>工作流说明：</b> 本邮件由工程监控定时任务自动生成。夜间 22:00 至次日 08:00 自动暂停播报。<br>
                    若需临时获取最新进度，可随时在命令行执行 <code>python tools/monitoring/send_progress_email.py --force</code>。
                </div>

            </div>
        </div>
    </body>
    </html>
    """
    return html


def send_email(subject: str, html_body: str, cfg: dict, recipient: str):
    sender = cfg.get("sender_email")
    password = cfg.get("sender_password")
    
    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = f"PCM Benchmark Monitor <{sender}>"
    msg["To"] = recipient
    msg.attach(MIMEText(html_body, "html", "utf-8"))

    endpoints = [
        ("183.47.101.192", 465, True, False),
        ("smtp.qq.com", 465, True, True),
        ("14.18.245.164", 465, True, False),
    ]

    for host, port, use_ssl_conn, verify_host in endpoints:
        try:
            ctx = ssl.create_default_context()
            if not verify_host:
                ctx.check_hostname = False
                ctx.verify_mode = ssl.CERT_NONE

            if use_ssl_conn:
                with smtplib.SMTP_SSL(host, port, context=ctx, timeout=15) as server:
                    server.login(sender, password)
                    server.sendmail(sender, recipient, msg.as_string())
            else:
                with smtplib.SMTP(host, port, timeout=15) as server:
                    server.starttls(context=ctx)
                    server.login(sender, password)
                    server.sendmail(sender, recipient, msg.as_string())

            print(f"[{datetime.datetime.now()}] SUCCESS: Email successfully sent to {recipient} (via {host}:{port})")
            return True
        except Exception as e:
            print(f"Endpoint {host}:{port} attempt failed: {e}")

    print("All SMTP endpoints failed.")
    return False


def main(force: bool = False):
    if not force and not is_in_active_window():
        print(f"[{datetime.datetime.now()}] Outside active hours (08:00-22:00). Skipping email.")
        return

    print(f"[{datetime.datetime.now()}] Collecting comprehensive PCM progress report...")
    processes = get_process_summary()
    tasks = collect_all_tasks()
    html_content = generate_html_email(processes, tasks)

    cfg = load_smtp_config()
    subject = f"【PCM计算进度看板】{datetime.datetime.now().strftime('%m-%d %H:%M')} 运行状态"
    send_email(subject, html_content, cfg, RECIPIENT_EMAIL)


if __name__ == "__main__":
    force_flag = "--force" in sys.argv
    main(force=force_flag)
