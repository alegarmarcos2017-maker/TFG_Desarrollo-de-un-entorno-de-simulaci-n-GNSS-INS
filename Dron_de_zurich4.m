%% =========================================================================
% TFG: FUSIÓN GNSS-INS CON EKF (INCLUYE DERIVA INERCIAL PURA)
% =========================================================================
clear; clc; close all;

% 1. RUTA DE LOS DATOS
carpetaData = 'D:\Universidad\4º_Año_de_verdad\TFG\Dataset con datos reales (dron Zúrich)\AGZ\AGZ\Log Files';

%% =========================================================================
% 2. LECTURA Y ALINEACIÓN DE TIEMPOS
% =========================================================================
fprintf('Cargando datos y sincronizando relojes...\n');
opts = {'Delimiter', ',', 'VariableNamingRule', 'preserve'};

tabla_gps   = readtable(fullfile(carpetaData, 'OnboardGPS.csv'), opts{:});
tabla_accel = readtable(fullfile(carpetaData, 'RawAccel.csv'), opts{:});
tabla_gyro  = readtable(fullfile(carpetaData, 'RawGyro.csv'), opts{:});
tabla_gt    = readtable(fullfile(carpetaData, 'GroundTruthAGL.csv'), opts{:});

% --- ALINEACIÓN TEMPORAL GLOBAL (Sincronización real) ---
t0_global = min(tabla_gps.Timpstemp(1), tabla_accel.Timpstemp(1));
t_gps   = double(tabla_gps.Timpstemp - t0_global) / 1e6;
t_accel = double(tabla_accel.Timpstemp - t0_global) / 1e6;

a_x = tabla_accel.x; a_y = tabla_accel.y; a_z = tabla_accel.z;
w_x = tabla_gyro.x;  w_y = tabla_gyro.y;  w_z = tabla_gyro.z;

% GPS (Sin factores de escala, el CSV ya está en grados)
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

% --- FIGURA 2: LA SOLUCIÓN (Fusión EKF) ---
figure('Name', 'Figura 2: Solución EKF', 'Color', 'w');

% 1. Ground Truth (Referencia - Pix4D)
plot3(gt_norte, gt_este, gt_abajo, 'b--', 'LineWidth', 2, 'DisplayName', 'Pix4D (Real)');
hold on;

% 2. Puntos del GPS Crudo (La "nube" de error de los satélites)
plot3(p_gps_norte, p_gps_este, p_gps_abajo, 'ro', 'MarkerSize', 4, 'DisplayName', 'GNSS Crudo');

grid on; axis equal; view(3);
xlabel('Norte (m)', 'FontWeight', 'bold'); 
ylabel('Este (m)', 'FontWeight', 'bold'); 
zlabel('Abajo (m)', 'FontWeight', 'bold');
title('Comparativa: GPS Crudo vs Realidad', 'FontSize', 12);
legend('Location', 'best');

%a continuación se representa la misma gráfica pero esta vez en proyección
%en los 3 ejes para visualizar mejor el error del gps favorablemente en un
%eje que en otro

%% =========================================================================
% DIAGNÓSTICO PREVIO: ERROR GNSS POR PLANOS ORTOGONALES
% =========================================================================
fprintf('Generando tríptico 2D de Ground Truth vs GPS...\n');

figure('Name', 'Análisis Error GNSS', 'Color', 'w', 'Units', 'normalized', 'Position', [0.1, 0.3, 0.8, 0.4]);

% --- SUBPLOT 1: Plano Horizontal (Planta / Norte-Este) ---
subplot(1, 3, 1);
plot(gt_este, gt_norte, 'b-', 'LineWidth', 2, 'DisplayName', 'Pix4D (Real)'); hold on;
plot(p_gps_este, p_gps_norte, 'r.', 'MarkerSize', 4, 'DisplayName', 'GNSS Crudo');
grid on; axis equal;
xlabel('Este (m)', 'FontWeight', 'bold'); 
ylabel('Norte (m)', 'FontWeight', 'bold');
title('Plano Horizontal (Top View)');
legend('Location', 'best');

% --- SUBPLOT 2: Plano Vertical Lateral (Norte-Abajo) ---
subplot(1, 3, 2);
plot(gt_norte, gt_abajo, 'b-', 'LineWidth', 2, 'DisplayName', 'Pix4D (Real)'); hold on;
plot(p_gps_norte, p_gps_abajo, 'r.', 'MarkerSize', 4, 'DisplayName', 'GNSS Crudo');
grid on; axis equal;
xlabel('Norte (m)', 'FontWeight', 'bold'); 
ylabel('Abajo (m)', 'FontWeight', 'bold');
title('Plano Vertical (Norte-Abajo)');
legend('Location', 'best');

% --- SUBPLOT 3: Plano Vertical Frontal (Este-Abajo) ---
subplot(1, 3, 3);
plot(gt_este, gt_abajo, 'b-', 'LineWidth', 2, 'DisplayName', 'Pix4D (Real)'); hold on;
plot(p_gps_este, p_gps_abajo, 'r.', 'MarkerSize', 4, 'DisplayName', 'GNSS Crudo');
grid on; axis equal;
xlabel('Este (m)', 'FontWeight', 'bold'); 
ylabel('Abajo (m)', 'FontWeight', 'bold');
title('Plano Vertical (Este-Abajo)');
legend('Location', 'best');

sgtitle('Descomposición del Error GNSS vs Ground Truth', 'FontWeight', 'bold', 'FontSize', 14);
fprintf('¡Tríptico GPS generado!\n');

%% =========================================================================
% DIAGNÓSTICO PREVIO: ERROR EUCLÍDEO DEL GPS VS GROUND TRUTH
% =========================================================================
fprintf('Calculando el error euclídeo del GPS crudo...\n');

num_points_gps = length(p_gps_norte);
error_gps_distancia = zeros(num_points_gps, 1);
P_gt_transpuesta = [gt_norte, gt_este, gt_abajo]'; % Matriz 3xN para calcular distancias rápido

% Calculamos la distancia mínima de cada lectura GPS a la trayectoria real
for i = 1:num_points_gps
    P_gps_actual = [p_gps_norte(i); p_gps_este(i); p_gps_abajo(i)];

    % Distancia euclídea 3D del punto GPS actual a todos los puntos del GT
    distancias = sqrt((P_gt_transpuesta(1,:) - P_gps_actual(1)).^2 + ...
        (P_gt_transpuesta(2,:) - P_gps_actual(2)).^2 + ...
        (P_gt_transpuesta(3,:) - P_gps_actual(3)).^2);

    % Asumimos que el error es la distancia al punto más cercano de la ruta real
    error_gps_distancia(i) = min(distancias);
end

% Cálculos estadísticos de la línea base
rmse_gps = sqrt(mean(error_gps_distancia.^2));
media_error_gps = mean(error_gps_distancia);

% --- Representación Gráfica ---
figure('Name', 'Error GNSS vs GT', 'Color', 'w', 'Units', 'normalized', 'Position', [0.2, 0.3, 0.6, 0.4]);

plot(t_gps, error_gps_distancia, 'r-', 'LineWidth', 1.2, 'DisplayName', 'Error Euclídeo GPS');
hold on;

% Añadimos líneas horizontales para marcar la Media y el RMSE
yline(rmse_gps, 'k--', ['RMSE = ', num2str(rmse_gps, '%.2f'), ' m'], 'LineWidth', 1.5, 'LabelHorizontalAlignment', 'left');
yline(media_error_gps, 'b--', ['Media = ', num2str(media_error_gps, '%.2f'), ' m'], 'LineWidth', 1.5, 'LabelHorizontalAlignment', 'left');

grid on;
xlabel('Tiempo (s)', 'FontWeight', 'bold');
ylabel('Error Espacial (m)', 'FontWeight', 'bold');
title('Evolución Temporal del Error del GPS Crudo (Línea Base)', 'FontWeight', 'bold', 'FontSize', 12);
legend('Location', 'best');

fprintf('\n--- LÍNEA BASE ESTABLECIDA ---\n');
fprintf('RMSE del GPS crudo: %.3f metros\n', rmse_gps);
fprintf('------------------------------\n\n');

%% =========================================================================
% EXTRACCIÓN Y REPRESENTACIÓN DE LA ACTITUD DEL PIXHAWK (EULER)
% =========================================================================
fprintf('Cargando datos de actitud del Pixhawk...\n');

% 1. Cargar el archivo de pose (asumiendo que opts ya está definido)
tabla_pose = readtable(fullfile(carpetaData, 'OnboardPose.csv'), opts{:});

% 2. Extraer el vector de tiempo (de microsegundos a segundos)
t_pose = double(tabla_pose.Timpstemp - tabla_pose.Timpstemp(1)) / 1e6;

% 3. Extraer los cuaterniones
q_w = tabla_pose.Attitude_w;
q_x = tabla_pose.Attitude_x;
q_y = tabla_pose.Attitude_y;
q_z = tabla_pose.Attitude_z;
cuaterniones_pixhawk = [q_w, q_x, q_y, q_z];

% 4. Convertir a ángulos de Euler (Secuencia ZYX)
% MATLAB devuelve por defecto la matriz en el orden [Yaw, Pitch, Roll] en radianes
angulos_pixhawk_rad = quat2eul(cuaterniones_pixhawk, 'ZYX');

% 5. Extraer y convertir a grados
yaw_pixhawk_deg   = rad2deg(angulos_pixhawk_rad(:, 1));
pitch_pixhawk_deg = rad2deg(angulos_pixhawk_rad(:, 2));
roll_pixhawk_deg  = rad2deg(angulos_pixhawk_rad(:, 3));

% =========================================================================
% REPRESENTACIÓN DE LA ACTITUD DEL PIXHAWK (GRÁFICA ÚNICA)
% =========================================================================
fprintf('Generando gráfica combinada de actitud...\n');

figure('Name', 'Actitud del Dron Combinada (Pixhawk)', 'Color', 'w', 'Units', 'normalized', 'Position', [0.2, 0.2, 0.6, 0.5]);

% Dibujamos las tres líneas en los mismos ejes
plot(t_pose, roll_pixhawk_deg, 'b-', 'LineWidth', 1.5, 'DisplayName', 'Alabeo (Roll)');
hold on;
plot(t_pose, pitch_pixhawk_deg, 'r-', 'LineWidth', 1.5, 'DisplayName', 'Cabeceo (Pitch)');
plot(t_pose, yaw_pixhawk_deg, 'g-', 'LineWidth', 1.5, 'DisplayName', 'Guiñada (Yaw)');

% Añadimos las líneas de límite del Gimbal Lock como referencia visual
yline(90, 'k--', 'Límite Sing. (+90º)', 'HandleVisibility', 'off');
yline(-90, 'k--', 'Límite Sing. (-90º)', 'HandleVisibility', 'off');

% Formato de la gráfica
grid on;
xlabel('Tiempo (s)', 'FontWeight', 'bold');
ylabel('Ángulo (Grados)', 'FontWeight', 'bold');
title('Evolución Temporal de la Actitud ', 'FontWeight', 'bold', 'FontSize', 14);

% Leyenda para identificar cada curva
legend('Location', 'best');

fprintf('¡Gráfica combinada generada!\n');



%% =========================================================================
% 5. FILTRO DE KALMAN E INTEGRACIÓN INERCIAL PURA
% =========================================================================
fprintf('Calculando trayectoria EKF y Deriva Inercial...\n');

g = 9.81; 
gravedad_n = [0; 0; g]; 

% Variables EKF

x_est = zeros(9,1);
% Incertidumbre inicial
P = diag([1 1 1, 0.5 0.5 0.5, deg2rad(5)*ones(1,3)]); 

% Matriz de Ruido de Proceso Continuo Q_c (Varianzas = sigma^2)
sigma_pos = 0.05; 
sigma_vel = 0.1; 
sigma_att = deg2rad(0.5);  
Q_c = diag([sigma_pos^2*ones(1,3), sigma_vel^2*ones(1,3), sigma_att^2*ones(1,3)]);  

% Matriz de Ruido de Medida R (Confianza en el GPS)
R = diag([0.05, 0.05, 0.05]); 

H = [eye(3), zeros(3, 6)]; 
I_9 = eye(9);

% Variables INS Pura (Para la nueva gráfica)
x_ins = zeros(9,1); 
% --- 2. PREPARACIÓN DE DATOS DE GPS ASÍNCRONOS ---
[t_gps_unique, unique_idx] = unique(t_gps);
p_gps_norte_u = p_gps_norte(unique_idx);
p_gps_este_u  = p_gps_este(unique_idx);
p_gps_abajo_u = p_gps_abajo(unique_idx);

% --- 3. INICIALIZACIÓN DE HISTORIALES Y MOTORES ---
x_ins = zeros(9,1); 
num_muestras = length(t_accel);

hist_pos     = zeros(3, num_muestras);
hist_pos_ins = zeros(3, num_muestras); 
hist_att     = zeros(3, num_muestras); 
hist_P       = zeros(9, num_muestras);
hist_P(:, 1) = diag(P); 

% Sincronizar el primer paquete de GPS válido
idx_gps = 1;

while idx_gps <= length(t_gps_unique) && t_gps_unique(idx_gps) < t_accel(1)
    idx_gps = idx_gps + 1;
end

% ANCLAJE INICIAL: Acoplamos el origen del filtro al primer dato real del GPS
if idx_gps <= length(t_gps_unique)
    x_est(1:3) = [p_gps_norte_u(idx_gps); p_gps_este_u(idx_gps); p_gps_abajo_u(idx_gps)];
    x_ins(1:3) = x_est(1:3); 
end

% --- 4. BUCLE PRINCIPAL DE INTEGRACIÓN ASÍNCRONA ---
for k = 2:num_muestras
    dt = t_accel(k) - t_accel(k-1);
    if dt <= 0, dt = 1e-4; end % Salvaguarda numérica
    
    a_b = [a_x(k); a_y(k); a_z(k)];
    w_b = [w_x(k); w_y(k); w_z(k)];
    
    % --- MATRIZ DE ROTACIÓN DE PASO ---
    phi = x_est(7); theta = x_est(8); psi = x_est(9);
    R_b_n = [cos(theta)*cos(psi), sin(phi)*sin(theta)*cos(psi)-cos(phi)*sin(psi), cos(phi)*sin(theta)*cos(psi)+sin(phi)*sin(psi);
             cos(theta)*sin(psi), sin(phi)*sin(theta)*sin(psi)+cos(phi)*cos(psi), cos(phi)*sin(theta)*sin(psi)-sin(phi)*cos(psi);
             -sin(theta),         sin(phi)*cos(theta),                            cos(phi)*cos(theta)];
             
    a_n = R_b_n * a_b + gravedad_n; 
    
    % =====================================================================
    % MOTOR 1: INERCIAL PURA (Evolución libre)
    % =====================================================================
    p_ins_prev = x_ins(1:3); 
    v_ins_prev = x_ins(4:6);
    x_ins(1:3) = p_ins_prev + v_ins_prev * dt + 0.5 * a_n * dt^2; 
    x_ins(4:6) = v_ins_prev + a_n * dt; 
    hist_pos_ins(:, k) = x_ins(1:3);
    
    % =====================================================================
    % MOTOR 2: FILTRO DE KALMAN ASÍNCRONO
    % =====================================================================
    % FASE DE PREDICCIÓN (Se ejecuta siempre con la IMU)
    p_prev = x_est(1:3); v_prev = x_est(4:6);
    
    x_pred = zeros(9,1);
    x_pred(1:3) = p_prev + v_prev * dt + 0.5 * a_n * dt^2; 
    x_pred(4:6) = v_prev + a_n * dt;                       
    x_pred(7:9) = x_est(7:9) + w_b * dt;                   
    
    % Jacobiano F estándar de 9 estados
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
    
    P_pred = F * P * F' + Q_c * dt; 
    
    % --- LA CLAVE PARA QUE NO SE CORTE ---
    % Por defecto, adoptamos la predicción inercial pura
    x_est = x_pred;
    P = P_pred;
    
    % FASE DE CORRECCIÓN ASÍNCRONA (Solo sobreescribe si toca GPS)
    while idx_gps <= length(t_gps_unique) && t_accel(k) >= t_gps_unique(idx_gps)
        
        z_gps = [p_gps_norte_u(idx_gps); p_gps_este_u(idx_gps); p_gps_abajo_u(idx_gps)];
        y_innov = z_gps - H * x_pred;
        
        S = H * P_pred * H' + R;
        K = P_pred * H' / S;
        
        % Sobreescribimos la estimación con el GPS
        x_est = x_pred + K * y_innov;
        P = (I_9 - K * H) * P_pred * (I_9 - K * H)' + K * R * K'; 
        
        % Actualizamos la predicción interna por si hay más de un GPS en la cola
        x_pred = x_est;
        P_pred = P;
        
        idx_gps = idx_gps + 1; 
    end
    
    % Almacenamiento
    hist_pos(:, k) = x_est(1:3);
    hist_att(:, k) = x_est(7:9);
    hist_P(:, k)   = diag(P);
    
    % Almacenamiento
    hist_pos(:, k) = x_est(1:3);
    hist_att(:, k) = x_est(7:9);
    hist_P(:, k)   = diag(P);
end
fprintf('¡Filtro de 9 estados asíncrono completado!\n');

%% =========================================================================
% 6. ALINEACIÓN DE CENTROS DE MASA Y CÁLCULO DE ERROR RMSE
% =========================================================================
offset_norte = mean(hist_pos(1,:)) - mean(gt_norte);
offset_este  = mean(hist_pos(2,:)) - mean(gt_este);
offset_abajo = mean(hist_pos(3,:)) - mean(gt_abajo);

hist_pos_alineado = hist_pos - [offset_norte; offset_este; offset_abajo];
hist_ins_alineado = hist_pos_ins - [offset_norte; offset_este; offset_abajo];

% Error RMSE Espacial (EKF vs Real)
num_points_ekf = size(hist_pos_alineado, 2);
error_distancia = zeros(num_points_ekf, 1);
P_gt = [gt_norte, gt_este, gt_abajo]';

for i = 1:num_points_ekf
    P_ekf_actual = hist_pos_alineado(:, i);
    distancias = sqrt((P_gt(1,:) - P_ekf_actual(1)).^2 + ...
                      (P_gt(2,:) - P_ekf_actual(2)).^2 + ...
                      (P_gt(3,:) - P_ekf_actual(3)).^2);
    error_distancia(i) = min(distancias);
end
rmse_3d_espacial = sqrt(mean(error_distancia.^2));

%% =========================================================================
% 7. REPRESENTACIÓN GRÁFICA (TFG)
% =========================================================================

% --- FIGURA 2: LA SOLUCIÓN (Fusión EKF) ---
figure('Name', 'Figura 2: Solución EKF', 'Color', 'w');

% 1. Ground Truth (Referencia - Pix4D)
plot3(gt_norte, gt_este, gt_abajo, 'b--', 'LineWidth', 2, 'DisplayName', 'Pix4D (Real)');
hold on;

% 2. Puntos del GPS Crudo
plot3(p_gps_norte, p_gps_este, p_gps_abajo, 'k.', 'MarkerSize', 4, 'DisplayName', 'GNSS Crudo');

% 3. Trayectoria EKF (Usamos la variable hist_pos DIRECTAMENTE)
plot3(hist_pos(1,:), hist_pos(2,:), hist_pos(3,:), 'r-', 'LineWidth', 1.5, 'DisplayName', 'EKF (Estimado)');

grid on; axis equal; view(3);
xlabel('Norte (m)', 'FontWeight', 'bold'); 
ylabel('Este (m)', 'FontWeight', 'bold'); 
zlabel('Abajo (m)', 'FontWeight', 'bold');
title('GPS Crudo vs Ground Truth', 'FontSize', 12);
legend('Location', 'best');
% %% =========================================================================
% % 8. DIAGNÓSTICO EN DETALLE: TRÍPTICO 2D DE LA DERIVA INERCIAL (SUBPLOT)
% % =========================================================================
% fprintf('Generando tríptico 2D con subplots para la memoria...\n');
% 
% % Creamos una única ventana maximizada horizontalmente para que se vea bien
% figure('Name', 'Análisis Bidimensional de la Deriva', 'Color', 'w', 'Units', 'normalized', 'Position', [0.1, 0.3, 0.8, 0.4]);
% 
% % --- SUBPLOT 1: Plano Horizontal (Planta) ---
% subplot(1, 3, 1);
% plot(gt_este, gt_norte, 'b--', 'LineWidth', 2, 'DisplayName', 'Pix4D (Real)');
% hold on;
% plot(hist_ins_alineado(2,:), hist_ins_alineado(1,:), 'k-', 'LineWidth', 1.5, 'DisplayName', 'INS Pura');
% grid on; axis equal;
% xlabel('Este (m)'); ylabel('Norte (m)');
% title('Vista Superior (Plano E-N)');
% legend('Location', 'best');
% 
% % --- SUBPLOT 2: Plano Vertical Norte-Abajo (Alzado Lateral) ---
% subplot(1, 3, 2);
% plot(gt_norte, gt_abajo, 'b--', 'LineWidth', 2, 'DisplayName', 'Pix4D (Real)');
% hold on;
% plot(hist_ins_alineado(1,:), hist_ins_alineado(3,:), 'k-', 'LineWidth', 1.5, 'DisplayName', 'INS Pura');
% grid on; axis equal;
% xlabel('Norte (m)'); ylabel('Abajo (m)');
% title('Vista Lateral (Plano N-D)');
% legend('Location', 'best');
% 
% % --- SUBPLOT 3: Plano Vertical Este-Abajo (Alzado Frontal) ---
% subplot(1, 3, 3);
% plot(gt_este, gt_abajo, 'b--', 'LineWidth', 2, 'DisplayName', 'Pix4D (Real)');
% hold on;
% plot(hist_ins_alineado(2,:), hist_ins_alineado(3,:), 'k-', 'LineWidth', 1.5, 'DisplayName', 'INS Pura');
% grid on; axis equal;
% xlabel('Este (m)'); ylabel('Abajo (m)');
% title('Vista Frontal (Plano E-D)');
% legend('Location', 'best');
% 
% % Título global de la composición académica
% sgtitle('Análisis de Deriva del Sistema de Navegación Inercial (INS Pura) por Planos Ortogonales', 'FontWeight', 'bold', 'FontSize', 12);
% 
% fprintf('¡Tríptico con subplots generado con éxito!\n');
%%  quizás una gráfica donde se vea el error del INS y como diverge respecto
%% del Ground Truth