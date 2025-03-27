cmake_minimum_required(VERSION 3.13)
include(pico_sdk_import.cmake)

project(adc_dma_pico)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

pico_sdk_init()

add_executable(adc_dma_pico
        adc_dma_pico.c
        parallel_out.pio
        )

pico_generate_pio_header(adc_dma_pico ${CMAKE_CURRENT_LIST_DIR}/parallel_out.pio)

pico_enable_stdio_usb(adc_dma_pico 1)
pico_enable_stdio_uart(adc_dma_pico 0)

target_link_libraries(adc_dma_pico
	pico_stdlib
        pico_multicore
        hardware_pio
        hardware_adc
        hardware_dma
        hardware_irq
        hardware_spi
        hardware_clocks
        )

pico_add_extra_outputs(adc_dma_pico)
