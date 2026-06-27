%% =========================================================================
% TFG: FUSIÓN GNSS-INS CON EKF PARA TRAYECTORIA DE DRON
% CURSO: 2025/2026
% ALUMNO: ALEJANDRO GARCÍA MARCOS 
% TUTOR: MIGUEL ÁNGEL GÓMEZ LÓPEZ
% =========================================================================
clear; clc; close all;


%% =========================================================================
% CONFIGURACIÓN DEL ENTORNO (Cambiar según el PC)
% =========================================================================

% 1. RUTA DE LOS DATOS
carpetaData = 'D:\Universidad\4º_Año_de_verdad\TFG\Dataset con datos reales (dron Zúrich)\AGZ\AGZ\Log Files';


%% =========================================================================
% 1. LECTURA Y ALINEACIÓN DE TIEMPOS (T0 = Primer sensor en arrancar)
% =========================================================================
fprintf('Cargando datos y sincronizando relojes (Alineamiento por mínimo)...\n');
opts = {'Delimiter', ',', 'VariableNamingRule', 'preserve'};

tabla_gps   = readtable(fullfile(carpetaData, 'OnboardGPS.csv'), opts{:});
tabla_accel = readtable(fullfile(carpetaData, 'RawAccel.csv'), opts{:});
tabla_gyro  = readtable(fullfile(carpetaData, 'RawGyro.csv'), opts{:});
tabla_gt    = readtable(fullfile(carpetaData, 'GroundTruthAGL.csv'), opts{:});
tabla_baro  = readtable(fullfile(carpetaData, 'BarometricPressure.csv'), opts{:});

% --- ALINEACIÓN TEMPORAL GLOBAL (T0 = min) ---
% Extraemos los arranques usando la columna 'Timpstemp' (con la errata del CSV)
t0_gps_crudo   = tabla_gps.Timpstemp(1);
t0_accel_crudo = tabla_accel.Timpstemp(1);
t0_baro_crudo  = tabla_baro.Timpstemp(1);

% T0 Global es el mínimo absoluto: el instante en el que el primer sensor cobra vida
t0_global = min([t0_gps_crudo, t0_accel_crudo, t0_baro_crudo]);

% Convertimos a segundos relativos al T0 Global (Todos serán >= 0)
t_gps   = double(tabla_gps.Timpstemp - t0_global) / 1e6;
t_accel = double(tabla_accel.Timpstemp - t0_global) / 1e6;
t_baro  = double(tabla_baro.Timpstemp - t0_global) / 1e6;
t_imu   = t_accel; % Tu bucle principal asume que se llama t_imu

% --- EXTRACCIÓN DIRECTA DE LECTURAS (Sin recortar nada) ---
% IMU (Acelerómetros y Giróscopos)
a_x = tabla_accel.x; a_y = tabla_accel.y; a_z = tabla_accel.z;
w_x = tabla_gyro.x;  w_y = tabla_gyro.y;  w_z = tabla_gyro.z;

% GPS (Sin factores de escala extraños, el CSV ya está en grados/metros)
gps_lat = double(tabla_gps.lat);
gps_lon = double(tabla_gps.lon);
gps_alt = double(tabla_gps.alt);

% Ground Truth 
gt_x = tabla_gt.x_gt; gt_y = tabla_gt.y_gt; gt_z = tabla_gt.z_gt;

%% =========================================================================
% 2. TRANSFORMACIÓN "FLAT EARTH"
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
% 3. DIAGNÓSTICO PREVIO: ERROR GNSS POR PLANOS ORTOGONALES
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
% 4. DIAGNÓSTICO PREVIO: ERROR EUCLÍDEO DEL GPS VS GROUND TRUTH
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
% 5. EXTRACCIÓN Y REPRESENTACIÓN DE LA ACTITUD DEL PIXHAWK (EULER)
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
% 6. REPRESENTACIÓN DE LA ACTITUD DEL PIXHAWK (GRÁFICA ÚNICA)
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
% 7.. FILTRO DE KALMAN E INTEGRACIÓN INERCIAL PURA
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
% 8. ANÁLISIS DE SENSIBILIDAD EKF (TUNING Q Y R)
% =========================================================================
%Lo que ocurría en el bucle
%anterior es que asumimos que Q tenía mucho ruido y R poco, entonces lo
%que pasa es que el filtro confía ciegamente en los datos GPS. Sin embargo
%como vimos en las gráficas de error los datos GPS también acumulan error,
%y hay que ser consistente y tener un equilibrio entre el peso que se le da
%tanto a los datos GPS como INS. 


fprintf('Iniciando Análisis de Sensibilidad del EKF (3 Escenarios)...\n');
g = 9.81; 
gravedad_n = [0; 0; g]; 
I_9 = eye(9);
H = [eye(3), zeros(3, 6)]; 
num_muestras = length(t_accel);

% Variables para almacenar resultados
nombres_casos = {'Caso A: INS > GNSS (Deriva)', 'Caso B: GNSS > INS (Ruido)', 'Caso C: Ajuste Óptimo'};
historiales_pos = cell(1, 3);
rmses_ekf = zeros(1, 3);
P_gt_transpuesta = [gt_norte, gt_este, gt_abajo]';

for caso = 1:3
    fprintf('  -> Ejecutando %s...\n', nombres_casos{caso});
    
    % --- 1. CONFIGURACIÓN DE MATRICES ESTOCÁSTICAS SEGÚN CASO ---
    x_est = zeros(9,1);
    P = diag([1 1 1, 0.5 0.5 0.5, deg2rad(5)*ones(1,3)]); 
    
    if caso == 1
        % CASO A: Sobreconfianza en INS (Q pequeña, R enorme)
        sigma_pos = 0.01; 
        sigma_vel = 0.01; 
        sigma_att = deg2rad(0.1);
        R = diag([50^2, 50^2, 100^2]); 
    elseif caso == 2
        % CASO B: Sobreconfianza en GNSS (Q enorme, R pequeña)
        sigma_pos = 10.0; sigma_vel = 10.0; sigma_att = deg2rad(20.0);
        R = diag([0.01^2, 0.01^2, 0.01^2]); 
    else
        % CASO C: Sweet Spot (Equilibrio)
        sigma_pos = 0.2; 
        sigma_vel = 0.2; 
        sigma_att = deg2rad(0.5); 
        R = diag([3.0^2, 3.0^2, 6.0^2]); 
        
    end
    
    Q_c = diag([sigma_pos^2*ones(1,3), sigma_vel^2*ones(1,3), sigma_att^2*ones(1,3)]);
    
    % --- 2. REINICIO Y ANCLAJE DE CONDICIONES INICIALES ---
    hist_pos = zeros(3, num_muestras);
    idx_gps = 1;
    while idx_gps <= length(t_gps_unique) && t_gps_unique(idx_gps) < t_accel(1)
        idx_gps = idx_gps + 1;
    end
    
    if idx_gps < length(t_gps_unique)
        x_est(1:3) = [p_gps_norte_u(idx_gps); p_gps_este_u(idx_gps); p_gps_abajo_u(idx_gps)];
        yaw_inicial = atan2(p_gps_este_u(idx_gps+1) - p_gps_este_u(idx_gps), ...
                            p_gps_norte_u(idx_gps+1) - p_gps_norte_u(idx_gps));
        x_est(9) = yaw_inicial; 
    end
    
    % --- 3. MOTOR EKF ASÍNCRONO ---
    for k = 2:num_muestras
        dt = t_accel(k) - t_accel(k-1);
        if dt <= 0, dt = 1e-4; end 
        
        a_b = [a_x(k); a_y(k); a_z(k)];
        w_b = [w_x(k); w_y(k); w_z(k)];
        
        phi = x_est(7); theta = x_est(8); psi = x_est(9);
        R_b_n = [cos(theta)*cos(psi), sin(phi)*sin(theta)*cos(psi)-cos(phi)*sin(psi), cos(phi)*sin(theta)*cos(psi)+sin(phi)*sin(psi);
                 cos(theta)*sin(psi), sin(phi)*sin(theta)*sin(psi)+cos(phi)*cos(psi), cos(phi)*sin(theta)*sin(psi)-sin(phi)*cos(psi);
                 -sin(theta),         sin(phi)*cos(theta),                            cos(phi)*cos(theta)];
        a_n = R_b_n * a_b + gravedad_n; 
        
        % Predicción
        p_prev = x_est(1:3); v_prev = x_est(4:6);
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
        
        P_pred = F * P * F' + Q_c * dt; 
        
        x_est = x_pred;
        P = P_pred;
        
        % Corrección Asíncrona
        while idx_gps <= length(t_gps_unique) && t_accel(k) >= t_gps_unique(idx_gps)
            z_gps = [p_gps_norte_u(idx_gps); p_gps_este_u(idx_gps); p_gps_abajo_u(idx_gps)];
            y_innov = z_gps - H * x_pred;
            S = H * P_pred * H' + R;
            K = P_pred * H' / S;
            
            x_est = x_pred + K * y_innov;
            P = (I_9 - K * H) * P_pred * (I_9 - K * H)' + K * R * K'; 
            
            x_pred = x_est;
            P_pred = P;
            idx_gps = idx_gps + 1; 
        end
        hist_pos(:, k) = x_est(1:3);
    end
    
    % --- 4. CÁLCULO DE ERROR DE ESTE CASO ---
    error_distancia = zeros(num_muestras, 1);
    for i = 1:num_muestras
        distancias = sqrt((P_gt_transpuesta(1,:) - hist_pos(1,i)).^2 + ...
                          (P_gt_transpuesta(2,:) - hist_pos(2,i)).^2 + ...
                          (P_gt_transpuesta(3,:) - hist_pos(3,i)).^2);
        error_distancia(i) = min(distancias);
    end
    
    historiales_pos{caso} = hist_pos;
    rmses_ekf(caso) = sqrt(mean(error_distancia.^2));
end

% =========================================================================
% 9. REPRESENTACIÓN GRÁFICA MULTI-ESCENARIO
% =========================================================================
figure('Name', 'Análisis de Sensibilidad EKF', 'Color', 'w', 'Units', 'normalized', 'Position', [0.05, 0.2, 0.9, 0.5]);
colores_ekf = {'#D95319', '#A2142F', '#0072BD'}; % Naranja, Granate, Azul

for caso = 1:3
    subplot(1, 3, caso);
    % Ground Truth
    plot3(gt_norte, gt_este, gt_abajo, 'k--', 'LineWidth', 1.5, 'DisplayName', 'Pix4D (Real)'); hold on;
    % GPS Crudo
    plot3(p_gps_norte, p_gps_este, p_gps_abajo, '.', 'Color', [0.7 0.7 0.7], 'MarkerSize', 3, 'DisplayName', 'GNSS Crudo');
    % Estimación EKF
    h_pos = historiales_pos{caso};
    plot3(h_pos(1,:), h_pos(2,:), h_pos(3,:), '-', 'Color', colores_ekf{caso}, 'LineWidth', 1.5, 'DisplayName', 'EKF');
    
    grid on; axis equal; view(3);
    xlabel('Norte (m)'); ylabel('Este (m)'); zlabel('Abajo (m)');
    title(sprintf('%s\nRMSE: %.2f m', nombres_casos{caso}, rmses_ekf(caso)), 'FontSize', 11);
    legend('Location', 'best', 'FontSize', 8);
end

sgtitle('Impacto del Tuning de Matrices (Q y R) en la Navegación', 'FontWeight', 'bold', 'FontSize', 14);

fprintf('\n--- RESULTADOS FINALES DEL ANÁLISIS ---\n');
fprintf('RMSE Línea Base GNSS : %.3f m\n', rmse_gps);
for caso = 1:3
    fprintf('RMSE %s: %.3f m\n', nombres_casos{caso}, rmses_ekf(caso));
end
fprintf('---------------------------------------\n');

%% =========================================================================
% 10. ALINEACIÓN DE CENTROS DE MASA Y CÁLCULO DE ERROR RMSE
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
% 11. REPRESENTACIÓN GRÁFICA (TFG)
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
% % 12. DIAGNÓSTICO EN DETALLE: TRÍPTICO 2D DE LA DERIVA INERCIAL (SUBPLOT)
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



%% =========================================================================
% 13. INICIALIZACIÓN: ESTIMACIÓN DINÁMICA ANTI-MULTIPATH. (EKF 15 ESTADOS)
% =========================================================================
fprintf('\nIniciando EKF 15 Estados: Aprendizaje en vuelo ultra-lento...\n');

% Arrancamos a ciegas (en vuelo)
x_est_15 = zeros(15,1);

% Matriz P_15: Incertidumbre inicial microscópica para los sesgos

% 2. Matriz P_15: Apertura total del Yaw
% Le decimos al filtro: "No confíes en el Yaw inicial calculado por GPS, averígualo tú"
P_15 = diag([1 1 1, ...                     
    0.5 0.5 0.5, ...               
    deg2rad(5), deg2rad(5), deg2rad(90), ... % <--- 90º de margen de error en Yaw
    1e-4*ones(1,3), ...            
    1e-5*ones(1,3)]);              

% (Mantén la matriz Q_c_15 que teníamos con 1e-6 y 1e-7 intacta)

% 4. Matriz R_15: Penalización severa del GPS por Multipath en cañón urbano
% Desconfianza masiva en el GPS (Asumimos Multipath urbano severo)
R_15 = diag([5^2, 5^2, 10^2]); % <--- Antes teníamos 3, 3, 6


% 2. Matriz Q_c_15: CONFIANZA CIEGA EN LA IMU
% Reducimos al mínimo la incertidumbre de la posición y velocidad inercial
sigma_pos_15 = 0.01;      % ANTES 0.1. Confiamos mucho en la cinemática
sigma_vel_15 = 0.01;      % ANTES 0.1.
sigma_att_15 = deg2rad(0.1); % ANTES 0.5.
sigma_ba_15  = 1e-6;      % Mantenemos el sesgo muy rígido
sigma_bg_15  = 1e-7;

Q_c_15 = diag([sigma_pos_15^2*ones(1,3), sigma_vel_15^2*ones(1,3), sigma_att_15^2*ones(1,3), ...
    sigma_ba_15^2*ones(1,3), sigma_bg_15^2*ones(1,3)]);  

H_15 = [eye(3), zeros(3, 12)]; 
I_15 = eye(15);
% =========================================================================

% =========================================================================

% --- 2. PREPARACIÓN DE HISTORIALES INDEPENDIENTES ---
hist_pos_15 = zeros(3, num_muestras);
hist_bias_acc = zeros(3, num_muestras);
hist_bias_gyr = zeros(3, num_muestras);

idx_gps_15 = 1;
while idx_gps_15 <= length(t_gps_unique) && t_gps_unique(idx_gps_15) < t_accel(1)
    idx_gps_15 = idx_gps_15 + 1;
end

if idx_gps_15 < length(t_gps_unique)
    x_est_15(1:3) = [p_gps_norte_u(idx_gps_15); p_gps_este_u(idx_gps_15); p_gps_abajo_u(idx_gps_15)];
    yaw_inicial_15 = atan2(p_gps_este_u(idx_gps_15+1) - p_gps_este_u(idx_gps_15), ...
                           p_gps_norte_u(idx_gps_15+1) - p_gps_norte_u(idx_gps_15));
    x_est_15(9) = yaw_inicial_15; 
end

% --- 3. BUCLE DE INTEGRACIÓN ASÍNCRONA CORREGIDO (INS + GPS) ---
for k = 2:num_muestras
    dt = t_accel(k) - t_accel(k-1);
    if dt <= 0, dt = 1e-4; end 

    % LAZO CERRADO: Restamos los sesgos estimados
    a_b_limpia = [a_x(k); a_y(k); a_z(k)] - x_est_15(10:12);
    w_b_limpia = [w_x(k); w_y(k); w_z(k)] - x_est_15(13:15);

    phi_15 = x_est_15(7); theta_15 = x_est_15(8); psi_15 = x_est_15(9);

    % 1. Matriz de Rotación (Body a NED para Aceleraciones)
    R_b_n_15 = [cos(theta_15)*cos(psi_15), sin(phi_15)*sin(theta_15)*cos(psi_15)-cos(phi_15)*sin(psi_15), cos(phi_15)*sin(theta_15)*cos(psi_15)+sin(phi_15)*sin(psi_15);
        cos(theta_15)*sin(psi_15), sin(phi_15)*sin(theta_15)*sin(psi_15)+cos(phi_15)*cos(psi_15), cos(phi_15)*sin(theta_15)*sin(psi_15)-sin(phi_15)*cos(psi_15);
        -sin(theta_15),            sin(phi_15)*cos(theta_15),                                     cos(phi_15)*cos(theta_15)];

    a_n_15 = R_b_n_15 * a_b_limpia + gravedad_n; 

    % 2. LA CLAVE: Matriz de Tasas de Euler (Body Rates a Euler Rates)
    E_mat = [1, sin(phi_15)*tan(theta_15), cos(phi_15)*tan(theta_15);
        0, cos(phi_15),               -sin(phi_15);
        0, sin(phi_15)/cos(theta_15), cos(phi_15)/cos(theta_15)];

    % Predicción cinemática
    p_prev_15 = x_est_15(1:3); v_prev_15 = x_est_15(4:6);
    x_pred_15 = zeros(15,1);

    x_pred_15(1:3)   = p_prev_15 + v_prev_15 * dt + 0.5 * a_n_15 * dt^2; 
    x_pred_15(4:6)   = v_prev_15 + a_n_15 * dt;                       
    x_pred_15(7:9)   = x_est_15(7:9) + (E_mat * w_b_limpia) * dt; % <-- Corrección aquí                   
    x_pred_15(10:15) = x_est_15(10:15); 

    % Jacobiano extendido de 15x15
    F_15 = eye(15);
    F_15(1:3, 4:6) = eye(3) * dt; 

    % Derivadas de la matriz de rotación (Igual que tenías)
    dR_dphi_15 = [0,  cos(phi_15)*sin(theta_15)*cos(psi_15)+sin(phi_15)*sin(psi_15), -sin(phi_15)*sin(theta_15)*cos(psi_15)+cos(phi_15)*sin(psi_15);
        0,  cos(phi_15)*sin(theta_15)*sin(psi_15)-sin(phi_15)*cos(psi_15), -sin(phi_15)*sin(theta_15)*sin(psi_15)-cos(phi_15)*cos(psi_15);
        0,  cos(phi_15)*cos(theta_15),                                     -sin(phi_15)*cos(theta_15)];
    dR_dtheta_15 = [-sin(theta_15)*cos(psi_15), sin(phi_15)*cos(theta_15)*cos(psi_15), cos(phi_15)*cos(theta_15)*cos(psi_15);
        -sin(theta_15)*sin(psi_15), sin(phi_15)*cos(theta_15)*sin(psi_15), cos(phi_15)*cos(theta_15)*sin(psi_15);
        -cos(theta_15),             -sin(phi_15)*sin(theta_15),            -cos(phi_15)*sin(theta_15)];
    dR_dpsi_15 = [-cos(theta_15)*sin(psi_15), -sin(phi_15)*sin(theta_15)*sin(psi_15)-cos(phi_15)*cos(psi_15), -cos(phi_15)*sin(theta_15)*sin(psi_15)+sin(phi_15)*cos(psi_15);
        cos(theta_15)*cos(psi_15),  sin(phi_15)*sin(theta_15)*cos(psi_15)-cos(phi_15)*sin(psi_15),  cos(phi_15)*sin(theta_15)*cos(psi_15)+sin(phi_15)*sin(psi_15);
        0,                          0,                                                             0];

    F_15(4:6, 7:9)   = [dR_dphi_15 * a_b_limpia, dR_dtheta_15 * a_b_limpia, dR_dpsi_15 * a_b_limpia] * dt;
    F_15(4:6, 10:12) = -R_b_n_15 * dt; 

    % 3. CORRECCIÓN DEL JACOBIANO DE ACTITUD
    % A) Derivadas de las Tasas de Euler respecto a los propios ángulos phi y theta
    wx = w_b_limpia(1); wy = w_b_limpia(2); wz = w_b_limpia(3);

    dEuler_dAtt = [ (cos(phi_15)*tan(theta_15)*wy - sin(phi_15)*tan(theta_15)*wz), (sin(phi_15)*sec(theta_15)^2*wy + cos(phi_15)*sec(theta_15)^2*wz), 0;
        -(sin(phi_15)*wy + cos(phi_15)*wz),                             0,                                                               0;
        (cos(phi_15)*sec(theta_15)*wy - sin(phi_15)*sec(theta_15)*wz), (sin(phi_15)*sec(theta_15)*tan(theta_15)*wy + cos(phi_15)*sec(theta_15)*tan(theta_15)*wz), 0 ];

    F_15(7:9, 7:9)   = eye(3) + dEuler_dAtt * dt;

    % B) Acoplamiento del sesgo del giróscopo a la actitud (multiplicado por E_mat)
    F_15(7:9, 13:15) = -E_mat * dt; % <-- Corrección aquí

    % Propagación de covarianza
    P_pred_15 = F_15 * P_15 * F_15' + Q_c_15 * dt ; 

    x_est_15 = x_pred_15;
    P_15 = P_pred_15;

    % Corrección asíncrona por satélite (GNSS 3D Crudo)
    while idx_gps_15 <= length(t_gps_unique) && t_accel(k) >= t_gps_unique(idx_gps_15)
        z_gps = [p_gps_norte_u(idx_gps_15); p_gps_este_u(idx_gps_15); p_gps_abajo_u(idx_gps_15)];
        y_innov = z_gps - H_15 * x_pred_15;

        S = H_15 * P_pred_15 * H_15' + R_15;
        K = P_pred_15 * H_15' / S;

        x_est_15 = x_pred_15 + K * y_innov;
        P_15 = (I_15 - K * H_15) * P_pred_15 * (I_15 - K * H_15)' + K * R_15 * K'; 

        x_pred_15 = x_est_15;
        P_pred_15 = P_15;
        idx_gps_15 = idx_gps_15 + 1; 
    end

    hist_pos_15(:, k) = x_est_15(1:3);
    hist_bias_acc(:, k) = x_est_15(10:12);
    hist_bias_gyr(:, k) = x_est_15(13:15);
end

% --- 4. CÁLCULO DE ERROR EUCLÍDEO DEL EKF 15 ---
error_ekf15_distancia = zeros(num_muestras, 1);
for i = 1:num_muestras
    P_ekf_actual = hist_pos_15(:, i);
    distancias = sqrt((P_gt_transpuesta(1,:) - P_ekf_actual(1)).^2 + ...
                      (P_gt_transpuesta(2,:) - P_ekf_actual(2)).^2 + ...
                      (P_gt_transpuesta(3,:) - P_ekf_actual(3)).^2);
    error_ekf15_distancia(i) = min(distancias);
end
rmse_ekf15 = sqrt(mean(error_ekf15_distancia.^2));


% --- 5. IMPRESIÓN DE BALANCE COMPARTIDO ---
fprintf('\n================ COMPARATIVA FINAL DE RENDIMIENTO ================ \n');
fprintf('RMSE GPS Crudo          : %.3f metros\n', rmse_gps);

% CORRECCIÓN: Llamamos a rmses_ekf(3) si mantienes el bucle de 3 casos, 
% o pon el nombre exacto de tu variable si lo cambiaste.
fprintf('RMSE EKF 9 Estados (C)  : %.3f metros\n', rmses_ekf(3)); 

fprintf('RMSE EKF 15 Estados     : %.3f metros\n', rmse_ekf15);
fprintf('Mejora absoluta del 15E : %.1f%% respecto al GPS crudo\n', 100 * (rmse_gps - rmse_ekf15) / rmse_gps);
fprintf('==================================================================\n');


% =========================================================================
% 14. ANÁLISIS DE LA CONTAMINACIÓN DE SESGOS (EKF 15 ESTADOS)
% =========================================================================
figure('Name', 'Autopsia del Filtro: Evolución de Sesgos', 'NumberTitle', 'off');
clf;

% --- 1. Gráfica de los Sesgos del Acelerómetro ---
subplot(2,1,1);
hold on;
plot(t_accel, hist_bias_acc(1,:), 'r', 'LineWidth', 1.2, 'DisplayName', 'Sesgo X (Roll)');
plot(t_accel, hist_bias_acc(2,:), 'g', 'LineWidth', 1.2, 'DisplayName', 'Sesgo Y (Pitch)');
plot(t_accel, hist_bias_acc(3,:), 'b', 'LineWidth', 1.5, 'DisplayName', 'Sesgo Z (Vertical)');
title('Evolución de los Sesgos Estimados (Acelerómetros)');
xlabel('Tiempo (s)');
ylabel('Sesgo Falso inyectado (m/s^2)');
grid on;
legend('Location', 'best');
hold off;

% --- 2. Gráfica de los Sesgos del Giróscopo ---
subplot(2,1,2);
hold on;
% Los pasamos a grados por segundo para leerlos de forma más intuitiva
plot(t_accel, rad2deg(hist_bias_gyr(1,:)), 'r', 'LineWidth', 1.2, 'DisplayName', 'Sesgo \omega_x');
plot(t_accel, rad2deg(hist_bias_gyr(2,:)), 'g', 'LineWidth', 1.2, 'DisplayName', 'Sesgo \omega_y');
plot(t_accel, rad2deg(hist_bias_gyr(3,:)), 'b', 'LineWidth', 1.5, 'DisplayName', 'Sesgo \omega_z');
title('Evolución de los Sesgos Estimados (Giróscopos)');
xlabel('Tiempo (s)');
ylabel('Sesgo Falso inyectado (deg/s)');
grid on;
legend('Location', 'best');
hold off;





%% =========================================================================
% 15. FILTRO DE KALMAN MULTISENSOR (GPS 2D + BARÓMETRO 1D)
% =========================================================================
fprintf('\nCalculando trayectoria EKF con fusión GPS + Barómetro...\n');

% --- 5.1 REINICIO Y AISLAMIENTO DE VARIABLES ---
% (Evita contaminación de ejecuciones anteriores en el Workspace)
x_est = zeros(9,1);
P = diag([1 1 1, 0.5 0.5 0.5, deg2rad(5)*ones(1,3)]); 
I_9 = eye(9);

% Limpiamos y prelocalizamos los historiales específicos de este filtro
hist_pos = zeros(3, num_muestras);
hist_P   = zeros(9, num_muestras);
hist_P(:, 1) = diag(P);

% --- 5.2 TUNING DEL EKF (RUIDOS DE PROCESO Y MEDIDA) ---
% Ruido de Proceso (IMU): Damos margen de incertidumbre en posición y velocidad
Q_c = diag([0.5^2*ones(1,3), 0.5^2*ones(1,3), deg2rad(0.5)^2*ones(1,3)]);  

% Medida GPS (Horizontal 2D): Confiamos en el satélite para X e Y
H_gps = [1, 0, 0, 0, 0, 0, 0, 0, 0;
    0, 1, 0, 0, 0, 0, 0, 0, 0];
R_gps = diag([1.0^2, 1.0^2]); 
idx_gps = 1; % Reinicio estricto del índice

% Medida Barómetro (Vertical 1D): Autoridad máxima en Z
H_baro = [0, 0, 1, 0, 0, 0, 0, 0, 0]; 
R_baro = 0.1^2; % Alta confianza en la presión (10 cm de incertidumbre)
idx_baro = 1; % Reinicio estricto del índice

% --- ¡AÑADE ESTO AQUÍ! PREPARACIÓN DE DATOS DEL BARÓMETRO ---
% Extraemos la altitud, la hacemos relativa al inicio y la invertimos para NED
altitud_cruda = tabla_baro.Altitude; 
z_baro = -(altitud_cruda - mean(altitud_cruda(1:50)));
% -------------------------------------------------------------

% ANCLAJE INICIAL DE POSICIÓN Y RUMBO (YAW)
while idx_gps <= length(t_gps_unique) && t_gps_unique(idx_gps) < t_accel(1)
    idx_gps = idx_gps + 1;
end

if idx_gps < length(t_gps_unique)
    x_est(1:2) = [p_gps_norte_u(idx_gps); p_gps_este_u(idx_gps)];
    % Ponemos el rumbo inicial correcto
    yaw_inicial = atan2(p_gps_este_u(idx_gps+1) - p_gps_este_u(idx_gps), ...
                        p_gps_norte_u(idx_gps+1) - p_gps_norte_u(idx_gps));
    x_est(9) = yaw_inicial; 
    
    % Seteamos el histórico inicial
    hist_pos(:, 1) = x_est(1:3);
end

% --- BUCLE PRINCIPAL DE INTEGRACIÓN ASÍNCRONA ---
for k = 2:num_muestras
    dt = t_accel(k) - t_accel(k-1);
    if dt <= 0, dt = 1e-4; end
    
    a_b = [a_x(k); a_y(k); a_z(k)];
    w_b = [w_x(k); w_y(k); w_z(k)];
    
    % --- MATRIZ DE ROTACIÓN ---
    phi = x_est(7); theta = x_est(8); psi = x_est(9);
    R_b_n = [cos(theta)*cos(psi), sin(phi)*sin(theta)*cos(psi)-cos(phi)*sin(psi), cos(phi)*sin(theta)*cos(psi)+sin(phi)*sin(psi);
             cos(theta)*sin(psi), sin(phi)*sin(theta)*sin(psi)+cos(phi)*cos(psi), cos(phi)*sin(theta)*sin(psi)-sin(phi)*cos(psi);
             -sin(theta),         sin(phi)*cos(theta),                            cos(phi)*cos(theta)];
             
    % --- CINEMÁTICA (GRAVEDAD CORREGIDA) ---
    % Como a_b ya incluye los ~9.81 m/s^2, al rotarla ya cae en el eje Z global
    a_n = R_b_n * a_b; 
    
    % --- FASE DE PREDICCIÓN ---
    p_prev = x_est(1:3); v_prev = x_est(4:6);
    x_pred = [p_prev + v_prev * dt + 0.5 * a_n * dt^2; 
              v_prev + a_n * dt; 
              x_est(7:9) + w_b * dt];
              
    % Jacobiano F
    F = eye(9); F(1:3, 4:6) = eye(3) * dt;
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
    x_est = x_pred;
    P = P_pred;
    
    % --- FASE DE CORRECCIÓN ASÍNCRONA: GPS (Solo X, Y) ---
    while idx_gps <= length(t_gps_unique) && t_accel(k) >= t_gps_unique(idx_gps)
        z_gps = [p_gps_norte_u(idx_gps); p_gps_este_u(idx_gps)]; % Observación 2D
        y_innov = z_gps - H_gps * x_est;
        
        S = H_gps * P * H_gps' + R_gps;
        K = P * H_gps' / S;
        
        x_est = x_est + K * y_innov;
        P = (I_9 - K * H_gps) * P * (I_9 - K * H_gps)' + K * R_gps * K'; 
        idx_gps = idx_gps + 1;
    end
    
    % --- FASE DE CORRECCIÓN ASÍNCRONA: BARÓMETRO (Solo Z) ---
    if idx_baro <= length(t_baro) && t_accel(k) >= t_baro(idx_baro)
        y_baro = z_baro(idx_baro) - H_baro * x_est;
        
        S_baro = H_baro * P * H_baro' + R_baro;
        K_baro = P * H_baro' / S_baro;
        
        x_est = x_est + K_baro * y_baro;
        P = (I_9 - K_baro * H_baro) * P * (I_9 - K_baro * H_baro)' + K_baro * R_baro * K_baro';
        idx_baro = idx_baro + 1;
    end
    
    % Almacenamiento
    hist_pos(:, k) = x_est(1:3);
    hist_P(:, k)   = diag(P);
end
fprintf('¡Filtro multisensor completado con segregación de ejes!\n');

% =========================================================================
% 16. ALINEACIÓN DE CENTROS DE MASA Y CÁLCULO DE ERROR RMSE REAL
% =========================================================================
fprintf('\nCalculando RMSE definitivo mediante alineación de centros de masa...\n');

% 1. Definimos la matriz de referencia del Ground Truth (3 x M)
P_gt = [gt_norte, gt_este, gt_abajo]'; 

% 2. Calculamos los offsets espaciales puros (Diferencia de medias en metros)
offset_norte = mean(hist_pos(1,:)) - mean(gt_norte);
offset_este  = mean(hist_pos(2,:)) - mean(gt_este);
offset_abajo = mean(hist_pos(3,:)) - mean(gt_abajo);

% 3. Alineamos la estimación del EKF al Ground Truth (SIN tocar la escala)
hist_pos_alineado = hist_pos - [offset_norte; offset_este; offset_abajo];

% 4. Cálculo del Error Espacial (Distancia mínima a la nube de puntos real)
num_points_ekf = size(hist_pos_alineado, 2);
error_distancia = zeros(num_points_ekf, 1);

for i = 1:num_points_ekf
    P_ekf_actual = hist_pos_alineado(:, i);
    % Distancia euclídea 3D a todos los puntos del Ground Truth
    distancias = sqrt((P_gt(1,:) - P_ekf_actual(1)).^2 + ...
        (P_gt(2,:) - P_ekf_actual(2)).^2 + ...
        (P_gt(3,:) - P_ekf_actual(3)).^2);
    % Nos quedamos con el error al punto más cercano de la ruta real
    error_distancia(i) = min(distancias);
end

% 5. Métrica final de rendimiento
rmse_3d_real = sqrt(mean(error_distancia.^2));

fprintf('--- RESULTADOS DEFINITIVOS DE LA FUSIÓN MULTISENSOR ---\n');
fprintf('RMSE 3D Espacial Real: %.4f metros\n', rmse_3d_real);

%% =========================================================================
% 17. DIAGNÓSTICO DE SALUD DEL EKF: CONVERGENCIA DE LA COVARIANZA (3-SIGMA)
% =========================================================================
fprintf('\nGenerando análisis de confianza del filtro (3-Sigma)...\n');

% 1. Extraemos la varianza de la posición (elementos 1, 2 y 3 de la diagonal de P)
var_x = hist_P(1, :);
var_y = hist_P(2, :);
var_z = hist_P(3, :);

% 2. Calculamos la desviación estándar (1-sigma)
sigma_x = sqrt(var_x);
sigma_y = sqrt(var_y);
sigma_z = sqrt(var_z);

% 3. Vector de tiempo real para el eje X de la gráfica
t_plot = t_accel - t_accel(1);

% --- Representación Gráfica ---
figure('Name', 'Salud del EKF: Límites 3-Sigma', 'Color', 'w', 'Units', 'normalized', 'Position', [0.1, 0.2, 0.8, 0.6]);

% Subplot X
subplot(3, 1, 1);
plot(t_plot, 3*sigma_x, 'b-', 'LineWidth', 1.5); hold on;
plot(t_plot, -3*sigma_x, 'b-', 'LineWidth', 1.5);
fill([t_plot; flipud(t_plot)], [3*sigma_x'; flipud(-3*sigma_x')], 'b', 'FaceAlpha', 0.1, 'EdgeColor', 'none');
grid on; ylabel('Incertidumbre X (m)');
title('Evolución de la Covarianza (Límites \pm 3\sigma)', 'FontWeight', 'bold');

% Subplot Y
subplot(3, 1, 2);
plot(t_plot, 3*sigma_y, 'r-', 'LineWidth', 1.5); hold on;
plot(t_plot, -3*sigma_y, 'r-', 'LineWidth', 1.5);
fill([t_plot; flipud(t_plot)], [3*sigma_y'; flipud(-3*sigma_y')], 'r', 'FaceAlpha', 0.1, 'EdgeColor', 'none');
grid on; ylabel('Incertidumbre Y (m)');

% Subplot Z
subplot(3, 1, 3);
plot(t_plot, 3*sigma_z, 'g-', 'LineWidth', 1.5); hold on;
plot(t_plot, -3*sigma_z, 'g-', 'LineWidth', 1.5);
fill([t_plot; flipud(t_plot)], [3*sigma_z'; flipud(-3*sigma_z')], 'g', 'FaceAlpha', 0.1, 'EdgeColor', 'none');
grid on; xlabel('Tiempo (s)'); ylabel('Incertidumbre Z (m)');

fprintf('Gráfica 3-Sigma generada. Revisa la estabilidad del "tubo".\n');

% =========================================================================
% 18. CONVERGENCIA INICIAL DE LA COVARIANZA (TRANSIENTE DEL EKF)
% =========================================================================
fprintf('\nGenerando gráfica de convergencia inicial de la covarianza...\n');

% Usamos la desviación estándar (1-sigma) en metros para que sea intuitivo
sigma_x = sqrt(hist_P(1, :));
sigma_y = sqrt(hist_P(2, :));
sigma_z = sqrt(hist_P(3, :));
t_plot = t_accel - t_accel(1);

figure('Name', 'Convergencia Inicial del Filtro', 'Color', 'w', 'Units', 'normalized', 'Position', [0.15, 0.25, 0.7, 0.5]);

% Graficamos las tres componentes juntas con distinto grosor/estilo
plot(t_plot, sigma_x, 'b-', 'LineWidth', 2, 'DisplayName', '\sigma_X (Norte)'); hold on;
plot(t_plot, sigma_y, 'r-', 'LineWidth', 2, 'DisplayName', '\sigma_Y (Este)');
plot(t_plot, sigma_z, 'g-', 'LineWidth', 2, 'DisplayName', '\sigma_Z (Abajo)');

% Formato profesional para la memoria
grid on;
set(gca, 'FontSize', 11);
xlabel('Tiempo de vuelo (s)', 'FontWeight', 'bold');
ylabel('Incertidumbre 1-\sigma (m)', 'FontWeight', 'bold');
title('Fase Transitoria: Convergencia de la Matriz de Covarianza', 'FontWeight', 'bold');
legend('Location', 'northeast');

% Hacemos zoom dinámico en los primeros 150 segundos para ver el "desplome"
% Puedes ajustar este valor si ves que tarda más o menos en aplanarse
xlim([0, min(150, t_plot(end))]);
ylim([0, max([sigma_x(1), sigma_y(1), sigma_z(1)]) * 1.1]);

fprintf('Gráfica de convergencia inicial generada.\n');


%% =========================================================================
% 19. VISUALIZACIÓN 3D DE TRAYECTORIAS (GT vs EKF vs GPS CRUDO)
% =========================================================================
fprintf('\nGenerando gráfica 3D de trayectorias con GPS crudo...\n');

% 1. Offsets (Calculados previamente para alinear todo al Ground Truth)
offset_norte_plot = mean(hist_pos(1,:)) - mean(gt_norte);
offset_este_plot  = mean(hist_pos(2,:)) - mean(gt_este);
offset_abajo_plot = mean(hist_pos(3,:)) - mean(gt_abajo);

% 2. Alineamos estimación EKF
pos_ekf_plot = hist_pos - [offset_norte_plot; offset_este_plot; offset_abajo_plot];

% 3. Alineamos el GPS crudo 
% (Aplicamos el mismo offset para mantener la relación real con el EKF)
gps_norte_plot = p_gps_norte_u - offset_norte_plot;
gps_este_plot  = p_gps_este_u - offset_este_plot;
gps_abajo_plot = p_gps_abajo_u - offset_abajo_plot;

% 4. Adaptación a ejes visuales (NED a: X=Este, Y=Norte, Z=Arriba)
x_gt  = gt_este;             y_gt  = gt_norte;             z_gt  = -gt_abajo;
x_ekf = pos_ekf_plot(2,:);   y_ekf = pos_ekf_plot(1,:);    z_ekf = -pos_ekf_plot(3,:);
x_gps = gps_este_plot;       y_gps = gps_norte_plot;       z_gps = -gps_abajo_plot;

% --- CREACIÓN DE LA FIGURA ---
figure('Name', 'Trayectoria 3D: GT vs EKF vs GPS', 'Color', 'w', 'Units', 'normalized', 'Position', [0.15, 0.15, 0.7, 0.7]);

% A. Ground Truth (Línea negra continua, representa la realidad)
plot3(x_gt, y_gt, z_gt, 'k-', 'LineWidth', 2, 'DisplayName', 'Ground Truth (Realidad)');
hold on; grid on;

% B. GPS Crudo (Puntos rojos, representa el sensor ruidoso)
% Usamos puntos '.' para no emborronar la gráfica con líneas saltarinas
plot3(x_gps, y_gps, z_gps, 'r.', 'MarkerSize', 6, 'DisplayName', 'GNSS Crudo (Medida)');

% C. EKF Multisensor (Línea azul continua, tu algoritmo)
plot3(x_ekf, y_ekf, z_ekf, 'b-', 'LineWidth', 2, 'DisplayName', 'EKF (Fusión GPS+Baro)');

% Marcadores de Inicio y Fin
plot3(x_gt(1), y_gt(1), z_gt(1), 'go', 'MarkerSize', 8, 'MarkerFaceColor', 'g', 'DisplayName', 'Inicio');
plot3(x_gt(end), y_gt(end), z_gt(end), 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r', 'DisplayName', 'Fin');

% --- FORMATO Y ESTÉTICA ---
set(gca, 'FontSize', 11);
xlabel('Este (m)', 'FontWeight', 'bold');
ylabel('Norte (m)', 'FontWeight', 'bold');
zlabel('Altitud Relativa (m)', 'FontWeight', 'bold');
title('Impacto del Filtro de Kalman frente a GNSS Crudo (RMSE: 4.15 m)', 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 11);

% Forzamos escala isométrica y perspectiva
axis equal;
view(3); 
grid minor;

fprintf('Gráfica 3D generada con éxito.\n');


% =========================================================================
% 20. ANÁLISIS DE PROYECCIONES ORTOGONALES (VISTAS 2D)
% =========================================================================
fprintf('\nGenerando trifigura de proyecciones ortogonales...\n');

% Creamos una figura ancha y profesional para la memoria
figure('Name', 'Proyecciones Ortogonales: GT vs EKF vs GPS', 'Color', 'w', ...
    'Units', 'normalized', 'Position', [0.1, 0.1, 0.8, 0.8]);

% -------------------------------------------------------------------------
% 1. VISTA EN PLANTA (Top View: Plano X-Y) -> Ocupa la mitad superior
% -------------------------------------------------------------------------
subplot(2, 2, [1, 2]);
plot(x_gt, y_gt, 'k-', 'LineWidth', 2, 'DisplayName', 'Ground Truth'); hold on;
plot(x_gps, y_gps, 'r.', 'MarkerSize', 5, 'DisplayName', 'GNSS Crudo');
plot(x_ekf, y_ekf, 'b-', 'LineWidth', 1.5, 'DisplayName', 'EKF (GPS+Baro)');
grid on; axis equal; % Escala isométrica crucial para vista superior
xlabel('Este (m)', 'FontWeight', 'bold'); 
ylabel('Norte (m)', 'FontWeight', 'bold');
title('Vista en Planta (Navegación Horizontal)', 'FontWeight', 'bold', 'FontSize', 12);
legend('Location', 'best');

% -------------------------------------------------------------------------
% 2. VISTA LATERAL 1 (Plano X-Z) -> Perfil Este - Altitud
% -------------------------------------------------------------------------
subplot(2, 2, 3);
plot(x_gt, z_gt, 'k-', 'LineWidth', 2); hold on;
plot(x_gps, z_gps, 'r.', 'MarkerSize', 5);
plot(x_ekf, z_ekf, 'b-', 'LineWidth', 1.5);
grid minor; 
xlabel('Este (m)', 'FontWeight', 'bold'); 
ylabel('Altitud Relativa (m)', 'FontWeight', 'bold');
title('Vista de Perfil (Corte Este-Altitud)', 'FontWeight', 'bold');

% -------------------------------------------------------------------------
% 3. VISTA LATERAL 2 (Plano Y-Z) -> Perfil Norte - Altitud
% -------------------------------------------------------------------------
subplot(2, 2, 4);
plot(y_gt, z_gt, 'k-', 'LineWidth', 2); hold on;
plot(y_gps, z_gps, 'r.', 'MarkerSize', 5);
plot(y_ekf, z_ekf, 'b-', 'LineWidth', 1.5);
grid minor;
xlabel('Norte (m)', 'FontWeight', 'bold'); 
ylabel('Altitud Relativa (m)', 'FontWeight', 'bold');
title('Vista de Perfil (Corte Norte-Altitud)', 'FontWeight', 'bold');

fprintf('Trifigura ortogonal generada con éxito.\n');