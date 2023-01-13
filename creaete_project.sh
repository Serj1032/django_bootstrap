#!/bin/bash
# Shell script for create a simple Django project.

# wget --output-document=setup.sh https://goo.gl/pm621U

set -e 

################################################################################
#                                   Colors
################################################################################

red=`tput setaf 1`
green=`tput setaf 2`
reset=`tput sgr0`

function print_green() {
  echo "${green}$1${reset}"
}

function print_red() {
  echo "${red}$1${reset}"
}

function print() {
  echo "$1"
}


################################################################################
#                                    Prepare Docker
################################################################################


function prepare_docker() { 
  print_green ">>> Prepare docker containers..."

  cp $SCRIPT_DIR/backend/Dockerfile           $BACKEND_CONTAINER_DIR
  cp $SCRIPT_DIR/frontend/Dockerfile          $FRONTEND_CONTAINER_DIR
  cp $SCRIPT_DIR/.env                         $PROJECT_DIR
  cp -r $SCRIPT_DIR/secrets                   $PROJECT_DIR
  cp $SCRIPT_DIR/docker-compose.yml           $PROJECT_DIR
  sed -i "s/django_net/${PROJECT}_net/" $PROJECT_DIR/docker-compose.yml
}


################################################################################
#                       Prepare Django project
################################################################################

function init_environment() {
  print_green ">>> Init environment: $PROJECT"

  cd $PROJECT_DIR

  print_green ">>> Creating virtualenv"
  virtualenv -p python3 .venv
  print_green ">>> .venv is created"

  # active
  sleep 2
  print_green ">>> activate the .venv"
  source .venv/bin/activate
  PS1="(`basename \"$VIRTUAL_ENV\"`)\e[1;34m:/\W\033[00m$ "
  sleep 2

  # installdjango
  print_green ">>> Installing the Django"
  pip install Django
  pip freeze > $BACKEND_CONTAINER_DIR/requirements.txt
}


################################################################################
#                       Create Django project
################################################################################

function create_django_project() {
  print_green ">>> Creating the project backend .."
  cd $BACKEND_WEB_DIR
  django-admin startproject backend .

  print_green ">>> Creating the app: $APP"
  python manage.py startapp $APP $BACKEND_APP_DIR

  print_green ">>> Creating forms.py"
  touch $BACKEND_APP_DIR/forms.py

  print_green ">>> Creating template directory"
  mkdir $BACKEND_APP_DIR/templates

  # up one level
  cd $BACKEND_WEB_DIR

  # migrate
  # it is required if this script will make any data models
  if [ "$MIGRATE" = true ]
  then
    print_red "Make migrations..."
    python manage.py makemigrations
    python manage.py migrate
  fi

  # createuser
  # print_green ">>> Creating a 'admin' user .."
  # print_green ">>> The password must contain at least 8 characters"
  # print_green ">>> Password suggestions: djangoadmin"
  # python manage.py createsuperuser --username='admin' --email=''
}

################################################################################
#                                    CLEANUP
################################################################################

function cleanup() {
  rm -rf $PROJECT_DIR/.venv
  if [ "$POSTGRES" = true ]
  then
    rm -rf $PROJECT_DIR/db.sqlite3
  fi
}


################################################################################
#                       Editing settings for database
################################################################################

function use_postgresql() {
  print_green ">>> Editing settings.py to use postgresql"
  echo "Editing settings.py: DATABASES"
  sed -i "s/'ENGINE':.*/'ENGINE': 'django.db.backends.postgresql',/"                $BACKEND_PROJECT_DIR/settings.py
  sed -i "s/'NAME': BASE_DIR \/ 'db.sqlite3',/'NAME': '$POSTGRES_NAME',/"           $BACKEND_PROJECT_DIR/settings.py
  sed -i "/'NAME': 'postgres',/a\        'USER': '$POSTGRES_USER',"                 $BACKEND_PROJECT_DIR/settings.py
  sed -i "/'USER': '$POSTGRES_USER',/a\        'PASSWORD': '$POSTGRES_PASSWORD',"   $BACKEND_PROJECT_DIR/settings.py
  sed -i "/'PASSWORD': '$POSTGRES_PASSWORD',/a\        'HOST': 'db',"               $BACKEND_PROJECT_DIR/settings.py
  sed -i "/'HOST': 'db',/a\        'PORT': '5432',"                                 $BACKEND_PROJECT_DIR/settings.py
}



################################################################################
#                            Setup app in backend
################################################################################

function setup_backend() {
  print_green ">>> Editing project to use created app..."
  cd $PROJECT_DIR

  echo "Editing $APP/apps.py"
  sed -i "s/name = '$APP'/name = 'backend.$APP'/" $BACKEND_APP_DIR/apps.py

  echo "Editing settings.py: INSTALLED_APPS"
  sed -i "/INSTALLED_APPS/a\    'rest_framework_simplejwt.token_blacklist',"  $BACKEND_PROJECT_DIR/settings.py
  sed -i "/INSTALLED_APPS/a\    'rest_framework',"  $BACKEND_PROJECT_DIR/settings.py
  sed -i "/INSTALLED_APPS/a\    'corsheaders',"     $BACKEND_PROJECT_DIR/settings.py
  sed -i "/INSTALLED_APPS/a\    'backend.$APP',"    $BACKEND_PROJECT_DIR/settings.py
    
  echo "Editing settings.py: MIDDLEWARE"
  sed -i "/MIDDLEWARE/a\    'corsheaders.middleware.CorsMiddleware',"      $BACKEND_PROJECT_DIR/settings.py
  sed -i "/MIDDLEWARE/a\    'django.middleware.common.CommonMiddleware',"  $BACKEND_PROJECT_DIR/settings.py

  echo "CORS_ORIGIN_ALLOW_ALL = True"                                >> $BACKEND_PROJECT_DIR/settings.py
  sed -i "s/ALLOWED_HOSTS.*$/ALLOWED_HOSTS = ['0.0.0.0', 'localhost', 'backend']/"    $BACKEND_PROJECT_DIR/settings.py
  cat << EOF >> $BACKEND_PROJECT_DIR/settings.py 

SIMPLE_JWT = {
  'ACCESS_TOKEN_LIFETIME': timedelta(hours=24),
  'REFRESH_TOKEN_LIFETIME': timedelta(weeks=1),
  'ROTATE_REFRESH_TOKENS': True,
  'BLACKLIST_AFTER_ROTATION': True,
}
EOF
  sed -i "14 i from datetime import timedelta"  $BACKEND_PROJECT_DIR/settings.py

  echo "Editing urls.py"
  sed -i "s/from django.urls import path/from django.urls import path, include/"      $BACKEND_PROJECT_DIR/urls.py
  sed -i "/urlpatterns = \[/a\    path('', include('backend.$APP.urls')),"           $BACKEND_PROJECT_DIR/urls.py

  echo "Copy $SCRIPT_DIR/backend/app/* -> $BACKEND_APP_DIR/"
  cp $SCRIPT_DIR/backend/app/*          $BACKEND_APP_DIR/
  cp $SCRIPT_DIR/backend/app/index.html $BACKEND_APP_DIR/templates/index.html
}

################################################################################
#                            Setup react app in frontened
################################################################################

function create_react_frontend() {
  print_green ">>> Install react frontened"
  cd $FRONTEND_APP_DIR
  npm install create-react-app
  npm create react-app .

  sed -i '$d' $FRONTEND_APP_DIR/package.json
  sed -i '$d' $FRONTEND_APP_DIR/package.json
  cat << EOF >> $FRONTEND_APP_DIR/package.json 
  },
  "proxy": "http://backend:8000"
}
EOF

  npm install bootstrap reactstrap axios --save

  mkdir -p $FRONTEND_APP_DIR/src/constants
  echo "export const API_URL = \"http://backend:8000/api/\"" > $FRONTEND_APP_DIR/src/constants/index.js
  sed -i "5 i import \"bootstrap/dist/css/bootstrap.min.css\";"  $FRONTEND_APP_DIR/src/index.js

  echo "Copy App.js"
  cp $SCRIPT_DIR/frontend/App.js $FRONTEND_APP_DIR/src/App.js
  cp $SCRIPT_DIR/frontend/App.css $FRONTEND_APP_DIR/src/App.css
}



################################################################################
#                                   Arguments
################################################################################

SCRIPT_DIR=$(dirname $(realpath "$0"))
TOP_DIR=$(dirname $SCRIPT_DIR)

unset APP PROJECT PROJECT_DIR MIGRATE
source $SCRIPT_DIR/.env

POSTGRES=false

POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    -p|--project)
      PROJECT="$2"
      shift # past argument
      shift # past value
      ;;
    -a|--app)
      APP="$2"
      shift # past argument
      shift # past value
      ;;
    # TODO: this flag needs when this script will be produced any data model, required migration of DB
    # -m|--migrate)  
    #   MIGRATE=true
    #   shift # past argument
    #   ;;
    --postgres)  
      POSTGRES=true
      shift # past argument
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift # past argument
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

if [ -z $APP ]
then
  print_red "Will be created default app name"
  APP=app
fi

################################################################################
#                       Prepare Django Structure
################################################################################


PROJECT_DIR=${TOP_DIR}/${PROJECT}_django

BACKEND_CONTAINER_DIR=$PROJECT_DIR/backend
BACKEND_WEB_DIR=$BACKEND_CONTAINER_DIR/web
BACKEND_PROJECT_DIR=$BACKEND_WEB_DIR/backend
BACKEND_APP_DIR=$BACKEND_PROJECT_DIR/$APP

FRONTEND_CONTAINER_DIR=$PROJECT_DIR/frontend
FRONTEND_WEB_DIR=$FRONTEND_CONTAINER_DIR/web
FRONTEND_APP_DIR=$FRONTEND_WEB_DIR/frontend


if [ -d $PROJECT_DIR ]
then
  print_green ">>> Remove old django project directory: ${PROJECT_DIR}"
  rm -rf $PROJECT_DIR
fi

mkdir -p $PROJECT_DIR
mkdir -p $BACKEND_CONTAINER_DIR
mkdir -p $BACKEND_WEB_DIR
mkdir -p $BACKEND_PROJECT_DIR
mkdir -p $BACKEND_APP_DIR

mkdir -p $FRONTEND_CONTAINER_DIR
mkdir -p $FRONTEND_WEB_DIR
mkdir -p $FRONTEND_APP_DIR

print_green "Directory structure:"
# echo "    Root project directory      = $PROJECT_DIR"
# echo "    Directory with dockerfile   = $BACKEND_CONTAINER_DIR"
# echo "    Backend source directory    = $BACKEND_PROJECT_DIR"
# echo "        Application directory   = $BACKEND_APP_DIR"
# echo "    Frontend source directory   = $FRONTEND_DIR"

tree  $PROJECT_DIR

prepare_docker
init_environment
create_django_project
setup_backend
# setup_frontend
create_react_frontend


if [ "$POSTGRES" = true ]
then
  use_postgresql
fi

cleanup

tree -I "node_modules|__pycache__" $PROJECT_DIR

sleep 2
print_green ">>> Done"
sleep 2

# React + Django
# https://tproger.ru/translations/django-react-webapp/
# https://blog.logrocket.com/using-react-django-create-app-tutorial/
# https://habr.com/ru/company/ruvds/blog/436886/
# https://habr.com/ru/company/piter/blog/651465/
# https://www.honeybadger.io/blog/docker-django-react/

# Django Auth
# https://habr.com/ru/post/512746/

# https://www.gnu.org/software/sed/manual/sed.html
# http://www.asciitable.com/
# http://linuxconfig.org/add-character-to-the-beginning-of-each-line-using-sed

# Docker Compose
# https://saasitive.com/tutorial/docker-compose-django-react-nginx-let-s-encrypt/