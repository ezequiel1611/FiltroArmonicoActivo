%%
clear all;
close all;
clc;

commandwindow;
%%

% Orden del filtro
cant_coeffs = 30;

% Frecuencia y periodo de muestreo
fs = 3e3;   % fs = 3kHz
ts = 1/fs;

% Tiempo máximo
tmax = 0.4; % Equivale a 20 ciclos de 50 Hz

% Vector de tiempo
t = 0:ts:tmax-ts;

% Vector de tiempo discreto
n = 0:length(t)-1;

% Cantidad de muestras
N = length(n);

% Frecuencia de red
f = 50;

% Señales de referencia (normalizadas)
xn = sin(2*pi*f*n*ts);  % 60 muestras por periodo
zn = cos(2*pi*f*n*ts);  % Señal ortogonal a xn

% Filtro de orden 29 (30 coeficientes)

% Coeficientes del filtro adaptativo (inicialmente en 0)
w0 = zeros(cant_coeffs,1);

% Coeficientes (n+1)
w1 = zeros(cant_coeffs,1);

% Inicialización de señales

% Salida del filtro
y = zeros(1,N);
% Señal de error 
e = zeros(1,N);
% Evolución de los coeficientes
w11 = zeros(cant_coeffs,N);

naux = N/4:N-1; % 3000 muestras y relleno con 0's
iL3 = [zeros(1,N/4) 0.5*cos(3*2*pi*f*naux*ts)]; % 3er armónico
%iL1 = [zeros(1,N/4) sin(2*pi*f*naux*ts)]; % La carga demanda más corriente
naux = N/2:N-1; % 2000 muestras y relleno con 0's
iL5 = [zeros(1,N/2) 0.25*sin(5*2*pi*f*naux*ts)]; % 5to armónico
naux = 3*N/4:N-1; % 1000 muestras y relleno con 0's
iL7 = [zeros(1,3*N/4) 0.1*sin(7*2*pi*f*naux*ts)]; % 7mo armónico

%ruido = randn(size(t)); % Ruido blanco

% Señal de prueba
%iL = sin(2*pi*f*n*ts) + iL1 + iL3 + iL5;% + iL7;% + ruido/(3*max(abs(ruido)));
iL = sin(2*pi*f*n*ts) + iL3 + iL5;% + iL7;% + ruido/(3*max(abs(ruido)));
% Vamos a normalizar la señal de prueba
iL = iL/max(iL);

% Con uMax los coeficientes convergen más rápido al valor final
% Con uMin los coeficientes convergen con mayor precisión al valor final

% Supongamos mantener uMax durante un ciclo de 50 Hz y luego cambiar a uMin

% Con esto no se necesitaría ningún factor de escalamiento

% Con la rápida convergencia los coeficientes son más sensibles a las
% perturbaciones o corrientes armónicas

u = 0.002;
leaky_factor = 0.999;

for i = cant_coeffs:N-1  % 1200 iteraciones

    % Cálculo de la salida
    y(i) = xn(i:-1:i-(cant_coeffs-1)) * w0;
    
    % Calculo el error
    e(i) = iL(i) - y(i);
    
    % Cómputo del valor siguiente de los coeficientes
    w1 = leaky_factor*w0 + 2*u*e(i)*xn(i:-1:i-(cant_coeffs-1))';
    
    % Actualizo los coeficientes para la próxima iteración
    w0 = w1;
    
    % Registra la variacion de los 30 coeficientes en el tiempo
    w11(:,i) = w1;
    
end

%               Calculo la FFT de la entrada
E = fft(iL);
L = length(iL);
P2 = abs(E/L);                       
P1 = P2(2:L/2+1);                
P1(1:end-1) = 2*P1(1:end-1);          
%f = fs*(1:L/2)/L;             

%               Calculo la FFT de la salida
Y = fft(y);
Q2 = abs(Y/L);                        
Q1 = Q2(2:L/2+1);                
Q1(1:end-1) = 2*Q1(1:end-1); 

% %               Cuantización de las señales y coeficientes

% Parámetros para las operaciones en punto fijo
F1 = fimath('ProductMode', 'SpecifyPrecision', 'ProductWordLength', 32,...
 'ProductFractionLength', 30);
F2 = fimath('SumMode', 'SpecifyPrecision', 'SumWordLength', 16,...
 'SumFractionLength', 15);

% 
% Cuantificamos la entrada (A/D de 8 bits)
s = 1;  % Con signo
w = 8;  % Cantidad de bits
f = 7;  % Bits fraccionarios

iLq = fi(iL,s,w,f); % Señal de prueba       S(8,7)
xnq = fi(xn,s,w,f); % Señal de referencia   S(8,7)
znq = fi(zn,s,w,f); % Señal ortogonal       S(8,7)

% Cuantificación de los coeficientes (supongamos S(16,15))

s = 1 ;  % Con signo
w = 16;  % Cantidad de bits
f = 15;  % Bits fraccionarios

w0q = zeros(cant_coeffs,1,'like',fi([],s,w,f));  % S(16,15)
w1q = zeros(cant_coeffs,1,'like',fi([],s,w,f));  % S(16,15)

% Evolución de los coeficientes
w11q = zeros(cant_coeffs,N,'like',fi([],s,w,f));    % S(16,15)

% Salida del filtro
yq = zeros(1,N,'like',fi([],s,w,f));    % S(16,15)

% % Variables para el cálculo de la compensación de la amplitud
% yqaux1 = zeros(1,N,'like',fi([],s,w,f));    % S(16,15)
% yqaux2 = zeros(1,N,'like',fi([],s,w,f));    % S(16,15)
% 
% ycomp = fi(0.7,s,w+1,f); % S(17,15)
% x = fi([],s,w,f); % S(16,15)
% dos = fi(2,s,w,f-1); % S(16,14)

% ------------------------------------------------------------

% Señal de error
eq = ones(1,N,'like',fi([],s,w,f));    % S(16,15)

uq = fi(2*u,s,w,f); % S(16,15)

leaky_factorq = fi(leaky_factor,s,w,f); % S(16,15)


for i = cant_coeffs:N-1 %

    % Cálculo de la salida
    yq(i) = xnq(i:-1:i-(cant_coeffs-1))*w0q;
    yq(i) = cast(yq(i),'like',fi([],1,16,15)); % Mantenemos en S(16,15)
    
       
% %         % Cálculo de la compensación de la amplitud fundamental
%         yqaux1(i) = xnq(i:-1:i-(cant_coeffs-1))*w0q;
%         yqaux2(i) = znq(i:-1:i-(cant_coeffs-1))*w0q;
% 
% 
%         x = yqaux1(i) + yqaux2(i);
% 
%             % Número de iteraciones depende de la precisión de la estimación inicial
%         num_iter = 5;
% 
%         for k = 1:num_iter
%             ycomp = ycomp * (dos - x * ycomp);  % Newton-Raphson iteration
%             ycomp = cast(ycomp,'like',fi([],1,17,15)); % Mantenemos en S(17,14)
%         end
% 
%         yq(i) = yq(i)*ycomp;
%         yq(i) = cast(yq(i),'like',fi([],1,16,15)); % Mantenemos en S(16,15)
        

    % Calculo el error
    eq(i) = iLq(i)-yq(i);
    
    % Cómputo del valor siguiente de los coeficientes
    w1q = leaky_factorq*w0q+uq*eq(i)*xnq(i:-1:i-(cant_coeffs-1))';
    
    w1q = cast(w1q,'like',fi([],1,16,15));  % Mantenemos en S(16,15)
    
    % Actualizo los coeficientes para la próxima iteración
    w0q = w1q;
    
    % Registra la variacion de los 30 coeficientes en el tiempo
    w11q(:,i) = w1q;
   
 end

%               Graficamos la evolución de los coeficientes

figure('Name','Evolución de los coeficientes');
hold on;
for k = 1:(cant_coeffs-1)
    plot(t,w11(k,:),t,w11q.double(k,:),'--','LineWidth', 0.25);
end
hold off;
xlabel('tiempo (s)');
ylabel('Amplitud');
grid on;

%               Graficamos en el dominio de tiempo 

figure('Name','Filtro LMS');

subplot(3,1,2);
plot(t,e,'k',t,eq.double,'g');
legend('Error float','Error fixed');
xlabel('tiempo (s)');
ylabel('Amplitud');
grid on;

subplot(3,1,1);
plot(t,iL,'k',t,iLq.double,'r');
legend('Entrada float','Entrada fixed');
xlabel('tiempo (s)');
ylabel('Amplitud');
grid on;

subplot(3,1,3);
plot(t,y,'k',t,yq.double,'b');
legend('Salida float','Salida fixed');
xlabel('tiempo (s)');
ylabel('Amplitud');
grid on;

%               Calculo la FFT de la entrada
Eq = fft(iLq.double);
L = length(iLq.double);
P2q = abs(Eq/L);                       
P1q = P2q(2:L/2+1);                
P1q(1:end-1) = 2*P1q(1:end-1);          
f = fs*(1:L/2)/L;             

%               Calculo la FFT de la salida
Yq = fft(yq.double);
Q2q = abs(Yq/L);                        
Q1q = Q2q(2:L/2+1);                
Q1q(1:end-1) = 2*Q1q(1:end-1); 

%           Graficamos los espectros de entrada y la salida
figure('Name','Espectro de la entrada vs salida');
plot(f,P1,'k--',f,P1q,'r');
hold on;
plot(f,Q1,'k--',f,Q1q,'b');
hold off;
legend('Entrada float','Entrada fixed','Salida float','Salida fixed');
xlim([0 500]);

xlabel('frecuencia (Hz)');
ylabel('Amplitud [V]');
grid on;

%           Graficamos respuesta en frecuencia

Hz = tf(w0',1,ts);            % Sin cuantizar
Hzq = tf(w0q.double',1,ts);   % Cuantizado

% Respuesta en frecuencia del filtro
w = logspace(0,4,2048);
[mag1, phase1, w1] = bode(Hz, w); 
HzdB=20*log10(mag1(:,:));
[mag2,phase2,w2]=bode(Hzq, w);
HzqdB=20*log10(mag2(:,:));

% Graficamos
figure('Name','Respuesta en frecuencia del filtro adaptativo');
semilogx(w1/(2*pi), HzdB,'k--');
hold on;
semilogx(w2/(2*pi),HzqdB,'b');
xlim([1 fs/2]);
grid on;
ylabel('Magnitud (dB)');
xlabel('Frecuencia (Hz)');
legend('H(z)','Hq(z)');
hold off;
title('Filtro ideal vs real');




% Hay que lograr un THD no mayor al 10% en la corriente

% Calcular la suma de los cuadrados de los armónicos
suma_armonicos_cuadrados = sum(P1(40:20:end).^2); % En P(20) está la fundamental

% Calcular el THD (Total Harmonic Distortion)
THD = sqrt(suma_armonicos_cuadrados) / P1(20);

% Imprimir el valor de THD
fprintf('El THD de la señal de corriente sin filtrar es: %.2f%%\n', THD * 100);

% Calcular la suma de los cuadrados de los armónicos
suma_armonicos_cuadrados = sum(Q1(40:20:end).^2); % En Q(20) está la fundamental

% Calcular el THD (Total Harmonic Distortion)
THD = sqrt(suma_armonicos_cuadrados) / Q1(20);

% Imprimir el valor de THD
fprintf('El THD de la señal de corriente filtrada es: %.2f%%\n', THD * 100);




















