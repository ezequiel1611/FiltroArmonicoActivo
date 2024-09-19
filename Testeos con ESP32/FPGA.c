#include <stdio.h>
#include "driver/dac.h"
#include "driver/gpio.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

#define SAMPLE_RATE 6000 // Frecuencia de muestreo en Hz (6 kHz)
#define GPIO_OUTPUT_PIN 5 // Nuevo pin GPIO de salida (para clock de 6 kHz)
#define GPIO_INPUT_MASK ((1ULL << 16) | (1ULL << 17) | (1ULL << 27) | (1ULL << 14) | (1ULL << 12) | (1ULL << 13) | (1ULL << 32) | (1ULL << 33)) // Máscara de los 8 pines de entrada

static bool toggle_signal = false; // Variable para alternar entre las dos señales

// Función para generar la señal y actualizar los DAC1 y DAC2
void SALIDA(void* arg) {
    // Activar GPIO (Clock de 6 kHz)
    gpio_set_level(GPIO_OUTPUT_PIN, 1);

    // Mantener la señal en alto por la mitad del periodo (83.33 us para 6 kHz)
    ets_delay_us(40);  //(1.000.000*1/4*1/SAMPLE_RATE) Uso de ets_delay_us para mayor precisión

    // Leer datos de 8 bits de los pines asignados
    uint8_t data_8bits = 0;
    data_8bits |= gpio_get_level(16) << 7; // Leer el bit más significativo
    data_8bits |= gpio_get_level(17) << 6;
    data_8bits |= gpio_get_level(32) << 5;
    data_8bits |= gpio_get_level(33) << 4;
    data_8bits |= gpio_get_level(27) << 3;
    data_8bits |= gpio_get_level(14) << 2;
    data_8bits |= gpio_get_level(12) << 1;
    data_8bits |= gpio_get_level(13);      // Leer el bit menos significativo

    // Alternar entre las dos señales
    if (toggle_signal) {
        dac_output_voltage(DAC_CHANNEL_1, data_8bits);  // Enviar señal al DAC1 (GPIO25)
    } else {
        dac_output_voltage(DAC_CHANNEL_2, data_8bits);  // Enviar señal al DAC2 (GPIO26)
    }

    toggle_signal = !toggle_signal;  // Cambiar la señal para la próxima vez

    // Mantener la señal en alto por la mitad del periodo (83.33 us para 6 kHz)
    ets_delay_us(40);  // Uso de ets_delay_us para mayor precisión

    // Desactivar GPIO (Clock)
    gpio_set_level(GPIO_OUTPUT_PIN, 0);
}

// Configurar y comenzar los temporizadores para cada señal
void app_main(void) {
    // Inicializar los DACs
    dac_output_enable(DAC_CHANNEL_1); // DAC1 (GPIO25)
    dac_output_enable(DAC_CHANNEL_2); // DAC2 (GPIO26)

    // Configurar GPIO de salida para el clock
    gpio_config_t io_conf_output = {
        .pin_bit_mask = (1ULL << GPIO_OUTPUT_PIN),
        .mode = GPIO_MODE_OUTPUT,
        .pull_up_en = 0,
        .pull_down_en = 0,
        .intr_type = GPIO_INTR_DISABLE
    };
    gpio_config(&io_conf_output);

    // Configurar GPIO de entrada para los 8 bits
    gpio_config_t io_conf_input = {
        .pin_bit_mask = GPIO_INPUT_MASK,
        .mode = GPIO_MODE_INPUT,
        .pull_up_en = 1,  // Habilitar pull-up para asegurar lectura estable
        .pull_down_en = 0,
        .intr_type = GPIO_INTR_DISABLE
    };
    gpio_config(&io_conf_input);

    // Crear un temporizador para la señal
    const esp_timer_create_args_t FPGA_timer_args = {
        .callback = &SALIDA,
        .name = "FPGA_timer"
    };
    esp_timer_handle_t FPGA_timer;
    esp_timer_create(&FPGA_timer_args, &FPGA_timer);
    esp_timer_start_periodic(FPGA_timer, 1000000 / SAMPLE_RATE); // Periodo en microsegundos (6 kHz)
}
