%% Vamos ahora a utilizar el dataset del dron 
%Este dron se mueve entre los edificios de la ciudad de zurich

%% Extraemos los datos del excel 
%Recordemos que los datos provienen de un disco duro, y por tanto este
%deberá estar conectado mientras se ejecute este script. 

%% =========================================================================
%% 1. EXTRACCIÓN Y PREPARACIÓN DE DATOS - ZURICH MAV DATASET
%% =========================================================================
clear; clc; close all;

% 1. DEFINIR RUTA DE LA CARPETA
% ¡Importante! Cambia esto por la ruta real donde tienes la carpeta 'Log Files'
carpetaData = 'D:\Universidad\4º_Año_de_verdad\TFG\Dataset con datos reales (dron Zúrich)\AGZ\AGZ\Log Files';

%% 2. LECTURA A PRUEBA DE BALAS (Evitando el problema del delimitador)
fprintf('Cargando archivos CSV crudos (esto puede tardar unos segundos)... \n');

% Forzamos a MATLAB a leer las comas y respetar los nombres de las cabeceras
opts = {'Delimiter', ',', 'VariableNamingRule', 'preserve'};

tabla_gps   = readtable(fullfile(carpetaData, 'OnboardGPS.csv'), opts{:});
tabla_accel = readtable(fullfile(carpetaData, 'RawAccel.csv'), opts{:});
tabla_gyro  = readtable(fullfile(carpetaData, 'RawGyro.csv'), opts{:});
tabla_gt    = readtable(fullfile(carpetaData, 'GroundTruthAGL.csv'), opts{:});

fprintf('¡Carga completada con éxito!\n\n');

%% 3. ALINEACIÓN TEMPORAL (El cronómetro maestro)
% Buscamos quién empezó a grabar primero para poner el t=0 ahí
t0_absoluto = min([tabla_gps.Timpstemp(1), tabla_accel.Timpstemp(1), tabla_gyro.Timpstemp(1)]);

% Pasamos de microsegundos a segundos reales, ya que en la web nos pone que
% The first column of every file contains the timestamp when the data was 
% recorded expressed in microseconds.
t_gps   = (tabla_gps.Timpstemp - t0_absoluto) / 1e6;
t_accel = (tabla_accel.Timpstemp - t0_absoluto) / 1e6;
t_gyro  = (tabla_gyro.Timpstemp - t0_absoluto) / 1e6;

%% 4. EXTRACCIÓN DE VARIABLES FÍSICAS

% --- IMU: Aceleraciones puras (m/s^2) ---
a_x = tabla_accel.x;
a_y = tabla_accel.y;
a_z = tabla_accel.z;

% --- IMU: Velocidades angulares puras (rad/s) ---
w_x = tabla_gyro.x;
w_y = tabla_gyro.y;
w_z = tabla_gyro.z;

% --- GPS: Posición y Velocidades Absolutas ---
% Aplicamos los factores de escala que especificaba el readme.txt
gps_lat = tabla_gps.lat / 1e7; % Grados
gps_lon = tabla_gps.lon / 1e7; % Grados
gps_alt = tabla_gps.alt / 1e3; % Metros

v_gps_norte = tabla_gps.vel_n_m_s;
v_gps_este  = tabla_gps.vel_e_m_s;
v_gps_abajo = tabla_gps.vel_d_m_s;

% --- GROUND TRUTH: La trayectoria real (Para comprobar luego) ---
gt_x = tabla_gt.x_gt;
gt_y = tabla_gt.y_gt;
gt_z = tabla_gt.z_gt;

%% 5. COMPROBACIÓN VISUAL RÁPIDA
figure(1);
plot(t_accel, a_z, 'g', 'DisplayName', 'Aceleración Z (IMU)');
hold on;
stem(t_gps, v_gps_abajo, 'b', 'Marker', 'o', 'DisplayName', 'Velocidad Z (GPS)');
xlabel('Tiempo de vuelo (s)');
ylabel('Magnitud');
title('Comprobación de la carga de datos (Asincronía)');
legend('Location', 'best');
grid on;

%% =========================================================================
% 2. INICIALIZACIÓN DEL EKF 3D (9 ESTADOS)
% =========================================================================

% Definimos la gravedad en el sistema NED (Tira hacia abajo, que es el eje +Z)
g = 9.81;
gravedad_n = [0; 0; g]; 

% Estado inicial: [pN, pE, pD, vN, vE, vD, phi, theta, psi]
% Usamos el primer dato del GPS y del Ground Truth para anclar el inicio
x_est = zeros(9,1);
x_est(1:3) = [gt_x(1); gt_y(1); gt_z(1)];
x_est(4:6) = [v_gps_norte(1); v_gps_este(1); v_gps_abajo(1)];
% Asumimos que arranca plano (Roll=0, Pitch=0) y alineado al norte (Yaw=0)
% En un entorno hiperrealista, inicializaríamos esto con las primeras lecturas de la IMU
x_est(7:9) = [0; 0; 0]; 

% Preparación del histórico
num_muestras = length(t_accel);
hist_pos = zeros(3, num_muestras);
hist_pos(:,1) = x_est(1:3);

%% =========================================================================
% 3. BUCLE MAESTRO: FASE DE PREDICCIÓN (MOTOR INERCIAL)
% =========================================================================
fprintf('Ejecutando integración inercial ciega... \n');

for k = 2:num_muestras

    % 1. Calculamos el dt dinámico
    dt = t_accel(k) - t_accel(k-1);

    % 2. Lecturas crudas de la IMU en este instante (Body Frame)
    a_b = [a_x(k); a_y(k); a_z(k)];
    w_b = [w_x(k); w_y(k); w_z(k)];

    % Extraemos variables del estado anterior para que sea más legible
    p_prev = x_est(1:3);
    v_prev = x_est(4:6);
    phi    = x_est(7); % Roll
    theta  = x_est(8); % Pitch
    psi    = x_est(9); % Yaw

    % 3. Matriz de Rotación de Cuerpo a Navegación (R_b_n)
    % Usamos la convención aeroespacial Z-Y-X (Yaw-Pitch-Roll)
    R_b_n = [cos(theta)*cos(psi), sin(phi)*sin(theta)*cos(psi)-cos(phi)*sin(psi), cos(phi)*sin(theta)*cos(psi)+sin(phi)*sin(psi);
        cos(theta)*sin(psi), sin(phi)*sin(theta)*sin(psi)+cos(phi)*cos(psi), cos(phi)*sin(theta)*sin(psi)-sin(phi)*cos(psi);
        -sin(theta),         sin(phi)*cos(theta),                            cos(phi)*cos(theta)];

    % 4. Proyección y RESTA DE LA GRAVEDAD
    % a_n es la aceleración de movimiento real respecto al mapa
    a_n = R_b_n * a_b - gravedad_n;

    % 5. Integración Cinemática (Predecimos el futuro)
    x_pred = zeros(9,1);
    x_pred(1:3) = p_prev + v_prev * dt + 0.5 * a_n * dt^2; % Nueva Posición
    x_pred(4:6) = v_prev + a_n * dt;                       % Nueva Velocidad

    % Para la actitud, sumamos directamente la velocidad angular
    % (Nota de rigor: Esto es una simplificación válida para ángulos pequeños. 
    % En drones de acrobacias se integran Cuaterniones).
    x_pred(7:9) = x_est(7:9) + w_b * dt;                   

    % [AQUÍ IRÁ EL JACOBIANO Y LA CORRECCIÓN DEL GPS LUEGO]

    % Por ahora, forzamos que el estado estimado sea la predicción (Vuelo a ciegas)
    x_est = x_pred;

    % Guardamos para dibujar
    hist_pos(:, k) = x_est(1:3);
end

%% 4. REPRESENTACIÓN: EL DESASTRE DE LA DERIVA 3D
figure(2);
plot3(gt_x, gt_y, gt_z, 'b--', 'LineWidth', 1.5, 'DisplayName', 'Ruta Real (Ground Truth)');
hold on;
plot3(hist_pos(1,:), hist_pos(2,:), hist_pos(3,:), 'r-', 'LineWidth', 1.5, 'DisplayName', 'Navegación Inercial Pura');
grid on; axis equal; view(3);
xlabel('Norte (m)'); ylabel('Este (m)'); zlabel('Abajo (m)');
title('Por qué necesitamos a Kalman: La Deriva en 3D');
legend('Location', 'best');

