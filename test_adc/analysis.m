clear all;
close all;
clc;
commandwindow;

% Cargo los datos
data_tx = load("data_enviada.txt");
% Grafico la señal
figure('Name','Señal Enviada');
subplot(2,1,1);
plot(data_tx);
title('ADC 120Ksps');
xlabel('Muestras');
xlim([0,1000]);
ylabel('Valor ADC');
grid 'on';
% Calculo la FFT
N = length(data_tx);
Y = fft(data_tx);
frecuencias = (0:N-1)*(50)/N;
amplitud = abs(Y/N);
subplot(2,1,2);
plot(frecuencias, amplitud);
title('FFT de la Señal');
xlabel('Frecuencia [Hz]');
xlim([-10,60]);
ylabel('|Y(f)|');
grid 'on';
valor_medio = mean(data_tx);
disp(['Valor Medio: ', num2str(valor_medio)]);

% Cargo los datos
data_rx = load("data_recibida.txt");
% Grafico la señal
figure('Name','Señal Recibida');
subplot(2,1,1);
plot(data_rx);
title('ADC 120Ksps');
xlabel('Muestras');
xlim([0,1000]);
ylabel('Valor ADC');
ylim([0,200]);
grid 'on';
% Calculo la FFT
N = length(data_rx);
Y = fft(data_rx);
frecuencias = (0:N-1)*(50)/N;
amplitud = abs(Y/N);
subplot(2,1,2);
plot(frecuencias, amplitud);
title('FFT de la Señal');
xlabel('Frecuencia [Hz]');
xlim([-10,60]);
ylabel('|Y(f)|');
grid 'on';
valor_medio = mean(data_rx);
disp(['Valor Medio: ', num2str(valor_medio)]);
