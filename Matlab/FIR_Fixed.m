%%
clear all;
close all;
clc;

commandwindow;
%%

% Script basado en:

% https://es.mathworks.com/help/fixedpoint/ug/develop-fixed-point-algorithms.html

% Características del filtro:

% Kaiser Window
% Fpass    500 Hz -> 1dB
% Fstop  1 500 Hz -> 60dB
% Fs    10 000 Hz
% Minimum order   -> 37

% Coeficientes del filtro FIR en punto flotante
b = [-0.000283611803117802 -0.000753933430567960 -0.00109267818007326 -0.000676904125412757 0.00102913830908346 0.00391172007046771 0.00678036976757522 0.00748839541846298 0.00382394758362093 -0.00503140803907895 -0.0171362972540381 -0.0273745241222449 -0.0285901697298935 -0.0141840133189078 0.0187323751527656 0.0670340965254562 0.121399367890124 0.168695206642492 0.196228922643286 0.196228922643286 0.168695206642492 0.121399367890124 0.0670340965254562 0.0187323751527656 -0.0141840133189078 -0.0285901697298935 -0.0273745241222449 -0.0171362972540381 -0.00503140803907895 0.00382394758362093 0.00748839541846298 0.00678036976757522 0.00391172007046771 0.00102913830908346 -0.000676904125412757 -0.00109267818007326 -0.000753933430567960 -0.000283611803117802];

% Cantidad de coeficientes
cant_coeffs = length(b);

% Cantidad de puntos
N = 1024;

% Generamos una señal aleatoria uniforme con altas y bajas frecuencias
s = rng; rng(0,'v5uniform');
x = randn(N,1)';
rng(s); % restore |rng| state

a1 = -1;     % Límite inferior
a2 = 0.99;   % Límite superior (1 no es cuantizable a S(8,7))

% Limitar al rango [a1, a2] para posterior cuantizacion
x = max(a1, min(x, a2)); % Lo limito al rango (-1,1)

% Normalizamos la señal de entrada para posterior cuantificación
%x = x / max(abs(x)); % Lo limito al rango (-1,1)

% Un pulso rectangular como señal de prueba
%x = [ones(1,cant_coeffs) zeros(1,N-cant_coeffs)];

% Inicializamos el vector de salida
y = zeros(1,N);

% Filtramos
for i = cant_coeffs:N-1  %

    % Cálculo de la salida
    y(i) = x(i:-1:i-(cant_coeffs-1)) * b'; % Es la ecuación en diferencias

end

% Cuantificamos la entrada y los coeficientes

% Cuantificamos la entrada (A/D de 8 bits) -> S(8,7)
 s = 1;  % Con signo
% w = 12;  % Cantidad de bits
% f = 11;  % Bits fraccionarios

% Señal de prueba S(8,7)
xq = fi(x,s,8,7);

% Definimos la salida S(8,7)
yq = zeros(1,N,'like',fi([],s,8,7));

% Cuantificación de los coeficientes S(16,15)
bq = fi(b,s,16,15);  % S(16,15)

% Definimos los productos parciales S(8,7)
prod = zeros(1,N,'like',fi([],s,8,7));
% Definimos la suma en S(14,7)
suma = fi(0,s,14,7);


% Filtramos en punto fijo
for i = cant_coeffs:N-1 
    
    % Realizamos los productos parciales
    prod = xq(i:-1:i-(cant_coeffs-1)) .* bq;
    % Mantenemos en S(8,7)
    %prod = cast(prod,'like',fi([],s,8,7));
    
    % Sumamos todos los productos parciales
    suma = sum(prod);
    % Mantenemos en S(14,7)
    %suma = cast(suma,'like',fi([],s,14,7));

    % Cálculo de la salida
    yq(i) = suma;
    
    % Falta ver cómo realiza el truncamiento de los bits
end

% Comparativa Float vs Fixed en frecuencia
figure;
% Vector de frecuencia de N/2 puntos entre 0 y fs/2
f = linspace(0,0.5,N/2);

% Respuestas en frecuencia de E/S en float y fixed
xdouble_response = 20*log10(abs(fft(x))         /N);
xq_response      = 20*log10(abs(fft(double(xq)))/N);
ydouble_response = 20*log10(abs(fft(y))         /N);
yq_response      = 20*log10(abs(fft(double(yq)))/N);


% Bode del filtro sin cuantizar
h = fft(b,N);   % FFT de la ventana del filtro
h = h(1:end/2);
% Bode del filtro cuantizado
hq = fft(double(bq),N); % FFT de la ventana del filtro cuantizado
hq = hq(1:end/2);

% Graficamos todo
plot(f,20*log10(abs(h)));  % H(z)
hold on; 
plot(f,20*log10(abs(hq))); % Hq(z)
plot(f,xdouble_response(1:N/2),'m-',...
    f,xq_response(1:N/2),'g.-',...
    f,ydouble_response(1:N/2),'b-',...
    f,yq_response(1:N/2),'r.-');
ylabel('Magnitude in dB');
xlabel('Normalized Frequency');
legend('Freq response (ideal)','Freq response (coeff quantized)','Float input','Fixed point input','Floating point output','Fixed point output','Location','Best');
title('Magnitude response of Floating-point and Fixed-point results');
hold off;

% Comprobamos con una señal senoidal la atenuacion en la banda de rechazo
% 
% Frecuencia de muestreo
fs = 10e3;
% Periodo de muestreo
ts = 1/fs;
% Frecuencia de prueba (fstop)
f = 1500;
% Tiempo máximo
tmax = 10/f; % 10 periodos de 1.5kHz
% Vector de tiempo
t = 0:ts:tmax-ts;
% Vector de tiempo discreto
n = 0:length(t)-1;
% Cantidad de muestras
N = length(n);
% Generamos entrada
xn = sin(2*pi*f*n*ts);


%Filtramos
yn = zeros(1,N);
for i = cant_coeffs:N-1

    % Cálculo de la salida
    yn(i) = xn(i:-1:i-(cant_coeffs-1)) * b';

end

% Cuantizamos 
% Señal de prueba S(8,7)
xq = fi(xn,s,8,7);
% Definimos la salida S(8,7)
yq = zeros(1,N,'like',fi([],s,8,7));
% Definimos los productos parciales S(8,7)
prod = zeros(1,N,'like',fi([],s,8,7));
% Definimos la suma en S(14,7)
suma = fi(0,s,14,7);

% Filtramos en punto fijo
for i = cant_coeffs:N-1 
    
    % Realizamos los productos parciales
    prod = xq(i:-1:i-(cant_coeffs-1)) .* bq;
    % Mantenemos en S(8,7)
    %prod = cast(prod,'like',fi([],s,8,7));
    
    % Sumamos todos los productos parciales
    suma = sum(prod);
    % Mantenemos en S(14,7)
    %suma = cast(suma,'like',fi([],s,14,7));

    % Cálculo de la salida
    yq(i) = suma;
    
    % Falta ver cómo realiza el truncamiento de los bits
end


% Graficamos en el dominio de tiempo 
figure;
%subplot(3,1,2);
plot(t,xn,'m-',...
     t,xq,'g.-',...
     t,yn,'b-',...
     t,yq,'r.-');
legend('Floating input','Fixed input','Floating output','Fixed output');
xlabel('tiempo (s)');
ylabel('Amplitud');
grid on;
title('Filter response of Floating-point and Fixed-point results');




