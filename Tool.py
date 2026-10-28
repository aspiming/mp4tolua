import tkinter as tk
from tkinter import filedialog, messagebox
import subprocess
import os
import threading

# 获取当前脚本所在的绝对路径
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))

def browse_file():
    filepath = filedialog.askopenfilename(filetypes=[("MP4 Video", "*.mp4")])
    if filepath:
        entry_video.delete(0, tk.END)
        entry_video.insert(0, filepath)

def generate_lua():
    video_path = entry_video.get()
    start_time = entry_start.get()
    duration = entry_duration.get()
    width = entry_width.get()
    height = entry_height.get()
    fps = entry_fps.get()
    color_scheme = combo_color.get()

    if not os.path.exists(video_path):
        messagebox.showerror("错误", "找不到视频文件！")
        return

    try:
        WIDTH, HEIGHT = int(width), int(height)
        FPS = int(fps)
        MAX_SECONDS = float(duration)
        START_TIME = float(start_time)
        QUANTIZE = int(color_scheme.split(" ")[0])
    except ValueError:
        messagebox.showerror("错误", "请输入正确的数字！")
        return

    btn_generate.config(state=tk.DISABLED, text="正在生成中，请稍候...")
    log_text.delete(1.0, tk.END)
    log_text.insert(tk.END, "1. 正在调用 FFmpeg 提取视频帧...\n")

    def run_task():
        try:
            # 强制使用绝对路径，避免工作目录不一致导致报错
            temp_rgb = os.path.join(CURRENT_DIR, "temp_raw.rgb")
            
            # 格式化时间，防止 FFmpeg 不认浮点数
            start_str = "{:.3f}".format(START_TIME)
            dur_str = "{:.3f}".format(MAX_SECONDS)

            # 运行 FFmpeg
            cmd = [
                "ffmpeg", "-y", "-ss", start_str, "-t", dur_str,
                "-i", video_path, "-vf", f"fps={FPS},scale={WIDTH}:{HEIGHT}",
                "-f", "rawvideo", "-pix_fmt", "rgb24", temp_rgb
            ]
            
            # 捕获输出以便排错
            result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            
            if result.returncode != 0:
                err_msg = result.stderr.decode('utf-8', errors='ignore')
                raise Exception(f"FFmpeg 运行失败！错误信息:\n{err_msg}")
            
            log_text.insert(tk.END, "2. FFmpeg 提取完成，正在合并色块并生成 Lua 数据...\n")
            
            # 读取二进制并生成 Lua
            with open(temp_rgb, "rb") as f:
                raw = f.read()
            if os.path.exists(temp_rgb):
                os.remove(temp_rgb) # 删除临时文件

            FRAME_SIZE = WIDTH * HEIGHT * 3
            total_frames = min(len(raw) // FRAME_SIZE, int(MAX_SECONDS * FPS))
            
            color_dict = {}
            color_list = []
            frames_data = []

            for frame_idx in range(total_frames):
                pixels = []
                offset = frame_idx * FRAME_SIZE
                for i in range(WIDTH * HEIGHT):
                    idx = offset + i * 3
                    r, g, b = raw[idx], raw[idx+1], raw[idx+2]
                    qr = (r // QUANTIZE) * QUANTIZE + (QUANTIZE//2)
                    qg = (g // QUANTIZE) * QUANTIZE + (QUANTIZE//2)
                    qb = (b // QUANTIZE) * QUANTIZE + (QUANTIZE//2)
                    rgb_key = (qr, qg, qb)
                    
                    if rgb_key not in color_dict:
                        color_dict[rgb_key] = len(color_list) + 1
                        color_list.append(rgb_key)
                    pixels.append(color_dict[rgb_key])

                # 2D 合并
                visited = [False] * (WIDTH * HEIGHT)
                rects = []
                for y in range(HEIGHT):
                    for x in range(WIDTH):
                        idx = y * WIDTH + x
                        if visited[idx]: continue
                        c_idx = pixels[idx]
                        w = 1
                        while x + w < WIDTH and pixels[y * WIDTH + x + w] == c_idx and not visited[y * WIDTH + x + w]:
                            w += 1
                        h = 1
                        while y + h < HEIGHT:
                            match = True
                            for i in range(w):
                                if pixels[(y + h) * WIDTH + x + i] != c_idx or visited[(y + h) * WIDTH + x + i]:
                                    match = False
                                    break
                            if match: h += 1
                            else: break
                        for dy in range(h):
                            for dx in range(w):
                                visited[(y + dy) * WIDTH + x + dx] = True
                        rects.extend([x, y, w, h, c_idx])
                frames_data.append(rects)

            log_text.insert(tk.END, f"3. 处理完毕！共 {total_frames} 帧，正在保存文件...\n")

            lua_output_path = os.path.join(CURRENT_DIR, "GridData.lua")
            with open(lua_output_path, "w") as out:
                out.write("return{width=" + str(WIDTH) + ",height=" + str(HEIGHT) + ",total_frames=" + str(total_frames) + ",\n")
                out.write("palette={")
                for c in color_list:
                    out.write("Color.FromRGB(%d,%d,%d)," % c)
                out.write("},\n")
                out.write("frames={\n")
                for rects in frames_data:
                    out.write("{" + ",".join(str(v) for v in rects) + "},\n")
                out.write("}}")

            log_text.insert(tk.END, f"✅ 成功！GridData.lua 已生成在: {CURRENT_DIR}\n")
            messagebox.showinfo("完成", "GridData.lua 生成成功！")
        except Exception as e:
            log_text.insert(tk.END, f"❌ 发生错误:\n{str(e)}\n")
        finally:
            btn_generate.config(state=tk.NORMAL, text="开始生成 GridData.lua")

    threading.Thread(target=run_task).start()

# --- 界面构建 ---
root = tk.Tk()
root.title("视频转 Lua 像素数据工具")
root.geometry("600x550")

tk.Label(root, text="MP4 视频路径:").pack(pady=5)
frame_vid = tk.Frame(root)
frame_vid.pack()
entry_video = tk.Entry(frame_vid, width=60)
entry_video.pack(side=tk.LEFT)
tk.Button(frame_vid, text="浏览", command=browse_file).pack(side=tk.LEFT, padx=5)

frame_params = tk.Frame(root)
frame_params.pack(pady=10)

tk.Label(frame_params, text="开始时间(秒):").grid(row=0, column=0, padx=5)
entry_start = tk.Entry(frame_params, width=10)
entry_start.insert(0, "0")
entry_start.grid(row=0, column=1)

tk.Label(frame_params, text="时长(秒):").grid(row=0, column=2, padx=5)
entry_duration = tk.Entry(frame_params, width=10)
entry_duration.insert(0, "17.3")
entry_duration.grid(row=0, column=3)

tk.Label(frame_params, text="宽度:").grid(row=1, column=0, padx=5)
entry_width = tk.Entry(frame_params, width=10)
entry_width.insert(0, "192")
entry_width.grid(row=1, column=1)

tk.Label(frame_params, text="高度:").grid(row=1, column=2, padx=5)
entry_height = tk.Entry(frame_params, width=10)
entry_height.insert(0, "108")
entry_height.grid(row=1, column=3)

tk.Label(frame_params, text="帧率:").grid(row=2, column=0, padx=5)
entry_fps = tk.Entry(frame_params, width=10)
entry_fps.insert(0, "12")
entry_fps.grid(row=2, column=1)

tk.Label(frame_params, text="取色方案:").grid(row=2, column=2, padx=5)
combo_color = tk.StringVar(value="24 (过渡自然)")
tk.OptionMenu(frame_params, combo_color, "16 (颜色较少，体积最小)", "24 (过渡自然)", "32 (颜色多，体积稍大)").grid(row=2, column=3)

btn_generate = tk.Button(root, text="开始生成 GridData.lua", font=("", 12, "bold"), bg="lightblue", command=generate_lua)
btn_generate.pack(pady=10)

log_text = tk.Text(root, height=12, width=75, fg="black")
log_text.pack()

root.mainloop()