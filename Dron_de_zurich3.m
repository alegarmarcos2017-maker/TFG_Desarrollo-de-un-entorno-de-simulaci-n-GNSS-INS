%% =========================================================================
% TFG: NÚCLEO DEL FILTRO EKF (VERSIÓN DEFINITIVA SÍNCRONA Y FÍSICA REAL)
% =========================================================================
clear; clc; close all;

carpetaData = 'D:\Universidad\4º_Año_de_verdad\TFG\Dataset con datos reales (dron Zúrich)\AGZ\AGZ\Log Files';

fprintf('Cargando datos...\n');
opts = {'Delimiter', ',', 'VariableNamingRule', 'preserve'};

tabla_gps   = readtable(fullfile(carpetaData, 'OnboardGPS.csv'), opts{:});
tabla_accel = readtable(fullfile(carpetaData, 'RawAccel.csv'), opts{:});
tabla_gyro  = readtable(fullfile(carpetaData, 'RawGyro.csv'), opts{:});
tabla_gt    = readtable(fullfile(carpetaData, 'GroundTruthAGL.csv'), opts{:});

% --- LA CLAVE: ALINEACIÓN ABSOLUTA (Para no desincronizar los sensores) ---
t0_absoluto = min([tabla_gps.Timpstemp(1), tabla_accel.Timpstemp(1), tabla_gyro.Timpstemp(1)]);
t_gps   = double(tabla_gps.Timpstemp - tabla_gps.Timpstemp(1)) / 1e6;
t_accel = double(tabla_accel.Timpstemp - tabla_accel.Timpstemp(1)) / 1e6;
t_gyro  = double(tabla_gyro.Timpstemp - tabla_gyro.Timpstemp(1)) / 1e6;

a_x = tabla_accel.x; a_y = tabla_accel.y; a_z = tabla_accel.z;
w_x = tabla_gyro.x;  w_y = tabla_gyro.y;  w_z = tabla_gyro.z;

gps_lat = double(tabla_gps.lat);
gps_lon = double(tabla_gps.lon);
gps_alt = double(tabla_gps.alt);

gt_x = tabla_gt.x_gt; gt_y = tabla_gt.y_gt; gt_z = tabla_gt.z_gt;

lat0 = gps_lat(1) * pi/180;
lon0 = gps_lon(1) * pi/180;
alt0 = gps_alt(1);
R_tierra = 6371000; 

p_gps_norte = (gps_lat*pi/180 - lat0) * R_tierra;
p_gps_este  = (gps_lon*pi/180 - lon0) * R_tierra * cos(lat0);
p_gps_abajo = -(gps_alt - alt0);

gt_este  = gt_x - gt_x(1);
gt_norte = gt_y - gt_y(1);
gt_abajo = -(gt_z - gt_z(1));

[t_gps_unique, unique_idx] = unique(t_gps);
p_gps_norte_u = p_gps_norte(unique_idx);
p_gps_este_u  = p_gps_este(unique_idx);
p_gps_abajo_u = p_gps_abajo(unique_idx);

z_gps_n = interp1(t_gps_unique, p_gps_norte_u, t_accel, 'linear', 'extrap');
z_gps_e = interp1(t_gps_unique, p_gps_este_u,  t_accel, 'linear', 'extrap');
z_gps_d = interp1(t_gps_unique, p_gps_abajo_u, t_accel, 'linear', 'extrap');

fprintf('Filtrando trayectoria...\n');

g = 9.81; 
gravedad_n = [0; 0; g]; 

x_est = zeros(9,1);
P = diag([1 1 1, 0.5 0.5 0.5, deg2rad(5) deg2rad(5) deg2rad(5)]); 
Q = diag([0.5*ones(1,3), 0.5*ones(1,3), deg2rad(2)*ones(1,3)]);  
R = diag([0.05, 0.05, 0.05]); 

H = [eye(3), zeros(3, 6)]; 
I_9 = eye(9);

num_muestras = length(t_accel);
hist_pos = zeros(3, num_muestras);

for k = 2:num_muestras
    dt = t_accel(k) - t_accel(k-1);
    
    a_b = [a_x(k); a_y(k); a_z(k)];
    w_b = [w_x(k); w_y(k); w_z(k)];
    
    p_prev = x_est(1:3); v_prev = x_est(4:6);
    phi = x_est(7); theta = x_est(8); psi = x_est(9);
    
    R_b_n = [cos(theta)*cos(psi), sin(phi)*sin(theta)*cos(psi)-cos(phi)*sin(psi), cos(phi)*sin(theta)*cos(psi)+sin(phi)*sin(psi);
             cos(theta)*sin(psi), sin(phi)*sin(theta)*sin(psi)+cos(phi)*cos(psi), cos(phi)*sin(theta)*sin(psi)-sin(phi)*cos(psi);
             -sin(theta),         sin(phi)*cos(theta),                            cos(phi)*cos(theta)];
             
    % ¡TU CORRECCIÓN APLICADA AQUÍ! a = f + g
    a_n = R_b_n * a_b + gravedad_n; 
    
    x_pred = zeros(9,1);
    x_pred(1:3) = p_prev + v_prev * dt + 0.5 * a_n * dt^2; 
    x_pred(4:6) = v_prev + a_n * dt;                       
    x_pred(7:9) = x_est(7:9) + w_b * dt;                   
    
    F = eye(9);
    F(1:3, 4:6) = eye(3) * dt; 
    
    dR_dphi = [0,  cos(phi)*sin(theta)*cos(psi)+sin(phi)*sin(psi), -sin(phi)*sin(theta)*cos(psi)+cos(phi)*sin(psi);
               0,  cos(phi)*sin(theta)*sin(psi)-sin(phi)*cos(psi), -sin(phi)*sin(theta)*sin(psi)-cos(phi)*cos(psi);
               0,  cos(phi)*cos(theta),                            -sin(phi)*cos(theta)];
    dR_dtheta = [-sin(theta)*cos(psi), sin(phi)*cos(theta)*cos(psi), cos(phi)*cos(theta)*cos(psi);
                 -sin(theta)*sin(psi), sin(phi)*cos(theta)*sin(psi), cos(phi)*cos(theta)*sin(psi);
                 -cos(theta),         -sin(phi)*sin(theta),         -cos(phi)*sin(theta)];
    dR_dpsi = [-cos(theta)*sin(psi), -sin(phi)*sin(theta)*sin(psi)-cos(phi)*cos(psi), -cos(phi)*sin(theta)*sin(psi)+sin(phi)*cos(psi);
                cos(theta)*cos(psi),  sin(phi)*sin(theta)*cos(psi)-cos(phi)*sin(psi),  cos(phi)*sin(theta)*cos(psi)+sin(phi)*sin(psi);
                0,                    0,                                              0];
    
    F(4:6, 7:9) = [dR_dphi * a_b, dR_dtheta * a_b, dR_dpsi * a_b] * dt;
    
    P_pred = F * P * F' + Q;
    
    z_gps = [z_gps_n(k); z_gps_e(k); z_gps_d(k)];
    y_innov = z_gps - H * x_pred;
    
    S = H * P_pred * H' + R;
    K = P_pred * H' / S;
    
    x_est = x_pred + K * y_innov;
    P = (I_9 - K * H) * P_pred * (I_9 - K * H)' + K * R * K'; 
    
    hist_pos(:, k) = x_est(1:3);
end

fprintf('¡Completado!\n');

figure('Name', 'Comparativa TFG', 'Color', 'w');
plot3(gt_norte, gt_este, gt_abajo, 'b--', 'LineWidth', 2, 'DisplayName', 'Pix4D (Real)');
hold on;
plot3(hist_pos(1,:), hist_pos(2,:), hist_pos(3,:), 'r-', 'LineWidth', 1.5, 'DisplayName', 'EKF (Calculada)');
grid on; axis equal; view(3);
xlabel('Norte (m)'); ylabel('Este (m)'); zlabel('Abajo (m)');
title('Trayectoria MAV: Filtro vs Real');
legend('Location', 'best');

%% =========================================================================
% DIAGNÓSTICO PASO 1: ANÁLISIS TEMPORAL (EJE NORTE)
% =========================================================================
figure('Name', 'Paso 1: Las tripas del Filtro', 'Color', 'w');

% 1. Lo que leyó el sensor
plot(t_gps_unique, p_gps_norte_u, 'ro', 'MarkerSize', 4, 'DisplayName', 'GPS Crudo (Sensor)');
hold on;

% 2. Lo que le entra al Filtro (Interpolación)
plot(t_accel, z_gps_n, 'b-', 'LineWidth', 1.5, 'DisplayName', 'GPS Interpolado (Input EKF)');

% 3. Lo que saca el Filtro (Cálculo)
plot(t_accel, hist_pos(1,:), 'k--', 'LineWidth', 2, 'DisplayName', 'Cálculo del EKF');

grid on;
xlabel('Tiempo de grabación (s)');
ylabel('Posición Norte (m)');
title('Diagnóstico 1D: Verificación de Entradas y Salidas');
legend('Location', 'best');