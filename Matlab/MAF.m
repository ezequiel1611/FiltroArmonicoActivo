%%
clear all;
close all;
clc;

commandwindow;
%%

fs = 3e3; % fs = 3kHz
ts = 1/fs;

f = 50; % Frecuencia señal 50 Hz
T = 1/50;

tmax = 5*T; % 5 periodos de señal a visualizar

t = 0:ts:tmax-ts; % Vector de tiempo

x = sin(2*pi*f*t) + sin(2*pi*3*f*t+pi) + sin(2*pi*5*f*t); % Señal de prueba

xn = x / max(x); % Normalizamos la señal

N1 = 20; % MAF de orden 20 (filtra 150 Hz)

b1 = (1/N1)*ones(1,N1);

N2 = 12; % MAF de orden 12 (filtra 250 Hz)

b2 = (1/N2)*ones(1,N2);

y1 = filter(b1,1,xn); % Filtramos 3er armónico

y2 = filter(b2,1,y1); % Filtramos 5to armónico

CF = 1.292;

y3 = y2*CF; % Compensamos la atenuación producida en los 50Hz

figure('Name','Respuesta del MAF');
plot(t,xn,'b', 'LineWidth', 0.5);
hold on;
plot(t,y1,'r', 'LineWidth', 1.0);
plot(t,y3,'m', 'LineWidth', 1.5);
hold off;
legend('Entrada','MAF 20','MAF 20 + MAF 12 + compensacion');

xlabel('tiempo (s)');
ylabel('Amplitud');
grid on;

% Respuesta en frecuencia del filtro
H1 = tf(b1,1,ts);
w = logspace(0,5,1000);
[mag1, phase1, w1] = bode(H1, w); 
HzdB1=20*log10(mag1(:,:));
H2 = tf(b2,1,ts);
[mag2, phase2, w2] = bode(H2, w); 
HzdB2=20*log10(mag2(:,:));

HzdB3 = CF*ones(1,length(w));

% Graficamos
figure;
semilogx(w1/(2*pi), HzdB1,'r','LineWidth', 0.5);
hold on;
semilogx(w2/(2*pi),HzdB2,'b','LineWidth', 0.5);
semilogx(w2/(2*pi),HzdB1+HzdB2+HzdB3,'m','LineWidth', 1.5);
xlim([1 1/(2*ts)]);
grid on;
ylabel('Magnitud (dB)');
xlabel('Frecuencia (Hz)');
legend('MAF 20','MAF 12','MAF20 + MAF12 + compensacion');
%hold off;
title('Respuesta en frecuencia del filtro MAF');

%               Calculo la FFT de la entrada
X = fft(xn(1:1+4*60));
L = length(xn(1:1+4*60));
P2 = abs(X/L);                       
P1 = P2(2:L/2+1);                
P1(1:end-1) = 2*P1(1:end-1);          
f = fs*(1:L/2)/L;             

%               Calculo la FFT de la salida compensada
Y = fft(y3(46:46+4*60));
Q2 = abs(Y/L);                        
Q1 = Q2(2:L/2+1);                
Q1(1:end-1) = 2*Q1(1:end-1); 

%           Graficamos los espectros de entrada y la salida
figure;
plot(f,P1,'r');
hold on;
plot(f,Q1,'b');
hold off;
legend('Entrada','Salida compensada');
xlim([0 fs/2]);

xlabel('frecuencia (Hz)');
ylabel('Amplitud [V]');
grid on;




