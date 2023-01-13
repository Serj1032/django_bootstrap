FROM python:3.9-buster

ENV TZ=Europe/Moscow
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

RUN python -m pip install psycopg2 django djangorestframework django-cors-headers
RUN python -m pip install djangorestframework-simplejwt

# ARG UNAME=user
# ARG UID=1000
# ARG GID=1000

# RUN groupadd -g $GID -o $UNAME
# RUN useradd -m -u $UID -g $GID -o -s /bin/bash $UNAME
# RUN usermod -a -G dialout $UNAME
# # RUN echo $UNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$UNAME \
# #         && chmod 0440 /etc/sudoers.d/$UNAME
# USER $UNAME

COPY requirements.txt /requirements.txt

RUN pip install -r /requirements.txt
