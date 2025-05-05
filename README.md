
# DiveClub Project

## Descripción

DiveClub es una aplicación web para gestión de clubes de buceo, diseñada utilizando Node.js y PostgreSQL. Esta aplicación está dockerizada para facilitar el desarrollo y despliegue.

## Tecnologías

- Node.js
- PostgreSQL
- Docker
- PgAdmin (opcional)

## Requisitos

Antes de ejecutar el proyecto, asegúrate de tener:

- Docker y Docker Compose instalados en tu máquina.
- Un editor de código como Visual Studio Code.
- Node.js y npm (si deseas trabajar fuera de los contenedores).

## Instalación

### Clonando el proyecto

```bash
git clone https://github.com/tu_usuario/diveclub.git
cd diveclub

###Construir y ejecutar los contenedores:
docker compose up --build -d


### Acceder a la base de datos:
psql -h localhost -p 5433 -U indira_sierra -d dive_app


###Acceder a la aplicación:
http://localhost:5000

Comandos útiles
Parar contenedores:
docker compose down

Levantarlos:
docker compose build
docker compose up -d

Ver logs de la app:
docker compose logs -f app


Ver logs de PostgreSQL:
docker compose logs -f postgres



