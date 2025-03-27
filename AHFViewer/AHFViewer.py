import serial
import matplotlib.pyplot as plt
import matplotlib.animation as animation
import matplotlib.ticker as ticker
from collections import deque
import numpy as np
#import threading
import tkinter as tk
from tkinter import ttk, simpledialog
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
import sys

# Flag de control para la animación
running = True
adjust = False

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
root.geometry(f"{screen_width}x{screen_height}")

# Solicita al usuario que ingrese el puerto serie
root.withdraw() # Oculta la ventana principal
port = simpledialog.askstring("Input","Ingrese el puerto serie:", initialvalue="/dev/ttyACM0")
# Solicita al usuario que ingrese la ganancia del canal 1
gain_ch1 = simpledialog.askfloat("Input","Ingrese la ganancia del canal 1:", initialvalue=1)
# Solicita al ususario que ingrese la ganancia del canal 2
gain_ch2 = simpledialog.askfloat("Input","Ingrese la ganancia del canal 2:", initialvalue=1)

# Configuración del puerto serie
baudrate = 115200
ser = serial.Serial(port, baudrate)

# Restablece la ventana principal después de obtener el puerto
root.deiconify()

# Frecuencia e intervalo de muestreo
sampling_interval_us = 4
sampling_rate_hz = 250000
# Factor de escala para la medición de corriente
scaling_factor = 10
# Cantidad de muestras a usar
samples = 2400

# Formato de la ventana principal
root.title("Filtro Activo de Armónicos - Di Lazzaro, Dollaz, Ubiedo - UTN FRP")
# Crear un frame principal que contendrá todo
main_frame = ttk.Frame(root)
main_frame.pack(fill=tk.BOTH, expand=True)
main_frame.grid_rowconfigure(0, weight=9)  # Fila para gráficos
main_frame.grid_rowconfigure(1, weight=1)  # Fila para controles
main_frame.grid_columnconfigure(0, weight=1)

# Frame para los gráficos
graph_frame = ttk.Frame(main_frame)
graph_frame.grid(row=0, column=0, sticky='nsew')
# Frame para los controles y labels
controls_frame = ttk.Frame(main_frame)
controls_frame.grid(row=1, column=0, sticky='ew', padx=5, pady=5)

label_freq = ttk.Label(controls_frame, text="Frecuencia: -- Hz")
label_freq.pack(side="left", padx=10, pady=5)
label_rms_load = ttk.Label(controls_frame, text="Corriente RMS de Il: -- A")
label_rms_load.pack(side="left", padx=10, pady=5)
label_thd_load = ttk.Label(controls_frame, text="THDi de Il: -- %")
label_thd_load.pack(side="left", padx=10, pady=5)

# Añadir botón para cerrar la aplicación
btn_close = tk.Button(controls_frame, text="Salir", command=close_application, bg="red", fg="white")
btn_close.pack(side="right", padx=10, pady=5)
# Añadir botón para pausar/reanudar la animación
btn_pause = ttk.Button(controls_frame, text="Pausar", command=toggle_animation)
btn_pause.pack(side="right", padx=10, pady=5)

# Configuración del gráfico
fig, [[ch1_time, ch2_time], [ch1_freq, ch2_freq]] = plt.subplots(2, 2)

# Datos para el gráfico de la señal Il en el domino del tiempo
x_data_ch1 = deque(maxlen=samples)
y_data_ch1 = deque(maxlen=samples)
ch1_time.set_xlim(0, 200)
ch1_time.set_ylim(-10,10)
line_time_ch1, = ch1_time.plot([], [])
# Añadir título, etiquetas a los ejes y grilla
ch1_time.set_title("Corriente de Carga Il")
ch1_time.set_xlabel("Tiempo (ms)")
ch1_time.set_ylabel("Corriente (A)")
ch1_time.set_xticks(np.arange(0,201,10)) # Intervalos de 5
ch1_time.grid(True, which='both')

# Datos para el gráfico de la FFT de Il
fft_vals_ch1 = deque(maxlen=samples)
fft_freq_ch1 = deque(maxlen=samples)
ch1_freq.set_xlim(0, 1000)
line_freq_ch1, = ch1_freq.plot([], [])
ch1_freq.set_title("FFT de la Corriente Il")
ch1_freq.set_xlabel("Frecuencia (Hz)")
ch1_freq.set_ylabel("Magnitud")
ch1_freq.set_xticks(np.arange(0, 1001, 100))  # Intervalos de 100
ch1_freq.xaxis.set_minor_locator(ticker.MultipleLocator(50))  # Subdivisiones de 50
ch1_freq.xaxis.set_major_locator(ticker.MultipleLocator(100))  # Divisiones principales de 100
ch1_freq.grid(True, which='both')

# Datos para el gráfico de la señal Ii en el domino del tiempo
x_data_ch2 = deque(maxlen=samples)
y_data_ch2 = deque(maxlen=samples)
ch2_time.set_xlim(0, 200)
ch2_time.set_ylim(-10,10)
line_time_ch2, = ch2_time.plot([], [])
# Añadir título, etiquetas a los ejes y grilla
ch2_time.set_title("Corriente Ii")
ch2_time.set_xlabel("Tiempo (ms)")
ch2_time.set_ylabel("Corriente (A)")
ch2_time.set_xticks(np.arange(0,201,10)) # Intervalos de 5
ch2_time.grid(True, which='both')

# Datos para el gráfico de la FFT de Il
fft_vals_ch2 = deque(maxlen=samples)
fft_freq_ch2 = deque(maxlen=samples)
ch2_freq.set_xlim(0, 1000)
line_freq_ch2, = ch2_freq.plot([], [])
ch2_freq.set_title("FFT de la Corriente Ii")
ch2_freq.set_xlabel("Frecuencia (Hz)")
ch2_freq.set_ylabel("Magnitud")
ch2_freq.set_xticks(np.arange(0, 1001, 100))  # Intervalos de 100
ch2_freq.xaxis.set_minor_locator(ticker.MultipleLocator(50))  # Subdivisiones de 50
ch2_freq.xaxis.set_major_locator(ticker.MultipleLocator(100))  # Divisiones principales de 100
ch2_freq.grid(True, which='both')

# Vectores para calcular el promedio del THDi de las señales Il e Il+Ii
thdi_load = deque(maxlen=10)

# Función para calcular la frecuencia dominante
def calculate_frequency(freqs, mags):
    index = np.argmax(mags)
    f0 = freqs[index]
    #return index
    return f0

# Función para calcular la corriente RMS
def calculate_rms(val):
    rms = np.sqrt(np.mean(np.square(val)))
    return rms

# Función para calcular el THD
def calculate_thd(abs_data):
    sq_sum=0.0
    for r in range(3,20,2):
        sq_sum = sq_sum + (abs_data[r*16])**2.0

    thd = 100.0*((sq_sum**0.5) / abs_data[16])
    return thd

# Función para inicializar los gráficos
def init():
    line_time_ch1.set_data([], [])
    line_freq_ch1.set_data([], [])
    line_time_ch2.set_data([], [])
    line_freq_ch2.set_data([], [])
    return line_time_ch1, line_freq_ch1, line_time_ch2, line_freq_ch2

# Función para actualizar los gráficos
def update(frame):
    global running
    global adjust

    if not running:
        return line_time_ch1, line_freq_ch1, line_time_ch2, line_freq_ch2

    read_data()
    canvas.draw()
    # Actualizo los gráficos temporales
    
    # Corriente Il
    x_vals_ch1 = np.arange(len(x_data_ch1)) * (sampling_interval_us/((baudrate/sampling_rate_hz)*65.35))
    y_vals_ch1 = (np.array(y_data_ch1) * (scaling_factor/gain_ch1))
    zc_index_ch1 = np.where(np.diff(np.sign(y_vals_ch1)))[0]
    if (y_vals_ch1[zc_index_ch1[0]+1] - y_vals_ch1[zc_index_ch1[0]]) > 0:
        y_ch1 = np.array(y_vals_ch1[zc_index_ch1[0]:len(y_vals_ch1)-1])
    else:
        y_ch1 = np.array(y_vals_ch1[zc_index_ch1[1]:len(y_vals_ch1)-1])

    x_ch1 = np.array(x_vals_ch1[0:len(y_ch1)])
    
    # Corriente Ii
    x_vals_ch2 = np.arange(len(x_data_ch2)) * (sampling_interval_us/((baudrate/sampling_rate_hz)*65.35))
    y_vals_ch2 = (np.array(y_data_ch2) * (scaling_factor/gain_ch2))
    zc_index_ch2 = np.where(np.diff(np.sign(y_vals_ch2)))[0]
    if (y_vals_ch2[zc_index_ch2[0]+1] - y_vals_ch2[zc_index_ch2[0]]) > 0:
        y_ch2 = np.array(y_vals_ch2[zc_index_ch2[0]:len(y_vals_ch2)-1])
    else:
        y_ch2 = np.array(y_vals_ch2[zc_index_ch2[1]:len(y_vals_ch2)-1])
    # arreglo para ver bien la señal cuando hay armónicos    
    zc_index_ch2_fix = np.where(np.diff(np.sign(y_ch2)))[0]
    y_ch2_fix = np.array(y_ch2[0:zc_index_ch2_fix[20]+2])
    y_ch2_fix[0] = 0.0
    y_ch2_fix[len(y_ch2_fix)-1] = 0.0
    y_ch2_inverse = np.flip(y_ch2_fix)
    y_ch2_final = y_ch2_inverse - y_ch2_fix
    # definicion de los datos del eje x
    x_ch2 = np.array(x_vals_ch2[0:len(y_ch2_final)])
    
    # Seteo
    line_time_ch1.set_data(x_ch1, y_ch1)
    line_time_ch2.set_data(x_ch2, y_ch2_final)
    # Actualizar los gráficos frecuenciales
    if len(y_data_ch1) > 0 and len(y_data_ch2) > 0:
        # Corriente Il
        fft_vals_ch1 = (np.abs(np.fft.rfft(y_vals_ch1,samples))*2)/(np.sqrt(2)*samples)
        fft_vals_ch1[0] = 0
        fft_freq_ch1 = np.fft.rfftfreq(len(y_vals_ch1), (1/baudrate)*15.36)
        # Corriente Ii
        fft_vals_ch2 = (np.abs(np.fft.rfft(y_vals_ch2,samples))*2)/(np.sqrt(2)*samples)
        fft_vals_ch2[0] = 0
        fft_freq_ch2 = np.fft.rfftfreq(len(y_vals_ch2), (1/baudrate)*15.36)
        # Seteo
        line_freq_ch1.set_data(fft_freq_ch1, fft_vals_ch1)
        line_freq_ch2.set_data(fft_freq_ch2, fft_vals_ch2)
        # La primera vez que se ejecuta la app se ajusta automáticamente los ejes de los gráficos
        if adjust == False:
            # Ajuste Il
            ch1_time.set_xlim(x_ch1[0], x_ch1[800])
            ch1_time.set_ylim(np.min(y_vals_ch1) - 0.3 * np.abs(np.min(y_vals_ch1)), np.max(y_vals_ch1) + 0.3 * np.abs(np.max(y_vals_ch1)))
            ch1_freq.set_ylim(np.min(fft_vals_ch1) - 0.3 * np.abs(np.min(fft_vals_ch1)), np.max(fft_vals_ch1) + 0.3 * np.abs(np.max(fft_vals_ch1)))
            # Ajuste Ii
            ch2_time.set_xlim(x_ch2[0], x_ch2[800])
            ch2_time.set_ylim(np.min(y_ch2_final) - 0.3 * np.abs(np.min(y_ch2_final)), np.max(y_ch2_final) + 0.3 * np.abs(np.max(y_ch2_final)))
            ch2_freq.set_ylim(np.min(fft_vals_ch2) - 0.3 * np.abs(np.min(fft_vals_ch2)), np.max(fft_vals_ch2) + 0.3 * np.abs(np.max(fft_vals_ch2)))
            adjust = True
        # Calcular y mostrar la frecuencia dominante de Il
        dominant_freq = calculate_frequency(fft_freq_ch1, fft_vals_ch1)
        label_freq.config(text=f"Frecuencia: {dominant_freq:.0f} Hz")
        # Calcular y mostrar la corriente RMS de Il
        rms_current_load = calculate_rms(y_vals_ch1)
        label_rms_load.config(text=f"Corriente RMS: {rms_current_load:.2f} A")
        # Calcular y mostrar el THD de la corriente Il
        thdi_load.append(calculate_thd(fft_vals_ch1))
        thdi_array_load = np.array(thdi_load)
        thdi_load_mean = np.mean(thdi_array_load)
        label_thd_load.config(text=f"THD: {thdi_load_mean:.2f} %")


    return line_time_ch1, line_freq_ch1, line_time_ch2, line_freq_ch2

# Función para leer los datos del puerto serie y actualizar los datos de los gráfico
def read_data():
    #toggle_ch = False
    counter = 0
    start_flag = False
    while(start_flag == False):
            line = ser.readline().decode('utf-8').strip()
            if line == "start":
                start_flag = True


    while(counter < 2400):
        line = ser.readline().decode('utf-8').strip()
        value = int(line)
        current = ((value / 255.0) * 3.0) - 1.50
        y_data_ch1.append(current)
        x_data_ch1.append(len(y_data_ch1))
        counter = counter + 1


    counter = 0
    while(counter < 2400):
        line = ser.readline().decode('utf-8').strip()
        value = int(line)
        current = ((value / 255.0) * 3.0) - 1.50
        y_data_ch2.append(current)
        x_data_ch2.append(len(y_data_ch2))
        counter = counter + 1


# Configuración de la animación
ani = animation.FuncAnimation(fig, update, init_func=init, blit=True, interval=1, cache_frame_data=False)

# Integrar los gráficos de matplotlib en Tkinter
canvas = FigureCanvasTkAgg(fig, master=graph_frame)
canvas.get_tk_widget().pack(side=tk.TOP, fill=tk.BOTH, expand=True)
canvas.draw()

root.mainloop()
