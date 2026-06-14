# TFG: Desarrollo de un entorno de simulación GNSS-INS

Repositorio de trabajo para el TFG centrado en la generación, análisis y fusión de trayectorias GNSS/INS con MATLAB. El proyecto usa datos reales de vehículos terrestres y aéreos para estudiar la deriva de la navegación inercial pura y la mejora obtenida al fusionar medidas GNSS mediante filtros de Kalman.

## Objetivo

El objetivo principal es construir un entorno de simulación y validación para navegación integrada GNSS-INS:

- Lectura y preparación de datasets reales con sensores GNSS, IMU y ground truth.
- Representación de trayectorias GPS/GNSS y variables de actitud.
- Integración inercial para observar la deriva acumulada.
- Fusión sensorial GNSS-INS mediante EKF.
- Comparación entre INS pura, EKF síncrono y EKF asíncrono multi-rate.
- Generación de gráficas y métricas para documentar los resultados del TFG.

## Estado del proyecto

El repositorio está en desarrollo y contiene scripts exploratorios junto a una versión más completa del flujo GNSS-INS para el dataset del dron de Zúrich. Actualmente los datasets no están incluidos en el repositorio y las rutas se configuran dentro de cada script.

## Estructura del repositorio

| Archivo | Descripción |
| --- | --- |
| `Generacion_trayectoria.m` | Procesado de datos KITTI/OXTS de coche: lectura GPS, actitud, integración, comparación de trayectorias y primera fusión GNSS-INS con EKF. |
| `Dron_de_zurich.m` | Primer flujo con el dataset de dron de Zúrich. Carga CSV, alinea sensores y muestra la deriva de una navegación inercial pura. |
| `Dron_de_zurich3.m` | Prototipo de EKF 3D síncrono para el dataset de Zúrich, con diagnóstico temporal de las entradas GPS interpoladas. |
| `Dron_de_zurich5.m` | Script principal más avanzado: compara INS pura, EKF síncrono y EKF asíncrono multi-rate, aplica filtrado antialiasing y calcula RMSE. |
| `Kalman_1_dimension.m` | Borrador para pruebas iniciales de filtro de Kalman en una dimensión. |
| `Datasets.m` | Apuntes iniciales sobre datasets. |
| `untitled.m` | Archivo de práctica para simulaciones. |
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

`Dron_de_zurich5.m` genera un conjunto de figuras para comparar:

- Deriva de la INS pura frente al ground truth.
- EKF síncrono frente a EKF asíncrono.
- Trayectorias 3D en ejes Norte-Este-Abajo.
- Efecto del filtrado Butterworth sobre la señal GNSS interpolada.
- Detalle multi-rate de predicción INS, muestras GPS y estimación posterior del EKF.

También imprime métricas finales en la consola de MATLAB:

- RMSE del EKF síncrono.
- RMSE del EKF asíncrono.
- Deriva final de la INS pura.

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
- La estimación todavía no incluye un modelo completo de sesgos de acelerómetro y giroscopio.
- `Generacion_trayectoria.asv` es un archivo de autosalvado de MATLAB y podría eliminarse del control de versiones en una limpieza futura.

## Próximos pasos recomendados

- Mover las rutas de datasets a un archivo de configuración local no versionado.
- Separar carga de datos, preprocesado, filtrado y gráficas en funciones reutilizables.
- Añadir un README específico para cada dataset con su estructura exacta.
- Guardar automáticamente figuras y métricas en una carpeta `resultados/`.
- Ampliar el modelo de estado del EKF con sesgos de IMU y ajuste de covarianzas.
