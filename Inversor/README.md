# Resumen PWM de Prueba con ESP32

Para la prueba con una senoidal de 50Hz lo que hice fue generar dos señales PWM, comenzando primero por obtener el vector de valores de referencia de la senoidal. 
Para eso tomo una senoidal de amplitud 115 centrada en 127 (de modo que varie entre 0 y 255) y divido el periodo completo en 200 muestras (tamaño del vector). En el void setup se genera este vector:

```
for (int i = 0; i < SAMPLES; i++){
sineTable[i] = (uint8_t)(127.0 + 115.0 * sin(2 * M_PI * i / SAMPLES));  // Escalado a 8 bits
}
```
Si lo graficara se vería así la señal con 200 muestras formando un periodo completo:


Después lo que hice fue configurar dos pines del ESP32 como salidas PWM con una frecuencia de 15KHz, siendo que un pin tiene su salida invertida así las señales son complementarias.
Lo que faltaría es el tiempo muerto, este quedo en 1.3uS pero no se como determinar cual es el mínimo necesario para evitar problemas, es medio mucho pero así me aseguraba no tener cortocircuitos.
Para lograr el tiempo muerto en la configuración de los pines para el PWM a un pin le puse un atraso (`hpoint = 5`) y al otro pin lo que hago es que el ciclo de trabajo sea siempre un poco mas grande.
Así en t0 el canal 1 pasa de alto a bajo mientras el canal 0 sigue en bajo, despues el canal 0 (el que esta atrasado) pasa de bajo a alto. 
Después, como el ciclo de trabajo del canal 1 es mas grande, el canal 0 se va a poner en bajo y despues de un tiempo el canal 1 se pone en alto, así hice andar el tiempo muerto.
