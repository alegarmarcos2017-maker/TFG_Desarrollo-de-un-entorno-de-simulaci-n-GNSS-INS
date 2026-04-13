%% Anuncio importante acerca de github
%Cuando nosotros abrimos el documento dentro del repositorio se abrirá un
%nuevo archivo igual, el cuál si es que modificas se modifica github.


%% Vamos a obtener una trayectoria con datos reales 
%A partir de los datos reales de datasets públicos proporcionados por KITTI

%Primero obtendremos los puntos obtenidos del sensor GPS y pintaremos la
%trayectoria seguida

%Luego obtendremos los datos de actitud mediante los sensores inerciales
%aparte

%% En esta primera parte obtenemos los datos GPS y representamos

% 1. Definimos la carpeta de trabajo
carpeta = 'D:\Universidad\4º_Año_de_verdad\TFG\Datasets con datos reales (coche)\Caso 2\2011_09_26\2011_09_26_drive_0036_sync\oxts\data';

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
 
% % 3. Pon un mapa de fondo (puedes usar 'streets', 'satellite', 'topographic')
geobasemap 'satellite'

%Ya aparecen reflejados los datos en el mapa

%% Obtenemos datos de actitud y representamos
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
ylabel('Orientación (rad)'); xlabel('Tiempo_archivos');
legend('Yaw','roll','pitch');

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
ylabel('Orientación (rad)'); xlabel('Tiempo_archivos');
legend('Pitch','roll','Yaw');

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
ylabel('Orientación (rad)'); xlabel('Tiempo_archivos');
legend('Pitch','roll','Yaw');

%Ya son prácticamente idénticas, vamos a representarlas juntas en una misma
%grápica

% Representar las curvas de orientación acumulada juntas
figure(5)
plot(t, yaw_acumulado, 'r', t, yaw_acumulado1, 'g', t, yaw_continuo,'b');
ylabel('Orientación (rad)');
xlabel('Tiempo_archivos');
legend('Con integración Sin alineamiento', 'Con integración y con alineamiento', 'Datos proporcionados por la IMU' );
title('Comparación de Orientaciones Acumuladas');
grid on;

%Con la gráfica se comprueba que el error anterior era debido a la falta
%de alineación. Además las curvas integrada y la ya dada por el sensor
%prácticamente se solapan, aunque luego se observa un error que se va
%notando con el tiempo

