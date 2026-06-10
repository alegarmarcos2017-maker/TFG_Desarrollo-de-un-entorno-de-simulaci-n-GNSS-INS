%% =========================================================================
% TFG: ENTORNO DE SIMULACIÓN GNSS-INS (FILTRADO SÍNCRONO VS ASÍNCRONO VS INS)
% Alumno: Alejandro García Marcos
% =========================================================================
clear; clc; close all;

% 1. RUTA DE LOS DATOS
carpetaData = 'D:\Universidad\4º_Año_de_verdad\TFG\Dataset con datos reales (dron Zúrich)\AGZ\AGZ\Log Files';

%% =========================================================================
% 2. LECTURA DE DATOS CRUDOS
% =========================================================================
fprintf('Cargando datos del dataset de Zúrich...\n');
opts = {'Delimiter', ',', 'VariableNamingRule', 'preserve'};

tabla_gps   = readtable(fullfile(carpetaData, 'OnboardGPS.csv'), opts{:});
tabla_accel = readtable(fullfile(carpetaData, 'RawAccel.csv'), opts{:});
tabla_gyro  = readtable(fullfile(carpetaData, 'RawGyro.csv'), opts{:});
tabla_gt    = readtable(fullfile(carpetaData, 'GroundTruthAGL.csv'), opts{:});

t_gps   = double(tabla_gps.Timpstemp - tabla_gps.Timpstemp(1)) / 1e6;
t_accel = double(tabla_accel.Timpstemp - tabla_accel.Timpstemp(1)) / 1e6;

a_x = tabla_accel.x; a_y = tabla_accel.y; a_z = tabla_accel.z;
w_x = tabla_gyro.x;  w_y = tabla_gyro.y;  w_z = tabla_gyro.z;

gps_lat = double(tabla_gps.lat);
gps_lon = double(tabla_gps.lon);
gps_alt = double(tabla_gps.alt);

gt_x = tabla_gt.x_gt; gt_y = tabla_gt.y_gt; gt_z = tabla_gt.z_gt;

%% =========================================================================
% 3. TRANSFORMACIÓN "FLAT EARTH"
% =========================================================================
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

%% =========================================================================
% 4. PREPROCESADO SÍNCRONO: INTERPOLACIÓN + FILTRO ANTIALIASING ANALÍTICO
% =========================================================================
z_gps_n_raw = interp1(t_gps_unique, p_gps_norte_u, t_accel, 'linear', 'extrap');
z_gps_e_raw = interp1(t_gps_unique, p_gps_este_u,  t_accel, 'linear', 'extrap');
z_gps_d_raw = interp1(t_gps_unique, p_gps_abajo_u, t_accel, 'linear', 'extrap');

% Filtro Butterworth analítico de 2º orden (Paso Bajo, fc = 0.5 Hz, fs = 10 Hz)
fs_imu = 10; fc_corte = 0.5; T = 1 / fs_imu;
wd = 2 * pi * fc_corte; wa = (2 / T) * tan(wd * T / 2);
den_comun = 4 + 2 * sqrt(2) * wa * T + (wa^2) * (T^2);
b_filt = [(wa^2)*(T^2)/den_comun, 2*(wa^2)*(T^2)/den_comun, (wa^2)*(T^2)/den_comun];
a_filt = [1, (2*(wa^2)*(T^2)-8)/den_comun, (4-2*sqrt(2)*wa*T+(wa^2)*(T^2))/den_comun];

z_gps_n_filt = filter(b_filt, a_filt, z_gps_n_raw);
z_gps_e_filt = filter(b_filt, a_filt, z_gps_e_raw);
z_gps_d_filt = filter(b_filt, a_filt, z_gps_d_raw);

%% =========================================================================
% 5. PARÁMETROS CONFIGURACIÓN COMUNES
% =========================================================================
g = 9.81; gravedad_n = [0; 0; g]; 
num_muestras = length(t_accel);

P_init = diag([1 1 1, 0.5 0.5 0.5, deg2rad(5) deg2rad(5) deg2rad(5)]); 
Q = diag([0.5*ones(1,3), 0.5*ones(1,3), deg2rad(2)*ones(1,3)]);  
R = diag([0.05, 0.05, 0.05]); H = [eye(3), zeros(3, 6)]; I_9 = eye(9);

%% =========================================================================
% ALGORITMO 1 & MOTOR INERCIAL: EKF SÍNCRONO + INS PURA
% =========================================================================
fprintf('Ejecutando EKF Síncrono e Integración INS Pura...\n');
x_est_sinc = zeros(9,1); x_ins = zeros(9,1);
P_sinc = P_init;

hist_pos_sinc = zeros(3, num_muestras);
hist_pos_ins  = zeros(3, num_muestras);

for k = 2:num_muestras
    dt = t_accel(k) - t_accel(k-1);
    a_b = [a_x(k); a_y(k); a_z(k)]; w_b = [w_x(k); w_y(k); w_z(k)];
    
    % Matriz de rotación (Basada en estados del EKF Síncrono)
    phi = x_est_sinc(7); theta = x_est_sinc(8); psi = x_est_sinc(9);
    R_b_n = [cos(theta)*cos(psi), sin(phi)*sin(theta)*cos(psi)-cos(phi)*sin(psi), cos(phi)*sin(theta)*cos(psi)+sin(phi)*sin(psi);
             cos(theta)*sin(psi), sin(phi)*sin(theta)*sin(psi)+cos(phi)*cos(psi), cos(phi)*sin(theta)*sin(psi)-sin(phi)*cos(psi);
             -sin(theta),         sin(phi)*cos(theta),                            cos(phi)*cos(theta)];
    a_n = R_b_n * a_b + gravedad_n; 
    
    % --- MOTOR INS PURA (Ciego, acumula error) ---
    x_ins(1:3) = x_ins(1:3) + x_ins(4:6)*dt + 0.5*a_n*dt^2;
    x_ins(4:6) = x_ins(4:6) + a_n*dt;
    hist_pos_ins(:, k) = x_ins(1:3);
    
    % --- MOTOR EKF SÍNCRONO ---
    x_pred = [x_est_sinc(1:3) + x_est_sinc(4:6)*dt + 0.5*a_n*dt^2; x_est_sinc(4:6) + a_n*dt; x_est_sinc(7:9) + w_b*dt];
    F = eye(9); F(1:3, 4:6) = eye(3) * dt; F(4:6, 7:9) = eye(3) * dt;
    P_pred = F * P_sinc * F' + Q;
    
    z_gps = [z_gps_n_filt(k); z_gps_e_filt(k); z_gps_d_filt(k)];
    y_innov = z_gps - H * x_pred;
    S = H * P_pred * H' + R; K = P_pred * H' / S;
    x_est_sinc = x_pred + K * y_innov;
    P_sinc = (I_9 - K * H) * P_pred * (I_9 - K * H)' + K * R * K'; 
    hist_pos_sinc(:, k) = x_est_sinc(1:3);
end

hist_pos_asinc = zeros(3, num_muestras);
hist_pos_pred  = zeros(3, num_muestras); 

%% =========================================================================
% ALGORITMO 2: EKF ASÍNCRONO MULTI-RATE
% =========================================================================
fprintf('Ejecutando EKF Asíncrono Multi-rate...\n');
x_est_asinc = zeros(9,1); P_asinc = P_init;
hist_pos_asinc = zeros(3, num_muestras);
idx_gps_actual = 1; tol_temporal = 0.05;

for k = 2:num_muestras
    dt = t_accel(k) - t_accel(k-1);
    a_b = [a_x(k); a_y(k); a_z(k)]; w_b = [w_x(k); w_y(k); w_z(k)];
    
    phi = x_est_asinc(7); theta = x_est_asinc(8); psi = x_est_asinc(9);
    R_b_n = [cos(theta)*cos(psi), sin(phi)*sin(theta)*cos(psi)-cos(phi)*sin(psi), cos(phi)*sin(theta)*cos(psi)+sin(phi)*sin(psi);
             cos(theta)*sin(psi), sin(phi)*sin(theta)*sin(psi)+cos(phi)*cos(psi), cos(phi)*sin(theta)*sin(psi)-sin(phi)*cos(psi);
             -sin(theta),         sin(phi)*cos(theta),                            cos(phi)*cos(theta)];
    a_n = R_b_n * a_b + gravedad_n;
    
    x_pred = [x_est_asinc(1:3) + x_est_asinc(4:6)*dt + 0.5*a_n*dt^2; x_est_asinc(4:6) + a_n*dt; x_est_asinc(7:9) + w_b*dt];
    F = eye(9); F(1:3, 4:6) = eye(3) * dt; F(4:6, 7:9) = eye(3) * dt;
    P_pred = F * P_asinc * F' + Q;

    % Predicción Inercial
    x_pred = [x_est_asinc(1:3) + x_est_asinc(4:6)*dt + 0.5*a_n*dt^2; x_est_asinc(4:6) + a_n*dt; x_est_asinc(7:9) + w_b*dt];
    F = eye(9); F(1:3, 4:6) = eye(3) * dt; F(4:6, 7:9) = eye(3) * dt;
    P_pred = F * P_asinc * F' + Q;

    hist_pos_pred(:, k) = x_pred(1:3); % <--- AÑADE ESTA LÍNEA PARA GUARDAR EL DATO
    
    flag_gps_nuevo = 0;
    if idx_gps_actual <= length(t_gps_unique)
        if abs(t_accel(k) - t_gps_unique(idx_gps_actual)) <= tol_temporal
            flag_gps_nuevo = 1;
            z_gps = [p_gps_norte_u(idx_gps_actual); p_gps_este_u(idx_gps_actual); p_gps_abajo_u(idx_gps_actual)];
            idx_gps_actual = idx_gps_actual + 1;
        end
    end
    
    if flag_gps_nuevo == 1
        y_innov = z_gps - H * x_pred;
        S = H * P_pred * H' + R; K = P_pred * H' / S;
        x_est_asinc = x_pred + K * y_innov;
        P_asinc = (I_9 - K * H) * P_pred * (I_9 - K * H)' + K * R * K';
    else
        x_est_asinc = x_pred; P_asinc = P_pred;
    end
    hist_pos_asinc(:, k) = x_est_asinc(1:3);
end

%% =========================================================================
% 6. POST-PROCESADO Y ALINEACIÓN DE CENTROS DE MASA
% =========================================================================
fprintf('Alineando centros de masa y calculando errores...\n');

% Offsets Motor Síncrono e INS
offset_n_sinc = mean(hist_pos_sinc(1,:)) - mean(gt_norte);
offset_e_sinc = mean(hist_pos_sinc(2,:)) - mean(gt_este);
offset_d_sinc = mean(hist_pos_sinc(3,:)) - mean(gt_abajo);
hist_sinc_al  = hist_pos_sinc - [offset_n_sinc; offset_e_sinc; offset_d_sinc];
hist_ins_al   = hist_pos_ins  - [offset_n_sinc; offset_e_sinc; offset_d_sinc];

% Offsets Motor Asíncrono
offset_n_asinc = mean(hist_pos_asinc(1,:)) - mean(gt_norte);
offset_e_asinc = mean(hist_pos_asinc(2,:)) - mean(gt_este);
offset_d_asinc = mean(hist_pos_asinc(3,:)) - mean(gt_abajo);
hist_asinc_al  = hist_pos_asinc - [offset_n_asinc; offset_e_asinc; offset_d_asinc];

% ---> ¡AQUÍ ESTÁ LA LÍNEA EN SU SITIO CORRECTO! <---
hist_pred_al = hist_pos_pred - [offset_n_asinc; offset_e_asinc; offset_d_asinc];

% Cálculo de RMSE
calc_rmse = @(trayect) sqrt(mean(arrayfun(@(i) min(sum(( [gt_norte, gt_este, gt_abajo]' - trayect(:,i) ).^2, 1)), 1:size(trayect,2))));
rmse_sinc  = calc_rmse(hist_sinc_al);
rmse_asinc = calc_rmse(hist_asinc_al);

%% =========================================================================
% 7. GENERACIÓN DEL SET DE GRÁFICAS PARA EL DOCUMENTO
% =========================================================================
fprintf('Generando catálogo de figuras...\n');

% --- FIGURA 1: EL TRÍPTICO DE LA DERIVA (INS PURA VS REAL) ---
figure('Name', 'Figura 1: Tríptico Deriva INS', 'Color', 'w', 'Units', 'normalized', 'Position', [0.05, 0.5, 0.45, 0.4]);
subplot(1,3,1); plot(gt_este, gt_norte, 'b--', 'LineWidth', 2); hold on; plot(hist_ins_al(2,:), hist_ins_al(1,:), 'k-'); grid on; axis equal; xlabel('Este (m)'); ylabel('Norte (m)'); title('Plano E-N (Planta)');
subplot(1,3,2); plot(gt_norte, gt_abajo, 'b--', 'LineWidth', 2); hold on; plot(hist_ins_al(1,:), hist_ins_al(3,:), 'k-'); grid on; axis equal; xlabel('Norte (m)'); ylabel('Abajo (m)'); title('Plano N-D (Alzado)');
subplot(1,3,3); plot(gt_este, gt_abajo, 'b--', 'LineWidth', 2); hold on; plot(hist_ins_al(2,:), hist_ins_al(3,:), 'k-'); grid on; axis equal; xlabel('Este (m)'); ylabel('Abajo (m)'); title('Plano E-D (Perfil)');
legend('Pix4D (Real)', 'INS Pura', 'Location', 'best');
sgtitle('Análisis de Deriva del Sistema de Navegación Inercial (INS Pura) por Planos Ortogonales', 'FontWeight', 'bold');

% --- FIGURA 2: EL TRÍPTICO DE LA SOLUCIÓN (COMPARATIVA FILTROS VS REAL) ---
figure('Name', 'Figura 2: Tríptico Comparativo Filtros', 'Color', 'w', 'Units', 'normalized', 'Position', [0.5, 0.5, 0.45, 0.4]);
subplot(1,3,1); plot(gt_este, gt_norte, 'b--', 'LineWidth', 2.5); hold on; plot(hist_sinc_al(2,:), hist_sinc_al(1,:), 'r-'); plot(hist_asinc_al(2,:), hist_asinc_al(1,:), 'g-'); grid on; axis equal; xlabel('Este (m)'); ylabel('Norte (m)'); title('Plano E-N (Planta)');
subplot(1,3,2); plot(gt_norte, gt_abajo, 'b--', 'LineWidth', 2.5); hold on; plot(hist_sinc_al(1,:), hist_sinc_al(3,:), 'r-'); plot(hist_asinc_al(1,:), hist_asinc_al(3,:), 'g-'); grid on; axis equal; xlabel('Norte (m)'); ylabel('Abajo (m)'); title('Plano N-D (Alzado)');
subplot(1,3,3); plot(gt_este, gt_abajo, 'b--', 'LineWidth', 2.5); hold on; plot(hist_sinc_al(2,:), hist_sinc_al(3,:), 'r-'); plot(hist_asinc_al(2,:), hist_asinc_al(3,:), 'g-'); grid on; axis equal; xlabel('Este (m)'); ylabel('Abajo (m)'); title('Plano E-D (Perfil)');
legend('Pix4D (Real)', 'EKF Síncrono', 'EKF Asíncrono', 'Location', 'best');
sgtitle('Análisis Comparativo por Planos: EKF Síncrono vs. EKF Asíncrono', 'FontWeight', 'bold');

% --- FIGURA 3: COMPARATIVA EN TRES DIMENSIONES (3D) ---
figure('Name', 'Figura 3: Comparativa 3D Completa', 'Color', 'w');
plot3(gt_norte, gt_este, gt_abajo, 'b--', 'LineWidth', 2.5, 'DisplayName', 'Pix4D (Ground Truth)'); hold on;
plot3(hist_sinc_al(1,:), hist_sinc_al(2,:), hist_sinc_al(3,:), 'r-', 'LineWidth', 1.5, 'DisplayName', sprintf('EKF Síncrono (RMSE: %.3fm)', rmse_sinc));
plot3(hist_asinc_al(1,:), hist_asinc_al(2,:), hist_asinc_al(3,:), 'g-.', 'LineWidth', 1.5, 'DisplayName', sprintf('EKF Asíncrono (RMSE: %.3fm)', rmse_asinc));
grid on; axis equal; view(3); xlabel('Norte (m)'); ylabel('Este (m)'); zlabel('Abajo (m)');
title('Comparativa de Arquitecturas de Filtrado de Kalman Extendido (EKF)'); legend('Location', 'best');

% --- FIGURA 4: ZOOM ANTIALIASING (PARA LA REVISIÓN DEL TUTOR) ---
rango_zoom = 10000:13000;
figure('Name', 'Figura 4: Efecto Butterworth', 'Color', 'w');
plot(z_gps_e_raw(rango_zoom), z_gps_n_raw(rango_zoom), 'k-.', 'LineWidth', 1.5, 'DisplayName', 'GPS Interpolado (Con Aliasing)'); hold on;
plot(z_gps_e_filt(rango_zoom), z_gps_n_filt(rango_zoom), 'm-', 'LineWidth', 2.5, 'DisplayName', 'GPS Suavizado (Filtro)');
grid on; axis equal; xlabel('Este (m)'); ylabel('Norte (m)'); title('Efecto del Filtro Antialiasing en la señal GNSS'); legend('Location', 'best');

fprintf('\n=== DATOS MÉTRICOS FINALES ===\n');
fprintf('RMSE EKF Síncrono:  %.4f m\n', rmse_sinc);
fprintf('RMSE EKF Asíncrono: %.4f m\n', rmse_asinc);
fprintf('Deriva Final INS:   %.1f km\n', norm(hist_ins_al(:,end))/1000);

%% =========================================================================
% GRÁFICA ESTRELLA TFG: TRAYECTORIA 3D (GROUND TRUTH VS EKF)
% =========================================================================
figure('Name', 'Resultados 3D: Validación del Filtro de Kalman', 'Color', 'w', 'Position', [100, 100, 800, 600]);

% 1. Dibujamos la ruta de referencia (Ground Truth de Pix4D) en azul
plot3(gt_norte, gt_este, gt_abajo, 'b--', 'LineWidth', 2.5, 'DisplayName', 'Ruta Real (Pix4D)');
hold on;

% 2. Dibujamos tu EKF Síncrono alineado en rojo
plot3(hist_sinc_al(1,:), hist_sinc_al(2,:), hist_sinc_al(3,:), 'r-', 'LineWidth', 1.5, 'DisplayName', 'Estimación EKF (GNSS+INS)');

% (Opcional) Si quieres que también salga el asíncrono, descomenta esta línea:
% plot3(hist_asinc_al(1,:), hist_asinc_al(2,:), hist_asinc_al(3,:), 'g-.', 'LineWidth', 1.5, 'DisplayName', 'EKF Asíncrono');

% 3. Formateo profesional de la figura
grid on; 
axis equal; % Vital para que las curvas no se deformen
view(3);    % Activa la perspectiva 3D isométrica

xlabel('Posición Norte (m)', 'FontWeight', 'bold'); 
ylabel('Posición Este (m)', 'FontWeight', 'bold'); 
zlabel('Altitud / Abajo (m)', 'FontWeight', 'bold');

title('Validación Espacial 3D: Fusión Sensorial MAV', 'FontSize', 14);
legend('Location', 'northeast', 'FontSize', 11);

fprintf('¡Gráfica 3D generada con éxito!\n');

% --- FIGURA 5: ZOOM 3D FUSIÓN COMPLETA (DIENTE DE SIERRA Y GPS CRUDO) ---
% Elegimos un tramo donde el dron esté girando para ver mejor la dinámica
rango_zoom = 12000:12500; 

figure('Name', 'Fig 5: Ecosistema Multirrate GNSS-INS', 'Color', 'w');

% 1. Ground Truth (Dibujamos la ruta entera, luego la cámara hará el zoom)
plot3(gt_norte, gt_este, gt_abajo, 'b--', 'LineWidth', 2, 'DisplayName', 'Ground Truth (Pix4D)');
hold on;

% 2. La evolución del INS (Mini-derivas entre actualizaciones)
% La línea gris muestra cómo el dron se va desviando poco a poco a ciegas
plot3(hist_pred_al(1, rango_zoom), hist_pred_al(2, rango_zoom), hist_pred_al(3, rango_zoom), 'Color', [0.6 0.6 0.6], 'LineWidth', 1.5, 'DisplayName', 'Propagación INS (A priori)');

% 3. Puntos GPS Crudos (Alineados con el EKF)
% Aplicamos el mismo offset para que los puntos caigan en el mismo sistema de coordenadas
gps_n_al = p_gps_norte_u - offset_n_asinc;
gps_e_al = p_gps_este_u - offset_e_asinc;
gps_d_al = p_gps_abajo_u - offset_d_asinc;

% Buscamos qué puntos del GPS ocurrieron exactamente durante esos 500 pasos de la IMU
t_inicio_zoom = t_accel(rango_zoom(1));
t_fin_zoom    = t_accel(rango_zoom(end));
idx_gps_zoom  = find(t_gps_unique >= t_inicio_zoom & t_gps_unique <= t_fin_zoom);

% Los pintamos como asteriscos rojos
plot3(gps_n_al(idx_gps_zoom), gps_e_al(idx_gps_zoom), gps_d_al(idx_gps_zoom), 'r*', 'MarkerSize', 8, 'LineWidth', 1.5, 'DisplayName', 'Muestras GPS Crudas');

% 4. Estimación Fusa Final (La ruta corregida del EKF)
% Esta línea magenta unirá los puntos tras los "tirones" del filtro
plot3(hist_asinc_al(1, rango_zoom), hist_asinc_al(2, rango_zoom), hist_asinc_al(3, rango_zoom), 'm-', 'LineWidth', 2.5, 'DisplayName', 'Estimación EKF (A posteriori)');

% Formateo de la figura
grid on; axis equal; view(3); 
xlabel('Norte (m)', 'FontWeight', 'bold'); 
ylabel('Este (m)', 'FontWeight', 'bold'); 
zlabel('Abajo (m)', 'FontWeight', 'bold');
title('Análisis Detallado de Fusión Multirrate (GNSS-INS)', 'FontSize', 12);

% 5. EL TRUCO DE CÁMARA: Acotamos la vista física a los límites del zoom
margen = 2; % 2 metros de margen
xlim([min(hist_pred_al(1, rango_zoom)) - margen, max(hist_pred_al(1, rango_zoom)) + margen]);
ylim([min(hist_pred_al(2, rango_zoom)) - margen, max(hist_pred_al(2, rango_zoom)) + margen]);
zlim([min(hist_pred_al(3, rango_zoom)) - margen, max(hist_pred_al(3, rango_zoom)) + margen]);

legend('Location', 'best', 'FontSize', 10);

