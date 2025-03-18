#include <driver/ledc.h>
#include <math.h>

#define PWM_FREQUENCY 15000
#define SINE_FREQUENCY 55
#define SAMPLES 200
#define DEAD_TIME 10

// uint8_t sineTable[SAMPLES] = {127,139,150,162,173,183,193,202,210,217,223,229,233,236,238,239,240,239,238,236,233,230,227,223,219,215,212,208,204,201,198,196,194,192,191,191,190,190,191,192,193,194,195,196,198,199,200,201,201,202,202,202,201,201,200,199,198,196,195,194,193,192,191,190,190,191,191,192,194,196,198,201,204,208,212,215,219,223,227,230,233,236,238,239,240,239,238,236,233,229,223,217,210,202,193,183,173,162,150,139,127,115,104,92,81,71,61,52,44,37,31,25,21,18,16,15,14,15,16,18,21,24,27,31,35,39,42,46,50,53,56,58,60,62,63,63,64,64,63,62,61,60,59,58,56,55,54,53,53,52,52,52,53,53,54,55,56,58,59,60,61,62,63,64,64,63,63,62,60,58,56,53,50,46,42,39,35,31,27,24,21,18,16,15,14,15,16,18,21,25,31,37,44,52,61,71,81,92,104,115};
uint8_t sineTable[SAMPLES];

void setup() {
  // put your setup code here, to run once:
  ledc_timer_config_t ledc_timer = {
    .speed_mode       = LEDC_LOW_SPEED_MODE,
    .duty_resolution  = LEDC_TIMER_8_BIT,
    .timer_num        = LEDC_TIMER_0,
    .freq_hz          = PWM_FREQUENCY,
    .clk_cfg          = LEDC_AUTO_CLK
  };
  ESP_ERROR_CHECK(ledc_timer_config(&ledc_timer));

  uint32_t deadTime = DEAD_TIME; // Large value to show clearly on the oscilloscope

  ledc_channel_config_t ledc_noninverted_channel = {
    .gpio_num       = GPIO_NUM_12,
    .speed_mode     = LEDC_LOW_SPEED_MODE,
    .channel        = LEDC_CHANNEL_0,
    .intr_type      = LEDC_INTR_DISABLE,
    .timer_sel      = LEDC_TIMER_0,
    .duty           = 127-deadTime/2, // Set duty to 50%
    .hpoint         = 5
  };
  ESP_ERROR_CHECK(ledc_channel_config(&ledc_noninverted_channel));

  ledc_channel_config_t ledc_complementary_channel = {
    .gpio_num       = GPIO_NUM_14,
    .speed_mode     = LEDC_LOW_SPEED_MODE,
    .channel        = LEDC_CHANNEL_1,
    .intr_type      = LEDC_INTR_DISABLE,
    .timer_sel      = LEDC_TIMER_0,
    .duty           = 127-deadTime/2, // Set cycle to start just after 50%
    .hpoint         = 0,
  };
  ESP_ERROR_CHECK(ledc_channel_config(&ledc_complementary_channel));

  // Generar tabla de valores senoidales
  for (int i = 0; i < SAMPLES; i++) {
    sineTable[i] = (uint8_t)(127.0 + 115.0 * sin(2 * M_PI * i / SAMPLES));  // Escalado a 8 bits (0-255)
  }

  GPIO.func_out_sel_cfg[GPIO_NUM_14].inv_sel = 1;
}

void loop() {
  // put your main code here, to run repeatedly:
  static int index = 0;
  uint8_t duty = sineTable[index];
  uint8_t duty_low = duty + DEAD_TIME;
  ledc_set_duty(LEDC_LOW_SPEED_MODE, LEDC_CHANNEL_0, duty);
  ledc_update_duty(LEDC_LOW_SPEED_MODE, LEDC_CHANNEL_0);
  ledc_set_duty(LEDC_LOW_SPEED_MODE, LEDC_CHANNEL_1, duty_low);
  ledc_update_duty(LEDC_LOW_SPEED_MODE, LEDC_CHANNEL_1);
  index = (index + 1) % SAMPLES;
  delayMicroseconds(1000000 / (SINE_FREQUENCY * SAMPLES));
}
