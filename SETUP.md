# Setup Guide

Este documento describe los pasos necesarios para configurar el entorno de desarrollo de DiveClub. Incluye los pasos para levantar los contenedores y realizar configuraciones adicionales.

## Requisitos

- **Docker**: Necesitarás tener Docker y Docker Compose instalados.
- **Editor de código**: Usamos Visual Studio Code para este proyecto.
- **PostgreSQL**: Ya está preconfigurado para ser ejecutado en contenedores.

## Paso 1: Instalar Docker

Si no tienes Docker instalado, ve a [la página oficial de Docker](https://www.docker.com/get-started) y sigue las instrucciones de instalación para tu sistema operativo.

**Verifica que Docker esté funcionando:**

```bash
docker --version
docker-compose --version


## Paso 2: IClona el repositorio en tu maquina local
git clone https://github.com/tu_usuario/diveclub.git
cd diveclub



## Paso 3: Configurar tus variables de entorno
# PostgreSQL Configuration
DB_NAME=dive_app
DB_USER=indira_sierra
DB_PASSWORD=Cadillac171217
DB_PORT=5432

# PgAdmin Configuration (opcional)
PGADMIN_EMAIL=admin@diveclub.com
PGADMIN_PASSWORD=admin123

# App Configuration
JWT_SECRET=tu_jwt_secreto_ultra_seguro
NODE_ENV=development

# Backup Configuration (opcional)
BACKUP_PATH=/var/lib/postgresql/backups
 
## Paso 5: Verificar la ejecución:

#Verifica que los contenedores están corriendo:
docker compose ps

#Accede a la base de datos:
psql -h localhost -p 5433 -U indira_sierra -d dive_app


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

