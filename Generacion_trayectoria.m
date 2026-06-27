%% =========================================================================
% TFG: FUSIÓN GNSS-INS CON EKF PARA TRAYECTORIA DE UN COCHE 
% CURSO: 2025/2026
% ALUMNO: ALEJANDRO GARCÍA MARCOS 
% TUTOR: MIGUEL ÁNGEL GÓMEZ LÓPEZ
% =========================================================================


%% Vamos a obtener una trayectoria con datos reales 
%A partir de los datos reales de datasets públicos proporcionados por KITTI
%primero obtendremos los puntos obtenidos del sensor GPS y pintaremos la
%trayectoria seguida, luego obtendremos los datos de actitud mediante los sensores inerciales
%aparte

%% En esta primera parte obtenemos los datos GPS y representamos

%% vamos a trabajar en otro ordenador a distancia
%por lo que vamos a clonar el repositorio y a partir de ahora los datasets
%los guardaremos en un disco duro, de esta forma no hace falta copiar todos
%los datos en cada ordenador. Para ello:

%% =========================================================================
% CONFIGURACIÓN DEL ENTORNO (Cambiar según el PC)
% =========================================================================
clear; clc; close all;

% Aquí va la letra que Windows que le haya asignado a tu disco duro externo
unidad_disco = 'D:'; 

% La ruta interna dentro de tu disco duro (esta nunca cambia)
ruta_interna = '\Universidad\4º_Año_de_verdad\TFG\Datasets con datos reales (coche)\Caso 2\2011_09_26\2011_09_26_drive_0036_sync\oxts\data';

% 1. Definimos la carpeta de trabajo uniendo la letra y la ruta
carpeta = fullfile(unidad_disco, ruta_interna);

%% =========================================================================
% 1. REPRESENTACIÓN RUTA MEDIANTE DATOS GPS
% =========================================================================
fprintf('Cargando datos del dataset de Kitti y ruta GPS...\n');

% 2. El comando 'dir' crea una lista (estructura) con todos los .txt
% '*' es un comodín que significa "cualquier nombre de archivo"
listaArchivos = dir(fullfile(carpeta, '*.txt'));

%Creamos dos vectores vacíos en los que iremos rellenando con los valores
%de latitud y longitud.

lat=zeros(1,length(listaArchivos));
lon=zeros(1,length(listaArchivos));

% 3. Obtenemos cuántos archivos hay en total
numArchivos = length(listaArchivos);

% 4. El bucle para "moverse" por cada uno
for i = 1:numArchivos
    % 'i' es nuestro índice: primero vale 1, luego 2, luego 3...
    
    % Obtenemos el nombre del archivo en la posición 'i'
    nombreActual = listaArchivos(i).name;
    
    % Construimos la ruta completa para que MATLAB sepa dónde está el archivo
    rutaCompleta = fullfile(carpeta, nombreActual);
    
    % Ahora ya puedes trabajar con el archivo (por ejemplo, leerlo)
    datos = readmatrix(rutaCompleta);
    
    lat(i)=datos(1,1);
    lon(i)=datos(1,2);
    
    
end

%Ahora para representarlos

% 2. Crea la figura de mapa
figure(1)
geoplot(lat, lon, 'r-o', 'LineWidth', 2) % 'r-o' es línea roja con círculos
title('Ruta GPS')
 
% % 3. Pon un mapa de fondo (puedes usar 'streets', 'satellite', 'topographic')
geobasemap 'satellite'

%Ya aparecen reflejados los datos en el mapa

%% ========================================================================
% 2. OBTENCIÓN Y REPRESENTACIÓN DE LA ACTITUD
% =========================================================================

carpeta = 'D:\Universidad\4º_Año_de_verdad\TFG\Datasets con datos reales (coche)\Caso 2\2011_09_26\2011_09_26_drive_0036_sync\oxts\data';

% 1. Listamos los archivos
listaArchivos = dir(fullfile(carpeta, '*.txt'));
numArchivos = length(listaArchivos);

t_archivos=1:numArchivos; %obtenemos un vector no exactamente del tiempo pero bueno

% 2. Preparamos los contenedores
copias_texto = cell(1, numArchivos); % Para guardar el texto bruto
roll = zeros(1, numArchivos);
pitch = zeros(1, numArchivos);
yaw = zeros(1, numArchivos);

% 3. El bucle para procesar y copiar
for i = 1:numArchivos
    nombreActual = listaArchivos(i).name;
    rutaCompleta = fullfile(carpeta, nombreActual);
    
    % --- NUEVA LÍNEA: Guardamos una copia del texto original ---
    % fileread lee el archivo completo como una cadena de texto (string)
    copias_texto{i} = fileread(rutaCompleta); 
    
    % --- Tu lógica actual para extraer datos numéricos ---
    datos = readmatrix(rutaCompleta);
    
    roll(i) = datos(1,4); 
    pitch(i) = datos(1,5);
    yaw(i) = datos(1,6);
end

yaw_continuo = unwrap(yaw); %es para que en la gráfica sea continuo y no haya un cambio brusco de ángulos
                            %ya que el sensor tiene un rango de -pi a pi

% 4. Ejemplo de cómo ver los datos:
% Si quieres ver el texto del tercer archivo, escribe en el Command Window:
% disp(copias_texto{3})

%Con los datos de la orientación vamos a graficarlos

figure(2)
plot(t_archivos,yaw_continuo,'r');
hold on
plot(t_archivos,roll,'r');
hold on
plot(t_archivos,pitch,'g');
ylabel('Orientación (rad)'); xlabel('Tiempo');
legend('Yaw','roll','pitch');
title('Representación actitud con datos del dron')


% De esta gráfica se aprecian los diferentes ángulos u orientaciones en
% cada archivo de la trayectoria. Se observa qe el más considerable es el
% yaw, y tiene bastante sentido ya que se trata de un coche, es decir se
% mueve simplemente en un plano horizontal. Por esto mismor sería preocupante
% que las líneas de orientación respectivas al pitch y roll tuvieran un
% valor significante, pues sería que el coche estaría levantando el morro o
% dando vueltas de campana. Afortunadamente lo único destacable es el yaw,
% es decir está girando en la carretera. 

%El salto pronunciado en la orientación es que según está definido el yaw,
%este solo va de -pi a +pi. Es por eso que cuando está dando una vuelta de
%180 grados prácticamente pasa a positivo. 


%En verdad nos ha facilitado trabajo, ya que otra forma de obtener la
%orientación sería integrando la aceleración angular y así sucesivamente de
%forma discreta. Ya que no podemos integrar funciones continuas pues no las
%tenemos para empezar. El mundo por no decir nunca, se comporta de forma
%continua. 

%% Obtenemos datos de actitud y representamos (2)

% En el apartado anterior tuvimos la suerte de que dentro de los datos
% proporcionados por la IMU ya nos daba directamente, sin tener que
% nosotros integrar ni nada. Lo ideal sería integrar y comprobar que
% efectivamente coincide con los datos de yaw, roll y pitch que nos
% proporcionaba. De esta forma veremos que concuerdan nuestros datos
% integrados y funciona bien nuestro código. 

%De igual forma que en apartados anteriores almacenaremos los valores de
%las velocidades angulares de cada eje en 3 vectores

roll_int = zeros(1, numArchivos);
pitch_int = zeros(1, numArchivos);
yaw_int = zeros(1, numArchivos);

% 3. El bucle para procesar y copiar
for i = 1:numArchivos
    nombreActual = listaArchivos(i).name;
    rutaCompleta = fullfile(carpeta, nombreActual);
    
    % --- NUEVA LÍNEA: Guardamos una copia del texto original ---
    % fileread lee el archivo completo como una cadena de texto (string)
    copias_texto{i} = fileread(rutaCompleta); 
    
    % --- Tu lógica actual para extraer datos numéricos ---
    datos = readmatrix(rutaCompleta);
    
    roll_int(i) = datos(1,18); 
    pitch_int(i) = datos(1,19);
    yaw_int(i) = datos(1,20);
end

%Además sabemos que la frecuencia de muestreo es de 10 Hz, por lo que el
%tiempo o periodo de muestreo que se toma cada dato de la IMU es la
%inversa de la frecuencia; 

freq=10; %Hz
t_muestreo= 1/freq;
dt=t_muestreo;
n = 803;            % Número de muestras
t = (0:n-1) * dt;   % Crea: 0, 0.1, 0.2, 0.3... hasta 80.2 este será nuestro
                    %vector tiempo real

% 4. Integrar los datos de actitud para obtener la orientación acumulada
% Cuando usas cumtrapz, MATLAB calcula el área de un pequeño trapecio entre
% cada dos muestras de datos. En sí es la fórmula del área

yaw_acumulado = cumtrapz(t, yaw_int);
roll_acumulado = cumtrapz(t, roll_int);
pitch_acumulado = cumtrapz(t, pitch_int);

%Vamos a representarlo 

figure(3)
plot(t,pitch_acumulado,'r');
hold on
plot(t,roll_acumulado,'g');
hold on 
plot(t, yaw_acumulado,'y');
ylabel('Orientación (rad)'); xlabel('Tiempo');
legend('Pitch','roll','Yaw');
title('Representación actitud mediante integración y sin alineamiento')

%Observamos que las curvas son prácticamente idénticas, solo que en la que
%nosotros hemos integrado la curva está desplazada. Esto se debe a que
%nosotros hemos empezado a integrar sin inicializar, es decir no le "hemos 
% dicho" a la IMU donde estaba en un inicio. 

% En términos matemáticos, cuando haces una integral indefinida (que es
% básicamente lo que hace cumtrapz desde el primer elemento), el resultado 
% es una integral más una constante. Esa constante es el valor inicial (la 
% orientación original del avión). Como cumtrapz siempre empieza en 0, si 
% tu avión ya estaba inclinado 10 grados al empezar el experimento, tu curva
% integrada y la del sensor estarán desplazadas exactamente esos 10 grados
% durante todo el trayecto. 

%Con este problema lo que vemos es la necesidad de alineación de nuestro
%sensor. 

%El sensor mediante el magnetómetro lo que ha conseguido es obtener el
%primer dato de orientación. Nosotros lo que haremos será usarlo como
%constante de integración, y de esta forma estarán las curvas igual de
%calibradas. 

% Inicializamos la constante de integración con el primer valor de yaw
yaw_offset = yaw(1); %yaw(1) es el primer elemento que nos da directamente
                     %el sensor, es la orientación

%Volvemos a reahacer nuestros vectores 
yaw_acumulado1 = yaw_acumulado + yaw_offset;

%Ya lo podremos representar

figure(4)
plot(t,pitch_acumulado,'r');
hold on
plot(t,roll_acumulado,'g');
hold on 
plot(t, yaw_acumulado1,'y');
ylabel('Orientación (rad)'); xlabel('Tiempo (s)');
legend('Pitch','roll','Yaw');
title('Representación actitud mediante integración y sin alineamiento')

%Ya son prácticamente idénticas, vamos a representarlas juntas en una misma
%grápica

% Representar las curvas de orientación acumulada juntas
figure(5)
plot(t, yaw_acumulado, 'r', t, yaw_acumulado1, 'g', t, yaw_continuo,'b');
ylabel('Orientación (rad)');
xlabel('Tiempo');
legend('Con integración Sin alineamiento', 'Con integración y con alineamiento', 'Datos proporcionados por la IMU' );
title('Comparación de Orientaciones Acumuladas');
grid on;

%Con la gráfica se comprueba que el error anterior era debido a la falta
%de alineación. Además las curvas integrada y la ya dada por el sensor
%prácticamente se solapan, aunque luego se observa un error que se va
%notando con el tiempo. Este error tiene pinta de deberse al Drift, que se
%va acumulando con el tiempo.

%Ese distanciamiento que ves es la prueba real de que tu integración es 
%correcta, pero tus datos tienen "imperfecciones". Lo que estás observando
%es exactamente lo que justifica por qué necesitamos algoritmos complejos
%(como el Filtro de Kalman) en lugar de una simple integración.

%% ========================================================================
% 3. REPRESENTACIÓN TRAYECTORIA CON DATOS CRUDOS
% =========================================================================


%Una vez obtenidos los datos de la actitud, ya sabemos la orientación que
%el vehículo obtiene en cada instante de muestreo. Es esencial para poder
%calcular correctamente las aceleraciones. 

%Además muy importante recalcar que como primera aproximación 
%no tendremos la gravedad en cuenta, ya que el pitch y roll son 
% aproximadamente 0, y asumiremos que solo hay
%giro en el plano horizontal. 

%Se asume una hipótesis de plano horizontal (Pitch y Roll nulos), por lo
%que la aceleración medida en el eje longitudinal del vehículo se proyecta 
%directamente sobre el plano de navegación mediante la matriz de rotación 
%de Yaw (ángulo phi). 

% C=[cos(yaw_acumulado1(1)) -sin(yaw_acumulado1(1)) 0;
%     sin(yaw_acumulado1(1)) cos(yaw_acumulado1(1)) 0; ...
%     0 0 1];
%Podemos usar simplemente la matriz 2x2, pues el eje x no se va a mover

C2=[cos(yaw_acumulado1(1)) -sin(yaw_acumulado1(1)) ;
    sin(yaw_acumulado1(1)) cos(yaw_acumulado1(1)) ];

%Lo anterior es un ejemplo para el primer elemento de la actitud, sin
%embargo durante todo el recorrido del vehículo la orientación será
%diferente, por lo que la aportación a los ejes navegación o globales será
%diferente. 

%Vamos de nuevo a recoger en vectores la aceleración registrada por los
%acelerómetros. Los siguientes datos serán o deberían ser los datos tomados
%desde ejes cuerpo. 

a_x = zeros(1, numArchivos);
a_y = zeros(1, numArchivos);
a_z = zeros(1, numArchivos);

v_x = zeros(1, numArchivos);
v_y = zeros(1, numArchivos);

%Estos datos son ya la velocidad proyectada en ejes navegación, o
%este-norte

v_norte=zeros(1, numArchivos);
v_este=zeros(1, numArchivos);

for i = 1:numArchivos
    nombreActual = listaArchivos(i).name;
    rutaCompleta = fullfile(carpeta, nombreActual);
    
    % --- NUEVA LÍNEA: Guardamos una copia del texto original ---
    % fileread lee el archivo completo como una cadena de texto (string)
    copias_texto{i} = fileread(rutaCompleta); 
    
    % --- Tu lógica actual para extraer datos numéricos ---
    datos = readmatrix(rutaCompleta);
    
    a_x(i) = datos(1,12); 
    a_y(i) = datos(1,13);
    a_z(i) = datos(1,14);

    v_x(i)=datos(1,9);
    v_y(i)=datos(1,10);


    %Vamos a recopilar también los vectores de la velocidad norte - este
    
    v_norte(i)=datos(1,7);
    v_este(i)=datos(1,8);

    %Vamos a ponerlo en forma de vector

    % Convert acceleration data into a 3D vector
    acceleration(:, i) = [a_x(i); a_y(i); a_z(i)]; %esto ya me crea una matriz la verdad

end

%Al igual que para el caso de la actitud, en los datos hay datos de la
%aceleración que parecen también ya haber sido procesados. Lo que haremos
%será probarlos con la matriz rotación y luego comprobar.

%Se puede hacer de dos formas, mediante bucle for o con vectorización: 
% Supongamos que yaw está en radianes y tiene N muestras
% N = length(ax);
% a_norte = zeros(N, 1);
% a_este = zeros(N, 1);
% 
% for i = 1:N
%     % 1. Creamos la matriz para el ángulo de ESTE instante
%     psi = yaw(i);
%     R = [cos(psi), -sin(psi); 
%          sin(psi),  cos(psi)];
% 
%     % 2. Multiplicamos por el vector de aceleración [ax; ay]
%     a_body = [ax(i); ay(i)];
%     a_nav = R * a_body;
% 
%     % 3. Guardamos los resultados
%     a_norte(i) = a_nav(1);
%     a_este(i) = a_nav(2);
% end

%% Vía 1: Inercial pura
%De la aceleración en ejes cuerpo, rotamos e integramos 2 veces, el error
%debería ser mucho mayor al resto

% Multiplicación directa elemento a elemento
a_norte = a_x .* cos(yaw_acumulado1) - a_y .* sin(yaw_acumulado1);
a_este  = a_x .* sin(yaw_acumulado1) + a_y .* cos(yaw_acumulado1);

%Ya tenemos las componentes de la aceleración en el plano de navegación o
%en el plano global. Ahora integrando obtendríamos la velocidad. La
%constante de integración la obtenemos de velocidad norte y este: 

vel_norte = cumtrapz(t, a_norte)+v_norte(1);
vel_este = cumtrapz(t, a_este)+v_este(1);

% Ahora que tenemos las velocidades en el plano de navegación, podemos
% calcular la posición integrando las velocidades.

pos_norte = cumtrapz(t, vel_norte);
pos_este = cumtrapz(t, vel_este);

%A priori no sabemos la constante de integración para la posición, asumimos
%constante 0

%Ahora representamos: 

% figure(6)
% plot(pos_este, pos_norte);
% xlabel('Eje este de navegación (m)'); ylabel('Eje norte de navegación (m)')
% title('Trayectoria mediante aceleración')

%Ciertamente no se parece en nada a la trayectoria generada por el GPS. El
%error acumulado por la doble integración parece importante


%% Vía 2: Odometría: chequear ángulos hay algo raro
%Teniendo la velocidad directamente en ejes cuerpo, rotamos e integramos

veloci_norte = v_y .* cos(-yaw_acumulado1) - v_x .* sin(yaw_acumulado1);
veloci_este  = v_y .* sin(-yaw_acumulado1) + v_x .* cos(yaw_acumulado1);


% Ahora que tenemos las velocidades en el plano de navegación, podemos
% calcular la posición integrando las velocidades de odometría.

posi_norte1 = cumtrapz(t, -veloci_norte);
posi_este1 = cumtrapz(t, veloci_este) ; 

%Hemos hecho un poco de trampa: hemos cambiado v_y por v_x y viceversa en
%la matriz de transformación y cambiado un signo en veloci_norte y da como
%la trayectoria. No te fies, chequear!!!!!!

%Si representamos lo que debería ocurrir es que no debería haber tanto
%error como en el caso de la obtención de trayectoria con la aceleración.

% figure(7)
% plot(posi_este1,posi_norte1);
% xlabel('Eje este de navegación (m)'); ylabel('Eje norte de navegación (m)')
% title('Trayectoria mediante odometría')

%Me sale la trayectoria tipo invertida

%% Vía 3: Referencia
%Donde ya sabemos las componentes de la velocidad en ejes globales, y solo habría
%que integrar

posi_norte = cumtrapz(t, v_norte);
posi_este = cumtrapz(t, v_este);

% figure(8)
% plot(posi_este, posi_norte);
% xlabel('Eje este de navegación (m)'); ylabel('Eje norte de navegación (m)');
% title(['Trayectoria mediante referencia' ]);
% grid on;

%Este sale representado con la forma casi iagual que la de la señal GPS

%% ========================================================================
% Se han omitido las gráficas 6, 7 y 8 por no presentar ningún resultado
% como tal relevante

%% Representación de todas

% Ahora que tenemos las posiciones calculadas, podemos comparar las trayectorias
% obtenidas por los diferentes métodos. 

figure(9)
clf; % <-- ¡AQUÍ ESTÁ LA SOLUCIÓN! Limpia el lienzo de ejecuciones anteriores
hold on;
plot(pos_este, pos_norte, 'r', 'DisplayName', 'Aceleración');
plot(posi_este1, posi_norte1, 'g', 'DisplayName', 'Odometría');
plot(posi_este, posi_norte, 'b', 'DisplayName', 'Referencia');
xlabel('Eje este de navegación (m)');
ylabel('Eje norte de navegación (m)');
title('Comparación de Trayectorias');
legend;
grid on;
hold off;

%Se observa una clara desviación completa en el caso de integrar la
%aceleración 2 veces. 
%En el caso de integrar solo la velocidad, observamos que al principio las
%curvas se solapan y coinciden bastante, y se va acumulando error con el
%tiempo. 




%% =========================================================================
% 4. FUSIÓN GNSS-INS MEDIANTE FILTRO DE KALMAN EXTENDIDO (EKF)
% =========================================================================
fprintf('Aplicando EKF...');

% 1. INICIALIZACIÓN DEL EKF
% Vector de estado inicial: [x_este; y_norte; v_x_local; v_y_local; yaw]
x_est = [posi_este(1); 
         posi_norte(1); 
         v_x(1); 
         v_y(1); 
         yaw_acumulado1(1)]; 

% Matriz de Covarianza Inicial P (Confianza inicial)
% Empezamos con mucha confianza en la pose inicial (valores bajos)
P = diag([0.1, 0.1, 0.1, 0.1, deg2rad(1)]); 

% Matriz de Ruido del Proceso Q (Incertidumbre de tu IMU)
% Ajustamos cuánto nos fiamos de las integraciones ciegas
q_pos = 0.05;
q_vel = 0.1;
q_yaw = deg2rad(1);
Q = diag([q_pos, q_pos, q_vel, q_vel, q_yaw]);

% Matriz de Ruido de Medida R (Incertidumbre del GPS y Velocímetro dataset)
r_gps_pos = 5;  % Asumimos un error de 5 metros en el GPS
r_gps_vel = 1;  % Asumimos 1 m/s de error en la velocidad medida
R = diag([r_gps_pos, r_gps_pos, r_gps_vel, r_gps_vel]);

% Matriz de Observación H (Relación lineal 1 a 1 con las 4 primeras variables)
H = [1 0 0 0 0;
     0 1 0 0 0;
     0 0 1 0 0;
     0 0 0 1 0];

I = eye(5); % Matriz identidad auxiliar

% Vectores para guardar la historia del EKF y poder graficar luego
ekf_pos_este  = zeros(1, numArchivos);
ekf_pos_norte = zeros(1, numArchivos);
ekf_yaw       = zeros(1, numArchivos);

% Guardamos el primer punto
ekf_pos_este(1)  = x_est(1);
ekf_pos_norte(1) = x_est(2);
ekf_yaw(1)       = x_est(5);

% 2. BUCLE PRINCIPAL DEL EKF (A 10 Hz)
for k = 2:numArchivos
    
    % --- DATOS DE ENTRADA EN EL INSTANTE k ---
    % IMU (Inputs u)
    ax = a_x(k); 
    ay = a_y(k); 
    wz = yaw_int(k); % Velocidad angular pura
    
    % GPS (Medidas z) -> Usamos tu Vía 3 como si fuera la antena GPS
    z = [posi_este(k); 
         posi_norte(k); 
         v_x(k); 
         v_y(k)];
    
    % Variables auxiliares del estado anterior
    vx_prev = x_est(3);
    vy_prev = x_est(4);
    th_prev = x_est(5);
    
    % --- FASE 1: PREDICCIÓN (INS) ---
    % 1. Ecuaciones cinemáticas puras (Odometría)
    x_pred = zeros(5,1);
    x_pred(1) = x_est(1) + (vx_prev * cos(th_prev) - vy_prev * sin(th_prev)) * dt;
    x_pred(2) = x_est(2) + (vx_prev * sin(th_prev) + vy_prev * cos(th_prev)) * dt;
    x_pred(3) = vx_prev + ax * dt;
    x_pred(4) = vy_prev + ay * dt;
    x_pred(5) = th_prev + wz * dt;
    
    % 2. Jacobiano F (Linealización en el punto actual)
    F = [1, 0,  cos(th_prev)*dt, -sin(th_prev)*dt, (-vx_prev*sin(th_prev) - vy_prev*cos(th_prev))*dt;
         0, 1,  sin(th_prev)*dt,  cos(th_prev)*dt, ( vx_prev*cos(th_prev) - vy_prev*sin(th_prev))*dt;
         0, 0,                1,                0,                                                 0;
         0, 0,                0,                1,                                                 0;
         0, 0,                0,                0,                                                 1];
     
    % 3. Propagación de la covarianza (Incertidumbre crece)
    P_pred = F * P * F' + Q;
    
    % --- FASE 2: CORRECCIÓN (GNSS) ---
    % 4. Innovación (Lo que mide el GPS vs lo que predecía el INS)
    y_innov = z - (H * x_pred);
    
    % 5. Covarianza de la Innovación y Ganancia de Kalman
    S = H * P_pred * H' + R;
    K = P_pred * H' / S;
    
    % 6. Actualización final del estado y la covarianza
    x_est = x_pred + K * y_innov;
    P = (I - K*H) * P_pred * (I - K*H)' + K * R * K'; % Forma de Joseph
    
    % --- GUARDADO DE DATOS ---
    ekf_pos_este(k)  = x_est(1);
    ekf_pos_norte(k) = x_est(2);
    ekf_yaw(k)       = x_est(5);
end

%% =========================================================================
% 5. CASO A: REPRESENTACIÓN DE FUSIÓN CASO SÍNCRONO
% =========================================================================
figure(10);
clf; % Limpiamos la figura por si se había quedado pillada
hold on;
% 1. Vía 2: Odometría Pura
plot(posi_este1, posi_norte1, 'g--', 'LineWidth', 1.5, 'DisplayName', 'Vía 2: Odometría');
% 2. Vía 3: Referencia GPS (con los puntos más grandes como pediste)
plot(posi_este, posi_norte, 'b.', 'MarkerSize', 15, 'DisplayName', 'Vía 3: Medidas GPS');
% 3. Vía 4: EKF
plot(ekf_pos_este, ekf_pos_norte, 'r-', 'LineWidth', 2, 'DisplayName', 'Vía 4: EKF (Fusión)');

xlabel('Eje Este (m)');
ylabel('Eje Norte (m)');
title('Comparativa de Estimación (Estática)');
legend('Location', 'best');
grid on;
axis equal;
hold off;

% ¡CLAVE! Forzamos a MATLAB a imprimir esta figura en pantalla antes de seguir
drawnow; 

% %% =========================================================================
% % REPRESENTACIÓN 2: ANIMACIÓN EN TIEMPO REAL (Figura 11)
% % =========================================================================
% figure(11);
% clf; % Lienzo limpio
% hold on;
% grid on;
% axis equal; 
% xlabel('Eje Este (m)');
% ylabel('Eje Norte (m)');
% title('Animación en Tiempo Real GNSS-INS');
% 
% % Fijamos la cámara usando la ruta del GPS con un margen
% margen = 20; 
% xlim([min(posi_este)-margen, max(posi_este)+margen]);
% ylim([min(posi_norte)-margen, max(posi_norte)+margen]);
% 
% % Creamos las líneas animadas
% linea_odom = animatedline('Color', 'g', 'LineStyle', '--', 'LineWidth', 1.5, 'DisplayName', 'Odometría');
% linea_gps  = animatedline('Color', 'b', 'Marker', '.', 'LineStyle', 'none', 'MarkerSize', 15, 'DisplayName', 'GPS');
% linea_ekf  = animatedline('Color', 'r', 'LineWidth', 2, 'DisplayName', 'EKF');
% 
% legend('Location', 'best');
% 
% % Bucle de animación (Avanzamos de 5 en 5 para que sea fluido y no tarde horas)
% for k = 1:5:numArchivos
% 
%     addpoints(linea_odom, posi_este1(k), posi_norte1(k));
%     addpoints(linea_gps, posi_este(k), posi_norte(k));
%     addpoints(linea_ekf, ekf_pos_este(k), ekf_pos_norte(k));
% 
%     % Usamos un pause mínimo en lugar de limitrate para máxima compatibilidad
%     drawnow;
%     pause(0.001); 
% end
% hold off;


%% =========================================================================
% 6. ANÁLISIS DE ERRORES: COMPARATIVA DE DERIVAS
% =========================================================================
% Calculamos el error de posición (distancia euclídea) en cada instante 'k'
% Error = sqrt( (x_estimado - x_real)^2 + (y_estimado - y_real)^2 )

% 1. Error de la integración de Aceleración (INS Pura)
error_accel = sqrt((pos_este - posi_este).^2 + (pos_norte - posi_norte).^2);

% 2. Error de la Odometría
error_odom = sqrt((posi_este1 - posi_este).^2 + (posi_norte1 - posi_norte).^2);

% 3. Error del Filtro de Kalman Extendido (EKF)
error_ekf = sqrt((ekf_pos_este - posi_este).^2 + (ekf_pos_norte - posi_norte).^2);

% Representación gráfica del error a lo largo del tiempo
% figure(12)
% clf; % Limpiamos la figura por si acaso
% hold on;
% plot(t, error_accel, 'r', 'LineWidth', 1.5, 'DisplayName', 'Error INS Pura (Aceleración)');
% plot(t, error_odom, 'g', 'LineWidth', 1.5, 'DisplayName', 'Error Odometría');
% plot(t, error_ekf, 'b', 'LineWidth', 2, 'DisplayName', 'Error EKF (Fusión)');
% 
% xlabel('Tiempo (s)', 'FontWeight', 'bold');
% ylabel('Error de Posición (m)', 'FontWeight', 'bold');
% title('Evolución del Error de Posición a lo largo de la trayectoria');
% legend('Location', 'northwest');
% grid on;

% Opcional: Hacemos un zoom limitando el eje Y, porque el error de la 
% aceleración será tan bestia que aplastará a las otras dos líneas y no 
% nos dejará ver lo bien que va el EKF. Descomenta la siguiente línea 
% si el error rojo se va a miles de metros:
% ylim([0, max(error_odom)*1.2]); 
hold off;

%% =========================================================================
% 7. ANÁLISIS DE ERRORES CON FILTRO Y SIN FILTRO  (Subplots)
% =========================================================================
figure(13)
clf; % Limpiamos la figura entera antes de dibujar para que no se solapen cosas

% --- PANEL SUPERIOR: Visión Global (La catástrofe inercial) ---
subplot(2,1,1);
hold on;
plot(t, error_accel, 'r', 'LineWidth', 1.5, 'DisplayName', 'Error INS Pura (Acel.)');
plot(t, error_odom, 'g', 'LineWidth', 1.5, 'DisplayName', 'Error Odometría');
plot(t, error_ekf, 'b', 'LineWidth', 2, 'DisplayName', 'Error EKF (Fusión)');
ylabel('Error Posición (m)', 'FontWeight', 'bold');
title('Visión Global: Divergencia de la Integración Inercial');
legend('Location', 'northwest');
grid on;
hold off;

% --- PANEL INFERIOR: Detalle de Precisión (El pulso real EKF vs Odom) ---
subplot(2,1,2);
hold on;
% Dibujamos la aceleración aunque se salga por el techo, para mantener la leyenda
plot(t, error_accel, 'r', 'LineWidth', 1.5, 'DisplayName', 'Error INS Pura (Acel.)'); 
plot(t, error_odom, 'g', 'LineWidth', 1.5, 'DisplayName', 'Error Odometría');
plot(t, error_ekf, 'b', 'LineWidth', 2, 'DisplayName', 'Error EKF (Fusión)');
xlabel('Tiempo (s)', 'FontWeight', 'bold');
ylabel('Error Posición (m)', 'FontWeight', 'bold');
title('Detalle de Precisión Acotada: Odometría vs. Filtro de Kalman');

% ¡Aquí está la magia del zoom acotando el eje Y!
ylim([0, 50]); 

legend('Location', 'northwest');
grid on;
hold off;

%% =========================================================================
% 8. CASO B: EKF 8 ESTADOS SÍNCRONO (ESTIMACIÓN DE BIAS DE INSTRUMENTACIÓN) 
% =========================================================================

% 1. INICIALIZACIÓN DEL EKF (CASO 2)
% Vector de estado inicial: [x_este; y_norte; v_x_local; v_y_local; yaw; b_ax; b_ay; b_gz]
x_est_c2 = [posi_este(1); 
            posi_norte(1); 
            v_x(1); 
            v_y(1); 
            yaw_acumulado1(1);
            0; % Bias inicial del acelerómetro en X asumido nulo
            0; % Bias inicial del acelerómetro en Y asumido nulo
            0];% Bias inicial del giróscopo en Z asumido nulo

% Matriz de Covarianza Inicial P (Confianza inicial)
% Damos más incertidumbre a los biases porque no sabemos cómo vienen de fábrica
P_c2 = diag([0.1, 0.1, 0.1, 0.1, deg2rad(1), 0.5, 0.5, deg2rad(1)]); 

% Matriz de Ruido del Proceso Q
q_pos = 0.05;
q_vel = 0.1;
q_yaw = deg2rad(1);
q_ba = 1e-6;  % Obligamos al filtro a creer que el bias es casi constante
q_bw = 1e-8;
Q_c2 = diag([q_pos, q_pos, q_vel, q_vel, q_yaw, q_ba, q_ba, q_bw]);

% Matriz de Ruido de Medida R (Mismo ruido GNSS que en el Caso 1)
r_gps_pos = 5;  
r_gps_vel = 1;  
R_c2 = diag([r_gps_pos, r_gps_pos, r_gps_vel, r_gps_vel]);

% Matriz de Observación H (El GPS sigue sin poder medir los biases)
H_c2 = [eye(4), zeros(4, 4)];
I_c2 = eye(8);

% Vectores para guardar la historia del Caso 2
ekf_c2_pos_este  = zeros(1, numArchivos);
ekf_c2_pos_norte = zeros(1, numArchivos);
ekf_c2_yaw       = zeros(1, numArchivos);
ekf_c2_bax       = zeros(1, numArchivos);
ekf_c2_bay       = zeros(1, numArchivos);
ekf_c2_bgz       = zeros(1, numArchivos);

% Guardamos el primer punto
ekf_c2_pos_este(1)  = x_est_c2(1);
ekf_c2_pos_norte(1) = x_est_c2(2);
ekf_c2_yaw(1)       = x_est_c2(5);

% 2. BUCLE PRINCIPAL DEL EKF (CASO 2)
for k = 2:numArchivos
    
    % --- DATOS DE ENTRADA ---
    ax_med = a_x(k); 
    ay_med = a_y(k); 
    wz_med = yaw_int(k); 
    
    z = [posi_este(k); posi_norte(k); v_x(k); v_y(k)];
    
    % Variables auxiliares del estado anterior
    vx_prev = x_est_c2(3);
    vy_prev = x_est_c2(4);
    th_prev = x_est_c2(5);
    bax_prev= x_est_c2(6);
    bay_prev= x_est_c2(7);
    bgz_prev= x_est_c2(8);
    
    % --- COMPENSACIÓN INSTRUMENTAL ---
    ax_c = ax_med - bax_prev;
    ay_c = ay_med - bay_prev;
    wz_c = wz_med - bgz_prev;
    
    % --- FASE 1: PREDICCIÓN (INS COMPENSADA) ---
    x_pred_c2 = zeros(8,1);
    x_pred_c2(1) = x_est_c2(1) + (vx_prev * cos(th_prev) - vy_prev * sin(th_prev)) * dt;
    x_pred_c2(2) = x_est_c2(2) + (vx_prev * sin(th_prev) + vy_prev * cos(th_prev)) * dt;
    x_pred_c2(3) = vx_prev + ax_c * dt;
    x_pred_c2(4) = vy_prev + ay_c * dt;
    x_pred_c2(5) = th_prev + wz_c * dt;
    x_pred_c2(6) = bax_prev; % Modelo Random Walk (se asume constante)
    x_pred_c2(7) = bay_prev;
    x_pred_c2(8) = bgz_prev;
    
    % Jacobiano F de 8x8
    F_c2 = eye(8);
    F_c2(1,3) = cos(th_prev)*dt; F_c2(1,4) = -sin(th_prev)*dt;
    F_c2(2,3) = sin(th_prev)*dt; F_c2(2,4) = cos(th_prev)*dt;
    F_c2(1,5) = (-vx_prev*sin(th_prev) - vy_prev*cos(th_prev))*dt;
    F_c2(2,5) = ( vx_prev*cos(th_prev) - vy_prev*sin(th_prev))*dt;
    F_c2(3,6) = -dt; % Acoplamiento del bias de ax a la velocidad x
    F_c2(4,7) = -dt; % Acoplamiento del bias de ay a la velocidad y
    F_c2(5,8) = -dt; % Acoplamiento del bias de wz al yaw
    
    P_pred_c2 = F_c2 * P_c2 * F_c2' + Q_c2;
    
    % --- FASE 2: CORRECCIÓN (GNSS) ---
    y_innov_c2 = z - (H_c2 * x_pred_c2);
    
    S_c2 = H_c2 * P_pred_c2 * H_c2' + R_c2;
    K_c2 = P_pred_c2 * H_c2' / S_c2;
    
    x_est_c2 = x_pred_c2 + K_c2 * y_innov_c2;
    P_c2 = (I_c2 - K_c2*H_c2) * P_pred_c2 * (I_c2 - K_c2*H_c2)' + K_c2 * R_c2 * K_c2'; 
    
    % --- GUARDADO DE DATOS ---
    ekf_c2_pos_este(k)  = x_est_c2(1);
    ekf_c2_pos_norte(k) = x_est_c2(2);
    ekf_c2_yaw(k)       = x_est_c2(5);
    ekf_c2_bax(k)       = x_est_c2(6);
    ekf_c2_bay(k)       = x_est_c2(7);
    ekf_c2_bgz(k)       = x_est_c2(8);
end

%% =========================================================================
% 9.REPRESENTACIÓN Y ANÁLISIS DEL ERROR EN CASO A Y B (CON Y SIN BIAS)
% =========================================================================

% 1. Cálculo del error del Caso 2
error_ekf_c2 = sqrt((ekf_c2_pos_este - posi_este).^2 + (ekf_c2_pos_norte - posi_norte).^2);

% 2. Figura 13: Comparativa definitiva de Precisión (Caso 1 vs Caso 2)
figure(14)
clf; 
hold on;
plot(t, error_ekf, 'r', 'LineWidth', 1.5, 'DisplayName', 'Caso 1: EKF 5 Estados (Sin Bias)');
plot(t, error_ekf_c2, 'b', 'LineWidth', 2, 'DisplayName', 'Caso 2: EKF 8 Estados (Con Bias)');
xlabel('Tiempo (s)', 'FontWeight', 'bold');
ylabel('Error de Posición (m)', 'FontWeight', 'bold');
title('Comparación del error absoluto para el Caso 1 y Caso 2');
legend('Location', 'best');
grid on; 
hold off;

% 3. Figura 14: Evolución Temporal de los Biases (La Autocalibración)
figure(15)
clf;
subplot(2,1,1);
plot(t, ekf_c2_bax, 'b', 'LineWidth', 1.5, 'DisplayName', 'Sesgo X (b_{ax})'); hold on;
plot(t, ekf_c2_bay, 'r', 'LineWidth', 1.5, 'DisplayName', 'Sesgo Y (b_{ay})');
grid on; 
title('Autocalibración de los Acelerómetros en Tiempo Real');
xlabel('Tiempo (s)'); ylabel('Aceleración (m/s^2)'); 
legend('Location', 'best');

subplot(2,1,2);
plot(t, rad2deg(ekf_c2_bgz), 'Color', [0.4660 0.6740 0.1880], 'LineWidth', 1.5, 'DisplayName', 'Sesgo Z (b_{gz})');
grid on; 
title('Autocalibración del Giróscopo en Tiempo Real');
xlabel('Tiempo (s)'); ylabel('Vel. Angular (deg/s)'); 
legend('Location', 'best');



%% ========================================================================
% 10. CASO 2 ASÍNCRONO (CON BIAS)
% =========================================================================
clc; % Limpiamos consola
% OJO: Asegúrate de tener los datos originales cargados en el Workspace

% 1. INTERPOLACIÓN Y PREPARACIÓN
factor_interp = 10; % Resolución (1=Crudo, 10=Sobre-muestreo)
t_fino = linspace(t(1), t(end), length(t) * factor_interp);
dt_fino = t_fino(2) - t_fino(1);

ax_fino = interp1(t, a_x, t_fino, 'linear');
ay_fino = interp1(t, a_y, t_fino, 'linear');
wz_fino = interp1(t, yaw_int, t_fino, 'linear');

% Filtro antialiasing (Media móvil)
ventana = 5;
ax_fino = movmean(ax_fino, ventana);
ay_fino = movmean(ay_fino, ventana);
wz_fino = movmean(wz_fino, ventana);

% 2. INICIALIZACIÓN DEL FILTRO (8 Estados: pos, vel, yaw, bias_ax, bias_ay, bias_wz)
x = [posi_este(1); posi_norte(1); v_x(1); v_y(1); yaw_acumulado1(1); 0; 0; 0];
P = eye(8) * 0.1; 
R = diag([5, 5, 1, 1]); % Ruido GNSS
Q2 = diag([0.05, 0.05, 0.1, 0.1, deg2rad(1), 1e-6, 1e-6, 1e-8]);
res_x2 = zeros(2, length(t_fino));

% 3. BUCLE EKF PROFESIONAL
for k = 1:length(t_fino)
    % A) PREDICCIÓN (INS)
    th = x(5);
    % Modelo no lineal
    f = [x(1) + (x(3)*cos(th) - x(4)*sin(th)) * dt_fino;
         x(2) + (x(3)*sin(th) + x(4)*cos(th)) * dt_fino;
         x(3) + (ax_fino(k)-x(6)) * dt_fino;
         x(4) + (ay_fino(k)-x(7)) * dt_fino;
         x(5) + (wz_fino(k)-x(8)) * dt_fino;
         x(6); x(7); x(8)]; 
    
    % Jacobiano F (Linealización en el punto actual)
    F = eye(8);
    F(1,3) = cos(th)*dt_fino; F(1,4) = -sin(th)*dt_fino; F(1,5) = (-x(3)*sin(th) - x(4)*cos(th))*dt_fino;
    F(2,3) = sin(th)*dt_fino; F(2,4) = cos(th)*dt_fino;  F(2,5) = (x(3)*cos(th) - x(4)*sin(th))*dt_fino;
    F(3,6) = -dt_fino; F(4,7) = -dt_fino; F(5,8) = -dt_fino;
    
    x = f;
    P = F * P * F' + Q2; % Propagación de incertidumbre
    
    % B) CORRECCIÓN (GNSS)
    if mod(k, factor_interp) == 0
        idx_gps = round(k / factor_interp);
        if idx_gps > 0 && idx_gps <= length(posi_este)
            z = [posi_este(idx_gps); posi_norte(idx_gps); v_x(idx_gps); v_y(idx_gps)];
            H = [eye(4), zeros(4,4)];
            
            S = H * P * H' + R;
            K = P * H' / S;
            
            x = x + K * (z - H * x);
            I_KH = eye(8) - K * H;
            P = I_KH * P * I_KH' + K * R * K'; % Forma de Joseph
        end
    end
    res_x2(:,k) = x(1:2);
end

% 4. CÁLCULO Y REPRESENTACIÓN DEL ERROR
GT_este = interp1(t, posi_este, t_fino, 'linear');
GT_norte = interp1(t, posi_norte, t_fino, 'linear');
err_final = sqrt((res_x2(1,:)-GT_este).^2 + (res_x2(2,:)-GT_norte).^2);


%% =========================================================================
%  11. DEGRADACIÓN GNSS CON EKF COMPLETO (DATOS A 10 Hz)
% =========================================================================
clc; %clearvars -except t a_x a_y yaw_int posi_este posi_norte v_x v_y yaw_acumulado1 dt;

% --- 1. ESTRANGULADOR DEL SATÉLITE ---
% Opciones válidas (divisores enteros de 10): 
% 10 (Síncrono), 5, 2, o 1 (Ceguera máxima)
frecuencia_gnss = 1; % <--- PRUEBA A CAMBIAR ESTE VALOR
% -------------------------------------
pasos_espera_gps = 10 / frecuencia_gnss;

fprintf('Aplicando EKF Degradado a %d Hz...\n', frecuencia_gnss);

numArchivos = length(t);

% 1. INICIALIZACIÓN DEL EKF
x_est = [posi_este(1); posi_norte(1); v_x(1); v_y(1); yaw_acumulado1(1)]; 
P = diag([0.1, 0.1, 0.1, 0.1, deg2rad(1)]); 

q_pos = 0.05; q_vel = 0.1; q_yaw = deg2rad(1);
Q = diag([q_pos, q_pos, q_vel, q_vel, q_yaw]);

r_gps_pos = 5;  
r_gps_vel = 1;  
R = diag([r_gps_pos, r_gps_pos, r_gps_vel, r_gps_vel]);

H = [1 0 0 0 0;
     0 1 0 0 0;
     0 0 1 0 0;
     0 0 0 1 0];
I = eye(5); 

ekf_pos_este  = zeros(1, numArchivos);
ekf_pos_norte = zeros(1, numArchivos);
ekf_yaw       = zeros(1, numArchivos);

ekf_pos_este(1)  = x_est(1);
ekf_pos_norte(1) = x_est(2);
ekf_yaw(1)       = x_est(5);

% 2. BUCLE PRINCIPAL DEL EKF (A 10 Hz)
for k = 2:numArchivos
    
    % --- DATOS DE ENTRADA EN EL INSTANTE k ---
    ax = a_x(k); 
    ay = a_y(k); 
    wz = yaw_int(k); 
    
    vx_prev = x_est(3);
    vy_prev = x_est(4);
    th_prev = x_est(5);
    
    % --- FASE 1: PREDICCIÓN (INS - ¡ESTO OCURRE SIEMPRE!) ---
    x_pred = zeros(5,1);
    x_pred(1) = x_est(1) + (vx_prev * cos(th_prev) - vy_prev * sin(th_prev)) * dt;
    x_pred(2) = x_est(2) + (vx_prev * sin(th_prev) + vy_prev * cos(th_prev)) * dt;
    x_pred(3) = vx_prev + ax * dt;
    x_pred(4) = vy_prev + ay * dt;
    x_pred(5) = th_prev + wz * dt;
    
    F = [1, 0,  cos(th_prev)*dt, -sin(th_prev)*dt, (-vx_prev*sin(th_prev) - vy_prev*cos(th_prev))*dt;
         0, 1,  sin(th_prev)*dt,  cos(th_prev)*dt, ( vx_prev*cos(th_prev) - vy_prev*sin(th_prev))*dt;
         0, 0,                1,                0,                                                 0;
         0, 0,                0,                1,                                                 0;
         0, 0,                0,                0,                                                 1];
     
    P_pred = F * P * F' + Q; % La incertidumbre inercial crece
    
    % --- FASE 2: CORRECCIÓN (GNSS - ¡CONDICIONADA A LA FRECUENCIA!) ---
    if mod(k, pasos_espera_gps) == 0
        % ¡El satélite entra! Leemos coordenada y corregimos
        z = [posi_este(k); posi_norte(k); v_x(k); v_y(k)];
        
        y_innov = z - (H * x_pred);
        S = H * P_pred * H' + R;
        K = P_pred * H' / S;
        
        x_est = x_pred + K * y_innov;
        P = (I - K*H) * P_pred * (I - K*H)' + K * R * K'; 
    else
        % ¡Ceguera GNSS! Nos quedamos solo con la estimación de la IMU
        x_est = x_pred;
        P = P_pred;
    end
    
    % --- GUARDADO DE DATOS ---
    ekf_pos_este(k)  = x_est(1);
    ekf_pos_norte(k) = x_est(2);
    ekf_yaw(k)       = x_est(5);
end

% 3. REPRESENTACIÓN GRÁFICA DEL ERROR
err_pos = sqrt((ekf_pos_este(:) - posi_este(:)).^2 + (ekf_pos_norte(:) - posi_norte(:)).^2);

figure(16); hold on;
plot(t(:), err_pos, 'LineWidth', 1.5, 'DisplayName', sprintf('EKF Original - GNSS a %d Hz', frecuencia_gnss));

title('Evolución del Error EKF ante Degradación del GNSS');
xlabel('Tiempo (s)', 'FontWeight', 'bold'); 
ylabel('Error absoluto de posición (m)', 'FontWeight', 'bold');
legend('Location', 'best'); grid on; set(gca, 'GridLineStyle', ':');

%% =========================================================================
% 12. ERRORES EKF SÍNCRONO (10 Hz) vs EKF ASÍNCRONO (1 Hz)
% =========================================================================

figure(17); clf;

% 1. Ploteamos el caso síncrono (Línea verde gruesa)
% Sustituye TU_VARIABLE_ERROR_SINCRONO por tu variable real
plot(t, error_ekf, 'g-', 'LineWidth', 2); hold on;

% 2. Ploteamos el caso asíncrono (Línea discontinua azul del bucle multirate)
% Usamos t_fino y el err2 que generamos en el bloque anterior
plot(t_fino, err_final, 'b--', 'LineWidth', 1.5);

% Formato académico para la memoria del TFG
title('Impacto de la Tasa de Actualización GNSS: 10 Hz vs 1 Hz', 'FontSize', 12);
xlabel('Tiempo (s)', 'FontSize', 11, 'FontWeight', 'bold'); 
ylabel('Error absoluto de posición (m)', 'FontSize', 11, 'FontWeight', 'bold');

% Leyenda
legend('EKF Síncrono (Corrección continua a 10 Hz)', ...
       'EKF Asíncrono (Corrección multirasa a 1 Hz)', 'Location', 'best');

grid on;
ax = gca;
ax.GridLineStyle = ':'; 
ax.GridAlpha = 0.7;





% =========================================================================
% 13. REPRESENTACIÓN ESPACIAL DE LAS TRAYECTORIAS ASÍNCRONA
% =========================================================================

figure(18); clf; hold on;

% 1. Dibujamos la ruta real del dataset (Ground Truth) en negro sólido
plot(posi_este, posi_norte, 'k-', 'LineWidth', 2, 'DisplayName', 'Ruta Real (GNSS Original)');

% 2. Dibujamos la ruta estimada por tu Filtro Degradado en rojo discontinuo
plot(ekf_pos_este, ekf_pos_norte, 'r--', 'LineWidth', 1.5, ...
    'DisplayName', sprintf('Estimación EKF (GNSS a %d Hz)', frecuencia_gnss));

% 3. Marcamos el punto de inicio (verde) para saber el sentido de la marcha
plot(posi_este(1), posi_norte(1), 'go', 'MarkerSize', 8, 'MarkerFaceColor', 'g', 'DisplayName', 'Inicio');

% 4. Marcamos el punto final de la ruta real y de la estimada para ver la separación exacta
plot(posi_este(end), posi_norte(end), 'ko', 'MarkerSize', 6, 'MarkerFaceColor', 'k', 'HandleVisibility', 'off');
plot(ekf_pos_este(end), ekf_pos_norte(end), 'ro', 'MarkerSize', 6, 'MarkerFaceColor', 'r', 'HandleVisibility', 'off');

% Dibujamos una línea sutil que une el final real con el final estimado (el error final)
plot([posi_este(end), ekf_pos_este(end)], [posi_norte(end), ekf_pos_norte(end)], 'b:', 'LineWidth', 1.5, 'HandleVisibility', 'off');

title(sprintf('Comparativa de Trayectorias - Degradación GNSS a %d Hz', frecuencia_gnss));
xlabel('Coordenada Este (m)', 'FontWeight', 'bold');
ylabel('Coordenada Norte (m)', 'FontWeight', 'bold');
legend('Location', 'best');
grid on;
set(gca, 'GridLineStyle', ':');

% CRÍTICO: Misma escala en ambos ejes para no deformar la realidad física
axis equal;

