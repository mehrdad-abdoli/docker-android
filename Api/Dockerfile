FROM python:3.6-alpine
WORKDIR /project
ADD ./requirements.txt /project
ENV TZ="Asia/Tehran"
RUN apk update && \
    apk add --no-cache --virtual build-dependencies \
    build-base gcc wget git openssl libressl \
    libressl-dev musl-dev libffi libffi-dev \
    libxml2-dev libxslt-dev jpeg-dev zlib-dev \
    linux-headers tzdata
RUN rm -rf /var/cache/apk/*
RUN pip install -r /project/requirements.txt
RUN ln -fs /usr/share/zoneinfo/Asia/Tehran /etc/localtime
