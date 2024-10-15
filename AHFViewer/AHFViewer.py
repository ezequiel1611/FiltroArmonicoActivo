import serial
import matplotlib.pyplot as plt
import matplotlib.animation as animation
import matplotlib.ticker as ticker
from matplotlib.ticker import MaxNLocator
from collections import deque
import numpy as np
import threading
import tkinter as tk
from tkinter import ttk, simpledialog
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
import sys

# Flag de control para la animación
running = True

# Función para pausar/reanudar la animación
def toggle_animation():
    global running
    if running:
        ani.event_source.stop()
        btn_pause.config(text="Reanudar")
    else:
        ani.event_source.start()
        btn_pause.config(text="Pausar")
    running = not running

# Función para cerrar la aplicación
def close_application():
    root.quit()
    sys.exit()

# Ventana de Tkinter
root = tk.Tk()
# Obtener las dimensiones de la pantalla
screen_width = root.winfo_screenwidth()
screen_height = root.winfo_screenheight()
# Configurar el tamaño a la mitad de la pantalla
root.geometry(f"{screen_width//2}x{screen_height}")

# Solicita al usuario que ingrese el puerto serie
root.withdraw() # Oculta la ventana principal
port = simpledialog.askstring("Input","Ingrese el puerto serie:", initialvalue="/dev/ttyACM0")
# Solicita al usuario que ingrese la ganancia usada
gain = simpledialog.askfloat("Input","Ingrese la ganancia:", initialvalue=1)

# Configuración del puerto serie
baudrate = 115200
ser = serial.Serial(port, baudrate)

# Restablece la ventana principal después de obtener el puerto
root.deiconify()

# Frecuencia e intervalo de muestreo
sampling_interval_us = 25
sampling_rate_hz = 40000
# Factor de escala para la medición de corriente
scaling_factor = 10
# Cantidad de muestras a usar
samples = 2400

# Formato de la ventana principal
root.title("Filtro Activo de Armónicos - Di Lazzaro, Dollaz, Ubiedo - UTN FRP")
frame = ttk.Frame(root)
frame.pack(side=tk.TOP, fill=tk.BOTH, expand=True)
label_freq = ttk.Label(root, text="Frecuencia: -- Hz")
label_freq.pack(side="left", padx=10, pady=5)
label_rms = ttk.Label(root, text="Corriente RMS: -- V")
label_rms.pack(side="left", padx=10, pady=5)
label_thd = ttk.Label(root, text="THD: -- %")
label_thd.pack(side="left", padx=10, pady=5)

# Añadir botón para cerrar la aplicación
btn_close = tk.Button(root, text="Salir", command=close_application, bg="red", fg="white")
btn_close.pack(side="right", padx=10, pady=5)
# Añadir botón para pausar/reanudar la animación
btn_pause = ttk.Button(root, text="Pausar", command=toggle_animation)
btn_pause.pack(side="right", padx=10, pady=5)

# Configuración del gráfico
fig, (ax_time, ax_freq) = plt.subplots(2, 1)

# Datos para el gráfico de la señal en el domino del tiempo
x_data = deque(maxlen=samples)
y_data = deque(maxlen=samples)
ax_time.set_xlim(0, 200)
ax_time.set_ylim(-10,10)
line_time, = ax_time.plot([], [])
# Añadir título, etiquetas a los ejes y grilla
ax_time.set_title("Corriente de Entrada")
ax_time.set_xlabel("Tiempo (ms)")
ax_time.set_ylabel("Corriente (A)")
ax_time.set_xticks(np.arange(0,201,10)) # Intervalos de 5
ax_time.grid(True, which='both')

# Datos para el gráfico de la FFT
fft_vals = deque(maxlen=samples)
fft_freqs = deque(maxlen=samples)
ax_freq.set_xlim(0, 1000)
line_freq, = ax_freq.plot([], [])
ax_freq.set_title("FFT de la Corriente de Entrada")
ax_freq.set_xlabel("Frecuencia (Hz)")
ax_freq.set_ylabel("Magnitud")
ax_freq.set_xticks(np.arange(0, 1001, 100))  # Intervalos de 100
ax_freq.xaxis.set_minor_locator(ticker.MultipleLocator(50))  # Subdivisiones de 50
ax_freq.xaxis.set_major_locator(ticker.MultipleLocator(100))  # Divisiones principales de 100
ax_freq.grid(True, which='both')

# Función para calcular la frecuencia dominante
def calculate_frequency(freqs, mags):
    f0 = freqs[np.argmax(mags)]
    return f0

# Función para calcular la corriente RMS
def calculate_rms(val):
    rms = np.sqrt(np.mean(np.square(val)))
    return rms

# Función para calcular el THD
def calculate_thd(abs_data):
    sq_sum=0.0
    for r in range( len(abs_data)):
       sq_sum = sq_sum + (abs_data[r])**2

    sq_harmonics = sq_sum -(max(abs_data))**2.0
    thd = sq_harmonics**0.5 / max(abs_data)

    return thd

# Función para inicializar los gráficos
def init():
    line_time.set_data([], [])
    line_freq.set_data([], [])
    return line_time, line_freq

# Función para actualizar los gráficos
def update(frame):
    if not running:
        return line_time, line_freq
    
    # Actualizar el gráfico temporal
    canvas.draw()
    x_vals = np.arange(len(x_data)) * (sampling_interval_us/((baudrate/sampling_rate_hz)*100))
    y_vals = (np.array(y_data) * (scaling_factor/gain))
    line_time.set_data(x_vals, y_vals)
    # Actualizar el gráfico frecuencial
    if len(y_data) > 0:
        fft_vals = (np.abs(np.fft.rfft(y_vals,samples))*2)/(np.sqrt(2)*samples)
        fft_freq = np.fft.rfftfreq(samples, (1/baudrate)*10)
        line_freq.set_data(fft_freq, fft_vals)
        ax_time.set_ylim(np.min(y_vals) - 0.3 * np.abs(np.min(y_vals)), np.max(y_vals) + 0.3 * np.abs(np.max(y_vals)))
        ax_freq.set_ylim(np.min(fft_vals) - 0.3 * np.abs(np.min(fft_vals)), np.max(fft_vals) + 0.3 * np.abs(np.max(fft_vals)))
        # Calcular y mostrar la frecuencia dominante
        dominant_freq = calculate_frequency(fft_freq, fft_vals)
        label_freq.config(text=f"Frecuencia: {dominant_freq:.2f} Hz")
        # Calcular y mostrar la corriente RMS
        rms_current = calculate_rms(y_vals)
        #line_current = rms_current * scaling_factor
        label_rms.config(text=f"Corriente RMS: {rms_current:.2f} A")
        # Calcular y mostrar el THD de la corriente
        thd_current = calculate_thd(fft_vals)
        label_thd.config(text=f"THD: {thd_current:.2f} %")
    
    return line_time, line_freq

# Función para leer los datos del puerto serie y actualizar los datos de los gráfico
def read_data():
    while True:
        try:
            line = ser.readline().decode('utf-8').strip()
            value = int(line)
            current = ((value / 255.0) * 3.3) - 1.5
            y_data.append(current)
            x_data.append(len(y_data))
        except Exception as e:
            print(f"Error reading data: {e}")

# Crear un hilo para leer los datos del puerto serie
data_thread = threading.Thread(target=read_data)
data_thread.daemon = True
data_thread.start()

# Configuración de la animación
ani = animation.FuncAnimation(fig, update, init_func=init, blit=True, interval=50)

# Integrar los gráficos de matplotlib en Tkinter
canvas = FigureCanvasTkAgg(fig, master=frame)
canvas.get_tk_widget().pack(side=tk.TOP, fill=tk.BOTH, expand=True)
canvas.draw()

root.mainloop()
