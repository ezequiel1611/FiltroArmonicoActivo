#include <stdio.h>
#include "pico/stdlib.h"
// For ADC input:
#include "hardware/adc.h"
#include "hardware/dma.h"
#include "hardware/irq.h"
// For Clock synchronization:
#include "hardware/gpio.h"
// For SPI interface:
#include "hardware/spi.h"
// For PIO programming
#include "hardware/pio.h"
#include "parallel_out.pio.h"
#include "hardware/clocks.h"
#include "pico/multicore.h"

// Channel 0 is GPIO26
#define NUM_CHANNELS 2
#define PARALLEL_PORT_BASE_PIN 2    // Puerto paralelo
#define PARALLEL_PORT_LENGTH 8      // pines de 2 a 9
#define CLOCK_PIN 10                // Pin de Clock
#define ENABLE_PIN 11               // Pin para habilitar la comunicación con la FPGA
#define POTE_BASE 20                // Pin flag fin de adj pote 0 (21 es para pote 1)
#define NUM_POTES 2                 // cantidad de potes
#define POTE_BASE_EN 12             // Pin EN de adj pote 0 (12 es para pote 1)

// Pines para SPI
#define SPI_PORT spi0
#define PIN_SCK 18  // Pin de reloj
#define PIN_MOSI 19 // Pin de datos
#define PIN_CS 17   // Pin de chip select
#define MCP42050_CMD_WRITE_POT0 0x11 // Comando para pote 0
#define MCP42050_CMD_WRITE_POT1 0x12 // Comando para pote 1
#define MCP42050_CMD_WRITE_BOTH 0x13 // Comando para los dos potes
#define MCP42050_INIT_VALUE 0x00

uint8_t adc_ch[2] = {0,0};
uint8_t channel_send = 0;
uint8_t adc_value, pote_value = 0;
uint dma_chan;
bool flag_agc;
bool flag_adc = false;
dma_channel_config cfg;
uint32_t channel_cont = 0;
double gain, dn;
static const float pio_freq = 20000000;
PIO pio;
uint state_machine;

void write_fifo_pio() {
    while(1){
        if(pio_sm_is_tx_fifo_empty(pio,state_machine) == true){
            pio_sm_put_blocking(pio, state_machine, adc_ch[0]);
        }
    }
}

void mcp42050_write(uint8_t pot_num, uint8_t value) {
    uint8_t data[2]; // dato a enviar por SPI
    // Selecciono el comando según que pote elijo
    if (pot_num == 0){
        data[0] = MCP42050_CMD_WRITE_POT0; // comando para pote 0
    } else if (pot_num == 1) {
        data[0] = MCP42050_CMD_WRITE_POT1; // comando para pote 1
    } else {
        return;
    }

    data[1] = value; // valor de 0 a 255 para la posición del pivote

    // activo el chip select
    gpio_put(PIN_CS, 0);
    // envio los dos bytes de datos
    spi_write_blocking(SPI_PORT, data, 2);
    // desactivo el chip select
    gpio_put(PIN_CS, 1);
}

void spi_init_config() {
    // Inicializar el puerto SPI
    spi_init(SPI_PORT, 1000000); // baudrate 1MHz
    // Configuro los pines de clock y datos para usar con SPI
    gpio_set_function(PIN_SCK, GPIO_FUNC_SPI);
    gpio_set_function(PIN_MOSI, GPIO_FUNC_SPI);
    // Configuro el pin de chip select como salida
    gpio_init(PIN_CS);
    gpio_set_dir(PIN_CS, GPIO_OUT);
    // Envio un comando inicial para tener ganancia 1 al comienzo
    gpio_put(PIN_CS, 0);
    uint8_t initData[2];
    initData[0] = MCP42050_CMD_WRITE_BOTH;
    initData[1] = MCP42050_INIT_VALUE;
    spi_write_blocking(SPI_PORT, initData, 2);
    gpio_put(PIN_CS, 1);
}

void flag(uint gpio, uint32_t events){
    flag_agc = true;
}

void dma_handler() {
    adc_run(false);
    // reinicio el flag de interrupción
    dma_hw->ints0 = 1u << dma_chan;
    // Vacío la lista FIFO del ADC
    adc_fifo_drain();
    adc_ch[channel_cont] = adc_value;
    // voy alternando el canal a leer
    (channel_cont == (NUM_CHANNELS - 1))? channel_cont=0 : channel_cont++;
    adc_select_input(channel_cont);
    // Configuro todos los parámetros del canal
    dma_channel_configure(
        dma_chan,       // canal a usar
        &cfg,           // puntero a la configuración del DMA
        &adc_value,     // dirección de escritura inicial (comienzo del vector)
        &adc_hw->fifo,  // dirección de lectura inicial (comienzo de la lista FIFO del ADC)
        1,              // número de transferencias a realizar
        true            // habilito inmediatamente el canal
    );
    // pongo en alto la bandera de envio de datos
    flag_adc = true;
    adc_run(true);
}

int main() {
    stdio_init_all();
    gpio_init(ENABLE_PIN);
    gpio_set_dir(ENABLE_PIN, GPIO_OUT);
    gpio_put(ENABLE_PIN, 1);
    sleep_ms(5000);
    ////////////////////////////////////////////////////////////////////////////////////////
    printf("Configurando ADC\n");
    // Inicializo los pines para usarlos como analógicos
    //adc_gpio_init(26); //Test para usar un canal solo
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
    /* 
            Cada conversión demora (1 + n) ciclos de reloj, el divisor mas pequeño válido
            es n = 95, (96 * 1/48MHz) = 2us -> 500Ksps.
            Si se coloca un n < 95, se setea la Fs al máximo que es 500Ksps.
            Para una Fs de 120Ksps se necesita un n = 399, (400 * 1/48MHz) = 8.33us -> 120Ksps 
    */
    adc_set_clkdiv(95); // 799 -> Fs=80Ksps | 1199 -> Fs=40Ksps
    ///////////////////////////////////////////////////////////////////////////////////////
    printf("Configurando DMA\n");

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
    printf("Configurando la interfaz SPI del MCP42050\n");
    spi_init_config();
    ///////////////////////////////////////////////////////////////////////////////////////
    printf("Ajustando Ganancia para máxima resolución\n");
    for (int i = 0; i < NUM_POTES; i++) {
        gpio_init(POTE_BASE_EN + i);
        gpio_set_dir(POTE_BASE_EN + i, GPIO_OUT);
        gpio_put(POTE_BASE_EN + i, 1);
        if(i==0){
            gpio_set_irq_enabled_with_callback(POTE_BASE + i, GPIO_IRQ_EDGE_RISE, true, &flag);
        }
        else{
            gpio_set_irq_enabled_with_callback(POTE_BASE + i, GPIO_IRQ_EDGE_FALL, true, &flag);
        }
        pote_value = 0;
        while(flag_agc == false) {
            pote_value++;
            mcp42050_write(i,pote_value);
            sleep_ms(50);
            printf("Incremento: %d\n",pote_value);
            if(pote_value == 255) {
                flag_agc = true;
            } 
        }
        pote_value = pote_value - 1;
        mcp42050_write(i, pote_value);
        gpio_set_irq_enabled(POTE_BASE + i, GPIO_IRQ_EDGE_RISE, false);
        gpio_put(POTE_BASE_EN + i, 0);
        flag_agc = false;
        dn = (double)pote_value;
        gain = 1.00 + (dn/(256.00-dn));
        printf("Ganancia Canal %d: %2.2f\n",i,gain);
        sleep_ms(500);
    }
    sleep_ms(1000);
    ///////////////////////////////////////////////////////////////////////////////////////
    printf("Configurando PIO\n");
    // Determino que voy a usar la PIO0
    pio = pio0;
    // Asigno una máquina de estado libre a state_machine
    state_machine = pio_claim_unused_sm(pio, true);
    // Cargo el programa en la PIO
    uint offset = pio_add_program(pio, &parallel_out_program);
    // Configuro la máquina de estado
    pio_sm_config c = parallel_out_program_get_default_config(offset);
    float div = (float)clock_get_hz(clk_sys) / pio_freq;
    sm_config_set_clkdiv(&c, div);
    // Configuro los pines para la máquina de estado
    sm_config_set_out_pins(&c, PARALLEL_PORT_BASE_PIN, PARALLEL_PORT_LENGTH);
    for(int i = 0; i < PARALLEL_PORT_LENGTH; i++){
        pio_gpio_init(pio, PARALLEL_PORT_BASE_PIN + i);
    }
    pio_sm_set_consecutive_pindirs(pio, state_machine, PARALLEL_PORT_BASE_PIN, 8, true);
    sm_config_set_sideset_pins(&c, CLOCK_PIN);
    // Inicializo la máquina de estado
    pio_sm_init(pio, state_machine, offset, &c);
    // Habilito la máquina de estado
    pio_sm_set_enabled(pio, state_machine, true);
    ///////////////////////////////////////////////////////////////////////////////////////
    printf("Inicializando 2do Core\n");
    multicore_launch_core1(write_fifo_pio);
    ///////////////////////////////////////////////////////////////////////////////////////
    printf("Comenzando Lectura\n");
    adc_run(true);
    gpio_put(ENABLE_PIN, 0);
    int sample_counter = 0;
    while (true){
        printf("start\n");
        busy_wait_ms(1000);
        do{
            if(channel_cont == 1 && flag_adc == true){
                printf("%-3d\n", adc_ch[0]);
                flag_adc = false;
                sample_counter++;
            }
        } while (sample_counter < 2400);
        sample_counter = 0;
        do{
            if(channel_cont == 0 && flag_adc == true){
                printf("%-3d\n", adc_ch[1]);
                flag_adc = false;
                sample_counter++;
            }
        } while (sample_counter < 2400);
        sample_counter = 0;
    }
}

