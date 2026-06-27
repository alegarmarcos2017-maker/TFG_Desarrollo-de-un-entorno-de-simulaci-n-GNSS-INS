# TFG: Desarrollo de un entorno de simulación GNSS-INS

Repositorio de trabajo para el TFG centrado en la generación, análisis y fusión de trayectorias GNSS/INS con MATLAB. El proyecto usa datos reales de vehículos terrestres y aéreos para estudiar la deriva de la navegación inercial pura y la mejora obtenida al fusionar medidas GNSS mediante filtros de Kalman extendidos (EKF).

## Objetivo

El objetivo principal es construir un entorno de simulación y validación para navegación integrada GNSS-INS:

- Lectura y preparación de datasets reales con sensores GNSS, IMU, ground truth y datos barometricos (se irán utilizando a medida que avanza el desarrollo.
- Representación de trayectorias GPS/GNSS y variables de actitud.
- Integración inercial para observar la deriva acumulada, y error del sistema GPS.
- Fusión sensorial GNSS-INS mediante EKF.
- Comparación entre INS pura, EKF síncrono de 5 estados (Caso A), EKF asíncrono multi-rate de 8 estados (Caso B), EKF de 9 estados (Caso C), EKF de 15 estados (Caso D) y EKF de 9 estados con fusión del alímetro barométrico.
- Generación de gráficas y métricas para documentar los resultados del TFG.

## Estado del proyecto

El repositorio está terminado, pero al haber sido para un estudio con casos reales, contiene scripts exploratorios junto a dos versión más completas del flujo GNSS-INS para el dataset del coche y el dron de Zúrich. Actualmente los datasets no están incluidos en el repositorio y las rutas se configuran dentro de cada script.

## Estructura del repositorio

| Archivo | Descripción |
| --- | --- |
| `Generacion_trayectoria.m` | Procesado de datos KITTI/OXTS de coche y desarrollo de algoritmo completo: lectura GPS, actitud, integración, comparación de trayectorias síncronas y asíncronas y primera fusión GNSS-INS con EKF. |
| `Dron_de_zurich4.m` | Procesado de datos del dron de Zúrich y desarrollo del algortimo completo. Carga CSV, alinea sensores, muestra la deriva de la navegación inercial pura, evalúa caso de 9, 15 estados, además de fusionar datos del barómetro |
| `Dron_de_zurich.m` | Primer flujo con el dataset de dron de Zúrich. Carga CSV, alinea sensores y muestra la deriva de una navegación inercial pura. |
| `Dron_de_zurich3.m` | Borrador |
| `Dron_de_zurich5.m` | Borrador |
| `Kalman_1_dimension.m` | Borrador |
| `Datasets.m` | Borrados |
| `untitled.m` |Borrador |
| `Generacion_trayectoria.asv` | Copia automática generada por MATLAB. No es necesaria para ejecutar el proyecto. |

## Datasets esperados

Los scripts trabajan con datasets externos guardados fuera del repositorio:

### KITTI / OXTS

Usado por `Generacion_trayectoria.m`.

Ruta esperada en el script:

```matlab
unidad_disco = 'D:';
ruta_interna = '\Universidad\4º_Año_de_verdad\TFG\Datasets con datos reales (coche)\Caso 2\2011_09_26\2011_09_26_drive_0036_sync\oxts\data';
```

La carpeta debe contener los ficheros `.txt` de OXTS del trayecto.

### Dataset de dron de Zúrich

Usado por `Dron_de_zurich.m`, `Dron_de_zurich3.m` y `Dron_de_zurich5.m`.

Ruta esperada en los scripts:

```matlab
carpetaData = 'D:\Universidad\4º_Año_de_verdad\TFG\Dataset con datos reales (dron Zúrich)\AGZ\AGZ\Log Files';
```

La carpeta `Log Files` debe contener, al menos:

- `OnboardGPS.csv`
- `RawAccel.csv`
- `RawGyro.csv`
- `GroundTruthAGL.csv`

## Requisitos

- MATLAB.
- Acceso local a los datasets anteriores.
- Funciones habituales de MATLAB como `readtable`, `readmatrix`, `interp1`, `filter`, `plot`, `plot3` y `animatedline`.
- Para las partes con mapas (`geoplot`, `geobasemap`) se necesita una versión de MATLAB que incluya esas funciones.

## Uso rápido

1. Clona o abre este repositorio en MATLAB.
2. Descarga los datasets necesarios y colócalos en una carpeta local o en un disco externo.
3. Ajusta las rutas `unidad_disco`, `ruta_interna` o `carpetaData` al principio del script que vayas a ejecutar.
4. Ejecuta el flujo principal del dron:

```matlab
run("Dron_de_zurich5.m")
```

Para el flujo de coche con KITTI:

```matlab
run("Generacion_trayectoria.m")
```

## Resultados que genera

`Dron_de_zurich4.m` genera un conjunto de figuras para comparar:


- Trayectorias 3D en ejes Norte-Este-Abajo, del GPS y la trayectoria de referencia Ground Truth.
- Representación de la actitud, roll, pith y yaw.
- Error del GPS y su RMSE.
- Estimación del EKF de 8 estados e impacto de modificar matrices Q y R y su RMSE.
- Estimación del EKF de 15 estados con bias.
- Impacto del filtro con integración del sensor barométrico

También imprime métricas finales en la consola de MATLAB:

- RMSE del EKF .
- Deriva final de la INS pura.
- RMSE GPS Crudo          
- RMSE EKF 9 Estados  
- RMSE EKF 15 Estados     
- Mejora absoluta del 15E 


`Generacion_trayectoria.m` genera un conjunto de figuras para comparar:

- Estado de la actitud y consecuencias de no alineamiento inicial
- Comparación de trayectorias mediante integración de la aceleración, mediante odometría en comparación a la de referencia, y sus errores. Efecto del filtrado Butterworth sobre la señal GNSS interpolada.
- EKF síncrono frente a EKF asíncrono y con degradación de GPS
- Error de posición con y sin cálculo del bias
  

## Notas de implementación

- El estado del EKF se modela como:

```text
[pN, pE, pD, vN, vE, vD, phi, theta, psi]
```

- El sistema de navegación usado en los scripts del dron es local NED: Norte, Este, Abajo.
- La transformación GNSS a coordenadas locales se realiza mediante una aproximación `Flat Earth`.
- La actitud se propaga con ángulos de Euler, suficiente para las pruebas del TFG, aunque una versión más robusta podría usar cuaterniones.
- El EKF asíncrono corrige solo cuando hay una muestra GNSS cercana al instante de la IMU.

## Limitaciones conocidas

- Las rutas a datasets están codificadas dentro de los scripts y deben adaptarse a cada PC.
- Los datasets no se versionan en Git por tamaño y por tratarse de datos externos.
- Varios archivos son prototipos o apuntes de desarrollo, no módulos cerrados.
- `Generacion_trayectoria.asv` es un archivo de autosalvado de MATLAB y podría eliminarse del control de versiones en una limpieza futura.

## Próximos pasos recomendados

- Mover las rutas de datasets a un archivo de configuración local no versionado.
- Separar carga de datos, preprocesado, filtrado y gráficas en funciones reutilizables.
- Añadir un README específico para cada dataset con su estructura exacta.
- Guardar automáticamente figuras y métricas en una carpeta `resultados/`.
- Ampliar el modelo de estado del EKF con sesgos de IMU y ajuste de covarianzas.
