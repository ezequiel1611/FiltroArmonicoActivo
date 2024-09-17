#include <stdio.h>
#include <math.h>
#include "driver/gpio.h"
#include "esp_timer.h"

#define SAMPLE_RATE 10000  // Frecuencia de muestreo (10000 muestras por segundo)
#define FREQUENCY 50       // Frecuencia de la señal senoidal en Hz (50 Hz)
#define GPIO_OUTPUT_MASK ((1ULL << 25) | (1ULL << 26) | (1ULL << 27) | (1ULL << 14) | (1ULL << 12) | (1ULL << 13) | (1ULL << 32) | (1ULL << 33)) // Pines corregidos
#define PI 3.14159265359   // Valor de PI

// Función para calcular y enviar la señal senoidal a los pines GPIO
void output_sine_wave(void* arg) {
    static int sample_number = 0;  // Número de muestra

    // Calcular el valor de la señal senoidal en tiempo real
    float sine_value = sin(2 * PI * FREQUENCY * sample_number / SAMPLE_RATE);

    // Convertir el valor de la señal a 8 bits (rango de 0 a 255)
    uint8_t sine_8bit_value = (uint8_t)((sine_value + 1) * 127.5);

    // Enviar el valor de 8 bits a los pines GPIO
    gpio_set_level(32, (sine_8bit_value >> 7) & 0x01); // Bit 7
    gpio_set_level(33, (sine_8bit_value >> 6) & 0x01); // Bit 6
    gpio_set_level(25, (sine_8bit_value >> 5) & 0x01); // Bit 5
    gpio_set_level(26, (sine_8bit_value >> 4) & 0x01); // Bit 4
    gpio_set_level(27, (sine_8bit_value >> 3) & 0x01); // Bit 3
    gpio_set_level(14, (sine_8bit_value >> 2) & 0x01); // Bit 2
    gpio_set_level(12, (sine_8bit_value >> 1) & 0x01); // Bit 1
    gpio_set_level(13, sine_8bit_value & 0x01);        // Bit 0

    // Incrementar el número de muestra
    sample_number = (sample_number + 1) % SAMPLE_RATE;
}

// Configurar y comenzar el temporizador para generar la señal senoidal
void app_main(void) {
    // Configurar GPIO de salida para los 8 bits
    gpio_config_t io_conf_output = {
        .pin_bit_mask = GPIO_OUTPUT_MASK,
        .mode = GPIO_MODE_OUTPUT,
        .pull_up_en = 0,
        .pull_down_en = 0,
        .intr_type = GPIO_INTR_DISABLE
    };
    gpio_config(&io_conf_output);

    // Crear un temporizador para generar la señal senoidal
    const esp_timer_create_args_t sine_timer_args = {
        .callback = &output_sine_wave,
        .name = "sine_timer"
    };
    esp_timer_handle_t sine_timer;
    esp_timer_create(&sine_timer_args, &sine_timer);

    // Calcular el intervalo del temporizador en microsegundos
    int interval_us = 1000000 / SAMPLE_RATE; // Periodo de muestreo (en microsegundos)

    // Iniciar el temporizador en modo periódico
    esp_timer_start_periodic(sine_timer, interval_us);
}
