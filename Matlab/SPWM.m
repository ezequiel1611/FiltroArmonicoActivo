%%
clear all;
close all;
clc;

commandwindow;
%%

%  NECESITAS MINIMO 30 MUESTRAS POR PERIODO DE LA SEÑAL TRIANGULAR
%  PORTADORA PARA GENERAR UNA RESPUESTA ACEPTABLE.
%  ADEMAS, LA FRECUENCIA DE LA PORTADORA DEBE SER 10 VECES EL ARMONICO MAS
%  ALTO QUE SE DESEE ELIMINAR DE LA FUNDAMENTAL DE 50 HZ.

% SI LA SEÑAL PORTADORA ES 20 KHZ ENTONCES EL ARMONICO MAS GRANDE QUE SE
% PUEDA REPRESENTAR POR SPWM ES DE 2KHZ

% Frecuencia y periodo de muestreo
fs = 45e3;
ts = 1/fs;

% Tiempo máximo
tmax = 5*0.02; % Segundos

% Vector de tiempo
t = 0:ts:tmax-ts;

% Vector de tiempo discreto
n = 0:length(t)-1;

% Cantidad de muestras
N = length(n);

% Frecuencia de red
f = 50;
% 3er armónico
f3 = 150;

% Señal moduladora
x = sin(2*pi*f*n*ts) - 0.5*cos(2*pi*f3*n*ts);  % 200 muestras por periodo (fundamental)

x = x / max(x);

% La señal portadora tendrá p = 5 -> fp = 10 * f3 = 1500 Hz

% Definir parámetros
Ap = 1;   % Amplitud de la señal triangular
fp = 1500; % Frecuencia señal triangular
tp = 1/fp;    % Período de la señal triangular
duty = 0.5;     % Ciclo de trabajo (puede variar entre 0 y 1)

% Generar señal triangular
portadora = Ap * sawtooth(2*pi*1/tp*n*ts, duty);

% Graficar la señal triangular
plot(t, portadora);
hold on;
plot(t,x);
plot(t,-x,'-');
hold off;
title('Señal Triangular');
xlabel('Tiempo');
ylabel('Amplitud');

g1 = zeros(1,N);
g4 = zeros(1,N);
g  = zeros(1,N);

for i = 1:N % Realiza 4000 iteraciones
       
    if portadora(i)<=x(i)
        
        g1(i) = 1;
        
    else
        
        g1(i) = 0;
        
    end
    
    if portadora(i)<=(-x(i))
        
        g4(i) = 1;
        
    else
        
        g4(i) = 0;
        
    end
    
    g(i) = g1(i)-g4(i);
    
end

% Filtro de segundo orden

b = [1 2 1];
a = [1 -1.901343793847117 0.9059866816089611];

K = 0.001160721940461;

% H = tf(K*b,a,ts);
% 
% figure;
% bode(H);

% Filtramos g

g_filtered = filter(K*b,a,g);

%               Calculo la FFT de la entrada
X = fft(g);
L = length(g);
P2 = abs(X/L);                       
P1 = P2(2:L/2+1);                
P1(1:end-1) = 2*P1(1:end-1);          
f = fs*(1:L/2)/L;             

%               Calculo la FFT de la salida
Y = fft(g_filtered);
Q2 = abs(Y/L);                        
Q1 = Q2(2:L/2+1);                
Q1(1:end-1) = 2*Q1(1:end-1); 

%           Graficamos los espectros de entrada y la salida
figure;
stem(f,P1,'r','.');
hold on;
stem(f,Q1,'b','.');
hold off;
legend('Entrada','Salida');
xlim([0 fs/2]);

xlabel('frecuencia (Hz)');
ylabel('Amplitud [V]');
grid on;

%               Graficamos en el dominio de tiempo 

figure('Name','SPWM');
subplot(2,1,1);
plot(t,x,'r', 'LineWidth', 0.5);
grid on;
legend('Entrada');
subplot(2,1,2);
plot(t,g_filtered,'b', 'LineWidth', 0.5);
legend('Salida');
xlabel('tiempo (s)');
ylabel('Amplitud');
grid on;







