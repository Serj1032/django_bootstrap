## Environment

Make you own `.env` file and edit all variables
```Bash
cp .env.template .env
```

## Docker containers

1. Build docker container with web app
    ```Bash
    docker-compose build
    ```
2. Run containers 
    ```Bash
    docker-compose up -d
    ```


## First run
After first running you should:
1. Make migration
    ```Bash
    python manage.py makemigrations
    python manage.py migrate
    ```
2. Create superuser  
    ```Bash
    # Creating a 'admin' user ..
    # The password must contain at least 8 characters
    python manage.py createsuperuser --username='admin' --email=''
    ```