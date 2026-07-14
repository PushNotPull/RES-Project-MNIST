import tkinter as tk
from tkinter import font as tkfont
import serial
import serial.tools.list_ports
import numpy as np
from PIL import Image, ImageDraw
import threading
import time

BAUD_RATE   = 115200
CANVAS_SIZE = 280
BRUSH_SIZE  = 18

COM_PORT = ""

def find_basys3_port():
    ports = list(serial.tools.list_ports.comports())
    for p in ports:
        if any(kw in p.description for kw in
               ["Digilent", "USB Serial", "FTDI", "USB UART"]):
            print(f"BASYS3 gefunden: {p.device} ({p.description})")
            return p.device
    if ports:
        print(f"Kein BASYS3 gefunden, nehme: {ports[0].device}")
        return ports[0].device
    return None

class UartTool:
    def __init__(self, root):
        self.root = root
        self.root.title("MNIST Digit Sender -> BASYS3")
        self.root.configure(bg="#1e1e1e")
        self.root.resizable(False, False)

        self.pil_image = Image.new("L", (CANVAS_SIZE, CANVAS_SIZE), color=0)
        self.pil_draw  = ImageDraw.Draw(self.pil_image)

        self.ser = None
        self.port_name = COM_PORT if COM_PORT else find_basys3_port()

        self._build_ui()
        self._connect_serial()

    def _build_ui(self):
        title_font = tkfont.Font(family="Helvetica", size=14, weight="bold")
        tk.Label(self.root, text="Draw a digit (0-9)",
                 bg="#1e1e1e", fg="white", font=title_font).pack(pady=(10,0))

        self.canvas = tk.Canvas(
            self.root,
            width=CANVAS_SIZE, height=CANVAS_SIZE,
            bg="black", cursor="crosshair",
            highlightthickness=2, highlightbackground="#444"
        )
        self.canvas.pack(padx=20, pady=10)

        self.canvas.bind("<B1-Motion>",    self._on_drag)
        self.canvas.bind("<ButtonPress-1>", self._on_drag)

        preview_frame = tk.Frame(self.root, bg="#1e1e1e")
        preview_frame.pack(pady=(0,5))
        tk.Label(preview_frame, text="28x28 preview (what FPGA sees):",
                 bg="#1e1e1e", fg="#888", font=("Helvetica", 9)).pack()
        self.preview = tk.Canvas(preview_frame,
                                  width=112, height=112,
                                  bg="black", highlightthickness=1,
                                  highlightbackground="#444")
        self.preview.pack()

        btn_frame = tk.Frame(self.root, bg="#1e1e1e")
        btn_frame.pack(pady=10)

        self.send_btn = tk.Button(
            btn_frame, text="Send to BASYS3",
            command=self._send,
            bg="#2d5a27", fg="white", font=("Helvetica", 12, "bold"),
            padx=20, pady=8, relief="flat", cursor="hand2"
        )
        self.send_btn.pack(side=tk.LEFT, padx=5)

        tk.Button(
            btn_frame, text="Clear",
            command=self._clear,
            bg="#5a2727", fg="white", font=("Helvetica", 12),
            padx=20, pady=8, relief="flat", cursor="hand2"
        ).pack(side=tk.LEFT, padx=5)

        self.status_var = tk.StringVar(value="Ready.")
        tk.Label(self.root, textvariable=self.status_var,
                 bg="#1e1e1e", fg="#aaa",
                 font=("Helvetica", 10)).pack(pady=(0,5))

        result_frame = tk.Frame(self.root, bg="#1e1e1e")
        result_frame.pack(pady=(0,15))
        tk.Label(result_frame, text="FPGA says:",
                 bg="#1e1e1e", fg="#888",
                 font=("Helvetica", 10)).pack()
        self.result_var = tk.StringVar(value="?")
        tk.Label(result_frame, textvariable=self.result_var,
                 bg="#1e1e1e", fg="#00ff88",
                 font=("Helvetica", 64, "bold")).pack()

        port_text = self.port_name if self.port_name else "kein Port gefunden"
        self.port_label = tk.Label(
            self.root,
            text=f"Port: {port_text}  |  {BAUD_RATE} Baud",
            bg="#1e1e1e", fg="#555", font=("Helvetica", 8)
        )
        self.port_label.pack(pady=(0,10))

    def _connect_serial(self):
        if not self.port_name:
            self.status_var.set("KEIN PORT GEFUNDEN! BASYS3 angeschlossen?")
            return
        try:
            self.ser = serial.Serial(
                self.port_name,
                baudrate=BAUD_RATE,
                timeout=5.0
            )
            self.status_var.set(f"Verbunden: {self.port_name}")
        except serial.SerialException as e:
            self.status_var.set(f"Fehler: {e}")
            self.ser = None

    def _on_drag(self, event):
        x, y = event.x, event.y
        r = BRUSH_SIZE // 2

        self.canvas.create_oval(x-r, y-r, x+r, y+r,
                                 fill="white", outline="white")

        self.pil_draw.ellipse([x-r, y-r, x+r, y+r], fill=255)

        self._update_preview()

    def _update_preview(self):
        small = self.pil_image.resize((28, 28), Image.LANCZOS)
        preview_img = small.resize((112, 112), Image.NEAREST)

        self.tk_preview = tk.PhotoImage(width=112, height=112)
        pixels = list(preview_img.getdata())
        for y in range(112):
            row = []
            for x in range(112):
                v = pixels[y*112 + x]
                row.append(f"#{v:02x}{v:02x}{v:02x}")
            self.tk_preview.put(" ".join(row), to=(0, y))

        self.preview.create_image(0, 0, anchor="nw", image=self.tk_preview)

    def _send(self):
        if self.ser is None or not self.ser.is_open:
            self.status_var.set("Nicht verbunden! Port pruefen.")
            return

        small  = self.pil_image.resize((28, 28), Image.LANCZOS)
        pixels = np.array(small, dtype=np.uint8)

        pixel_bytes = pixels.flatten().tobytes()

        self.status_var.set("Sende 784 Bytes...")
        self.send_btn.config(state="disabled")
        self.root.update()

        def send_thread():
            try:
                self.ser.write(pixel_bytes)
                self.ser.flush()

                self.root.after(0, lambda: self.status_var.set(
                    "Gesendet. Warte auf Antwort vom FPGA..."
                ))

                response = self.ser.read(1)

                if response:
                    digit = response[0]
                    if 0 <= digit <= 9:
                        self.root.after(0, lambda: self.result_var.set(str(digit)))
                        self.root.after(0, lambda: self.status_var.set(
                            f"Fertig! FPGA erkannte: {digit}"
                        ))
                    else:
                        self.root.after(0, lambda: self.status_var.set(
                            f"Unerwartete Antwort: 0x{digit:02X}"
                        ))
                else:
                    self.root.after(0, lambda: self.status_var.set(
                        "Timeout: keine Antwort vom FPGA (5s)"
                    ))

            except serial.SerialException as e:
                self.root.after(0, lambda: self.status_var.set(f"Fehler: {e}"))
            finally:
                self.root.after(0, lambda: self.send_btn.config(state="normal"))

        threading.Thread(target=send_thread, daemon=True).start()

    def _clear(self):
        self.canvas.delete("all")
        self.pil_image = Image.new("L", (CANVAS_SIZE, CANVAS_SIZE), color=0)
        self.pil_draw  = ImageDraw.Draw(self.pil_image)
        self.result_var.set("?")
        self.status_var.set("Geloescht.")
        self.preview.delete("all")

    def __del__(self):
        if self.ser and self.ser.is_open:
            self.ser.close()

if __name__ == "__main__":
    root = tk.Tk()
    app  = UartTool(root)
    root.mainloop()
