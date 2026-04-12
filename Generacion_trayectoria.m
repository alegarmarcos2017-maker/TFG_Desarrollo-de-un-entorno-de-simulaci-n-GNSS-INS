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

%% Obtención de trayectoria con datos inerciales
%En este apartado  me gustaría conseguir la trayectoria del coche mediante
%los datos proporcionados por la IMU y así poder compararlos con la
%trayectoria casi real del GPS. 

%A continuación haremos lo siguiente: 


