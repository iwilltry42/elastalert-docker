######################################
# Stage 1: Prepare Elastalert module #
######################################

FROM alpine:3.9 as py-ea

# Build Elastalert download URL
ARG ELASTALERT_REPO=https://github.com/iwilltry42/elastalert
ENV ELASTALERT_REPO=${ELASTALERT_REPO}
ARG ELASTALERT_VERSION=master
ENV ELASTALERT_VERSION=${ELASTALERT_VERSION}
ARG ELASTALERT_URL=${ELASTALERT_REPO}/archive/${ELASTALERT_VERSION}.zip
ENV ELASTALERT_URL=${ELASTALERT_URL}

# Elastalert home directory full path.
ENV ELASTALERT_HOME=/opt/elastalert

WORKDIR /opt

# Download and unpack Elastalert
RUN apk add --update --no-cache ca-certificates openssl-dev openssl python3-dev=3.6.8-r2 python3=3.6.8-r2 libffi-dev gcc musl-dev wget && \
    wget -O elastalert.zip "${ELASTALERT_URL}" && \
    unzip elastalert.zip && \
    rm elastalert.zip && \
    mv e* "${ELASTALERT_HOME}" && \
    python3 -m ensurepip && \
    pip3 install --upgrade pip && \
    pip3 install pyyaml

WORKDIR "${ELASTALERT_HOME}"

# Install Elastalert
RUN python3 setup.py install && \
    pip3 install -r requirements.txt


###########################################################
# Stage 2: Build container including bitsensor's REST API #
###########################################################

FROM node:alpine
LABEL maintainer="BitSensor <dev@bitsensor.io>"

# Set timezone for this container
ENV TZ Etc/UTC

RUN apk add --update --no-cache curl tzdata python2 python3=3.6.8-r2 make libmagic && \
    ln -sf python3 /usr/bin/python

COPY --from=py-ea /usr/lib/python3.6/site-packages /usr/lib/python3.6/site-packages
COPY --from=py-ea /opt/elastalert /opt/elastalert
COPY --from=py-ea /usr/bin/elastalert* /usr/bin/

WORKDIR /opt/elastalert-server
COPY . /opt/elastalert-server

RUN npm install --production --quiet
COPY config/elastalert.yaml /opt/elastalert/config.yaml
COPY config/elastalert-test.yaml /opt/elastalert/config-test.yaml
COPY config/config.json config/config.json
COPY rule_templates/ /opt/elastalert/rule_templates
COPY elastalert_modules/ /opt/elastalert/elastalert_modules

# Add default rules directory
# Set permission as unpriviledged user (1000:1000), compatible with Kubernetes
RUN mkdir -p /opt/elastalert/rules/ /opt/elastalert/server_data/tests/ \
    && chown -R node:node /opt

USER node

EXPOSE 3030
ENTRYPOINT ["npm", "start"]
