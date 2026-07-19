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
BRUSH_SIZE  = 20

GRAYSCALE_BIAS_THRESHOLD = 50

COM_PORT = ""

def find_basys3_port():
    ports = list(serial.tools.list_ports.comports())
    for p in ports:
        if any(kw in p.description for kw in
               ["Digilent", "USB Serial", "FTDI", "USB UART"]):
            print(f"BASYS3 gefunden: {p.device} ({p.description})"
                  )
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

        self.canvas.bind("<B1-Motion>", self._on_drag)
        self.canvas.bind("<ButtonRelease-1>", self._on_release)
        self.canvas.bind("<ButtonPress-1>", self._on_release)
                
        self.canvas.config(cursor="none") # Invisible Cursor
        self.canvas.bind("<Motion>", self._update_cursor_preview) # added
        # hier
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
        
        ##############################################
        # Slider
        ##############################################
        self.brush_size = tk.IntVar(value=BRUSH_SIZE)

        slider_frame = tk.Frame(self.root, bg="#1e1e1e")
        slider_frame.pack(pady=5)

        tk.Label(slider_frame, text="Brush Size: ", bg="#1e1e1e", fg="#aaa", font=("Helvetica", 9)).pack(side=tk.LEFT, padx=5)

        tk.Scale(
            slider_frame,
            showvalue=False,
            from_=5, to=80,
            orient=tk.HORIZONTAL,
            variable=self.brush_size,
            bg="#1e1e1e", fg="white", highlightthickness=0,
            troughcolor="#444", sliderrelief="flat"
        ).pack(side=tk.LEFT)

        ##############################################
        # Buttons
        ##############################################
        self.send_btn = tk.Button(
            btn_frame, text="Send to BASYS3",
            command=self._send,
            bg="#2d5a27", fg="white", font=("Helvetica", 12, "bold"),
            padx=20, pady=8, relief="flat", cursor="hand2"
        )
        self.send_btn.pack(side=tk.LEFT, padx=5)

        # Red Clear Button
        tk.Button(
            btn_frame, text="Clear",
            command=self._clear,
            bg="#c92828", fg="white", font=("Helvetica", 12),
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

    def _update_cursor_preview(self, event):
        self.canvas.delete("preview") # Delete old ring
        cursor_size = self.brush_size.get()/1.5

        self.canvas.create_oval(
            event.x - cursor_size, event.y - cursor_size,
            event.x + cursor_size, event.y + cursor_size,
            outline="#888", width=1, tags="preview"
        )

    def _on_drag(self, event):
        size = self.brush_size.get()
        x, y = event.x, event.y
        r = size // 2

        self.canvas.create_oval(x-r, y-r, x+r, y+r,
                                 fill="#FFFFFF", outline="#ffffff")

        self.pil_draw.ellipse([event.x-r, event.y-r, event.x+r, event.y+r], fill=255)

        self._update_cursor_preview(event) # New cursor
        #self._update_preview(event)
    
    def _on_release(self, event):
        self._update_preview(self)

    def _update_preview(self, event):
        # LANCZOS
        small = self.pil_image.convert('L')
        # every pixel > GRAYSCALE_BIAS_THRESHOLD --> 255 (white), else 0 (black)
        small = small.point(lambda p: 255 if p > GRAYSCALE_BIAS_THRESHOLD else 0)
        small = small.resize((28, 28), Image.BOX)

        # 50 % resize 255 / 2 = ~ 127
        small = small.point(lambda p: 255 if p > 127 else 0)

        # Preview Image, resized for GUI
        preview_img = small.resize((112, 112), Image.NEAREST)
        self.tk_preview = tk.PhotoImage(width=112, height=112)
        
        data = []
        # Changed for version control
        pixels = np.array(preview_img).flatten().tolist()
        #pixels = (np.array(preview_img) > 0).astype(int).flatten().tolist()
        for y in range(112):
            # List Comprehension, iterate from 0 to 112-1
            # grayscale to Hex value for ex. 255 --> ff
            # Mult with 3 for ex. 0a *3 = 0a0a0a
            row = ["#" + f"{pixels[y*112+x]:02x}"*3 for x in range(112)]
            data.append("{" + " ".join(row) + "}")

        self.tk_preview.put(" ".join(data), to=(0, 0))
        
        # Refresh canvas
        self.preview.delete("all")
        self.preview.create_image(0, 0, anchor="nw", image=self.tk_preview)

    def _send(self):
        if self.ser is None or not self.ser.is_open:
            self.status_var.set("Nicht verbunden! Port pruefen.")
            return

        # Resize to 28x28, grayscale
        small  = self.pil_image.resize((28, 28), Image.BILINEAR).convert('L')
        
        small = small.point(lambda p: 255 if p > GRAYSCALE_BIAS_THRESHOLD else 0)
        
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
