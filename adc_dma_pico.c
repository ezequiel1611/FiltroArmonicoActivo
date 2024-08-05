#include <stdio.h>
#include "pico/stdlib.h"
// For Multi-Core
#include "pico/multicore.h"
// For ADC input:
#include "hardware/adc.h"
#include "hardware/dma.h"
#include "hardware/irq.h"
#include "hardware/gpio.h"

// Channel 0 is GPIO26
#define NUM_CHANNELS 3
#define PARALLEL_PORT_BASE_PIN 2
#define PARALLEL_PORT_LENGTH 8
#define CLOCK_PIN 10

uint8_t adc_value;
uint dma_chan;
dma_channel_config cfg;
uint32_t channel_cont = 0;

void dma_handler() {
    adc_run(false);
    // reinicio el flag de interrupción
    dma_hw->ints0 = 1u << dma_chan;
    // Vacío la lista FIFO del ADC
    adc_fifo_drain();
    // Envío los datos por el puerto
    for(int i = 0; i < PARALLEL_PORT_LENGTH; i++){
        gpio_put(PARALLEL_PORT_BASE_PIN + i, (adc_value >> i) & 0x01);
    }
    // Le digo al otro core que canal lei
    adc_select_input(channel_cont);
    multicore_fifo_push_blocking(channel_cont);
    // voy alternando el canal a leer
    (channel_cont == 2) ? channel_cont=0 : channel_cont++;
    // cambio el estado del clock
    gpio_xor_mask(1u << CLOCK_PIN);
    // Configuro todos los parámetros del canal
    dma_channel_configure(
        dma_chan,       // canal a usar
        &cfg,           // puntero a la configuración del DMA
        &adc_value,     // dirección de escritura inicial (comienzo del vector)
        &adc_hw->fifo,  // dirección de lectura inicial (comienzo de la lista FIFO del ADC)
        1,              // número de transferencias a realizar
        true            // habilito inmediatamente el canal
    );
    adc_run(true);
}

void second_core_code(){
    uint32_t reading_cont = 0;
    while(1){
        reading_cont = multicore_fifo_pop_blocking();
        if(reading_cont == 0){
            printf("%-3d\n", adc_value);
        }
    }
}

int main() {
    stdio_init_all();
    sleep_ms(5000);
    // Inicializo el segundo core
    multicore_launch_core1(second_core_code);
    ////////////////////////////////////////////////////////////////////////////////////////
    printf("Configurando ADC\n");
    // Inicializo los pines para usarlos como analógicos
    //adc_gpio_init(26); Test para usar un canal solo
    for (int i=0;i<NUM_CHANNELS;i++){
        adc_gpio_init(26 + i);
    }
    // Inicializo el ADC
    adc_init();
    // Selecciono el canal del ADC a usar
    adc_select_input(channel_cont);
    // Configuro la lista FIFO del ADC
    adc_fifo_setup(
        true,    // habilito el pasaje de cada conversión completada a la lista
        true,    // habilito el uso de petición de DMA (DREQ) cada vez que la lista tenga datos
        1,       // DREQ se activa cuando hay al menos 1 dato en la lista
        false,   // deshabilito el flag de error.
        true     // convierto cada lectura completa (12 bits), a 8 bits para el DMA
    );
    // Cada conversión demora (1 + n) ciclos de reloj, el divisor mas pequeño válido
    // es n = 95, (96 * 1/48MHz) = 2us -> 500Ksps.
    // Si se coloca un n < 95, se setea la Fs al máximo que es 500Ksps.
    // Para una Fs de 120Ksps se necesita un n = 399, (400 * 1/48MHz) = 8.33us -> 120Ksps
    adc_set_clkdiv(399);
    ///////////////////////////////////////////////////////////////////////////////////////
    printf("Configurando DMA\n");
    sleep_ms(1000);

    // Guardo en dma_chan el canal de DMA libre para usarlo luego
    dma_chan = dma_claim_unused_channel(true);
    // Guardo la configuración inicial del canal libre a usar
    cfg = dma_channel_get_default_config(dma_chan);

    // Establezco el tamaño del bus de datos del DMA para el canal a usar en 8 bits
    channel_config_set_transfer_data_size(&cfg, DMA_SIZE_8);
    // Establezco que NO se incremente el puntero de lectura,
    // para así leer siempre de la misma dirección de memoria
    channel_config_set_read_increment(&cfg, false);
    // Establezco que SI se incremente el puntero de escritura,
    // para así escribir en una dirección de memoria contigua
    channel_config_set_write_increment(&cfg, false);
    // Al leer siempre de la misma dirección de memoria e ir
    // aumentando el puntero de escritura, tengo una lista FIFO

    // Establezco que el acceso a memoria se active cuando haya una petición del ADC
    channel_config_set_dreq(&cfg, DREQ_ADC);

    // Configuro todos los parámetros del canal
    dma_channel_configure(
        dma_chan,       // canal a usar
        &cfg,           // puntero a la configuración del DMA
        &adc_value,     // dirección de escritura inicial (comienzo del vector)
        &adc_hw->fifo,  // dirección de lectura inicial (comienzo de la lista FIFO del ADC)
        1,              // número de transferencias a realizar
        true            // habilito inmediatamente el canal
    );
    ///////////////////////////////////////////////////////////////////////////////////////
    printf("Configurando la Interrupción del DMA\n");
    irq_set_exclusive_handler(DMA_IRQ_0, dma_handler);
    irq_set_enabled(DMA_IRQ_0, true);
    dma_channel_set_irq0_enabled(dma_chan, true);
    ///////////////////////////////////////////////////////////////////////////////////////
    printf("Configurando Puerto Paralelo\n");
    // Configuro los pines GPIO 2-9 como salida
    for (int i = 0; i < PARALLEL_PORT_LENGTH; i++){
        gpio_init(PARALLEL_PORT_BASE_PIN + i);
        gpio_set_dir(PARALLEL_PORT_BASE_PIN + i, GPIO_OUT);
    }
    gpio_init(CLOCK_PIN);
    gpio_set_dir(CLOCK_PIN, GPIO_OUT);
    ///////////////////////////////////////////////////////////////////////////////////////
    printf("Comenzando Lectura\n");
    adc_run(true);
    while (true){
        tight_loop_contents();
    }
}

