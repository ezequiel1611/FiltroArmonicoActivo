#include <stdio.h>
#include <math.h>
#include "driver/gpio.h"
#include "esp_timer.h"

#define SAMPLE_RATE 12000   // Frecuencia de muestreo
#define FREQUENCY_1 100      // Frecuencia de la primera señal senoidal
#define FREQUENCY_2 400      // Frecuencia de la segunda señal senoidal
#define GPIO_OUTPUT_MASK ((1ULL << 25) | (1ULL << 26) | (1ULL << 27) | (1ULL << 14) | (1ULL << 12) | (1ULL << 13) | (1ULL << 32) | (1ULL << 33)) // Pines de salida
#define GPIO_CLOCK_PIN 4    // Pin para recibir el clock
#define PI 3.14159265359    // Valor de PI

// Variable global para almacenar el valor de la señal senoidal
static uint8_t global_sine_value = 0;
static int alternate_signal = 0;  // Alternar entre señales (0 o 1)
static int sample_number = 0;     // Número de muestra
static bool ready_to_update = true; // Señal de que se puede actualizar la señal

// Función para calcular y almacenar la señal senoidal en una variable global
void calculate_sine_wave(void) {
    if (ready_to_update) {
        // Calcular el valor de la señal senoidal alternada
        float sine_value;
        if (alternate_signal == 0) {
            sine_value = sin(2 * PI * FREQUENCY_1 * sample_number / SAMPLE_RATE);  // Señal 1
        } else {
            sine_value = sin(2 * PI * FREQUENCY_2 * sample_number / SAMPLE_RATE);  // Señal 2
        }

        // Convertir el valor de la señal a 8 bits (rango de 0 a 255) y guardarlo en la variable global
        global_sine_value = (uint8_t)((sine_value + 1) * 127.5);

        // Alternar la señal en el siguiente ciclo
        alternate_signal = !alternate_signal;

        // Incrementar el número de muestra
        sample_number = (sample_number + 1) % SAMPLE_RATE;

        // Indicar que ya no estamos listos para actualizar hasta que se procese el dato
        ready_to_update = false;
    }
}

// Función ISR para manejar el flanco ascendente del clock y enviar el valor por paralelo
static void IRAM_ATTR clock_isr_handler(void* arg) {
    // Enviar el valor de 8 bits almacenado en la variable global a los pines GPIO
    gpio_set_level(32, (global_sine_value >> 7) & 0x01); // Bit 7
    gpio_set_level(33, (global_sine_value >> 6) & 0x01); // Bit 6
    gpio_set_level(25, (global_sine_value >> 5) & 0x01); // Bit 5
    gpio_set_level(26, (global_sine_value >> 4) & 0x01); // Bit 4
    gpio_set_level(27, (global_sine_value >> 3) & 0x01); // Bit 3
    gpio_set_level(14, (global_sine_value >> 2) & 0x01); // Bit 2
    gpio_set_level(12, (global_sine_value >> 1) & 0x01); // Bit 1
    gpio_set_level(13, global_sine_value & 0x01);        // Bit 0

    // Ahora que se procesó el dato, permitir la generación de la próxima muestra
    ready_to_update = true;
}

// Configurar los pines y el clock para enviar datos sincronizados
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

    // Configurar GPIO del clock como entrada con interrupción por flanco ascendente
    gpio_config_t io_conf_input = {
        .pin_bit_mask = (1ULL << GPIO_CLOCK_PIN),
        .mode = GPIO_MODE_INPUT,
        .pull_up_en = 1,
        .pull_down_en = 0,
        .intr_type = GPIO_INTR_POSEDGE  // Detectar flanco ascendente
    };
    gpio_config(&io_conf_input);

    // Instalar el servicio de ISR de GPIO
    gpio_install_isr_service(0);
    // Agregar ISR handler para el pin del clock
    gpio_isr_handler_add(GPIO_CLOCK_PIN, clock_isr_handler, NULL);

    // Crear un temporizador para verificar si es necesario calcular la señal senoidal periódicamente
    const esp_timer_create_args_t sine_timer_args = {
        .callback = &calculate_sine_wave,
        .name = "sine_timer"
    };
    esp_timer_handle_t sine_timer;
    esp_timer_create(&sine_timer_args, &sine_timer);

    // Iniciar el temporizador en modo periódico para verificar cada intervalo si se puede calcular una nueva muestra
    esp_timer_start_periodic(sine_timer, 100); // Ajustar el tiempo si es necesario
}
