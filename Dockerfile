ARG PYTHON_VERSION=3.11
ARG NODE_VERSION=22.11.0
ARG DEV_REGISTRY=alpha.awada.systems
ARG TARGET=dev

#############################
# frontend builder с установленными зависимостями проекта
#############################
FROM --platform=${BUILDPLATFORM} ${DEV_REGISTRY}/node:${NODE_VERSION} AS static-builder
#############################

WORKDIR /frontend/

COPY ./frontend/package*.json .

RUN --mount=type=cache,target=/tmp/npm-cache \
    npm set cache /tmp/npm-cache; \
    npm ci


#############################
# frontend builder с готовой статикой
#############################
FROM static-builder AS static
#############################

COPY ./frontend/ /frontend/

RUN npm run build


#############################
# python с установленными зависимостями проекта
#############################
FROM ${DEV_REGISTRY}/python-dev:${PYTHON_VERSION} AS python-dependecies
#############################

RUN apt-get update
RUN apt-get install libbluetooth3

WORKDIR /application/

COPY ./backend/pyproject.toml /application/
RUN poetry install --no-root --without dev
COPY ./backend/ /application/
#RUN rm -rf /application/.venv

#############################
FROM python-dependecies AS settings
#############################

ARG TARGET

COPY --chmod=700 ./entrypoint.sh /entrypoint.sh
COPY --from=static /frontend/dist /static
COPY backend/config/${TARGET}.json /config/default.json
COPY location.snippet upstream.snippet /snippets/

#RUN mkdir /config
RUN --mount=type=bind,source=generate_schema.py,target=/application/generate_schema.py \
    /application/.venv/bin/python3 ./generate_schema.py

#############################
FROM settings AS dev-builder
#############################

WORKDIR /application/

RUN poetry install

#############################
FROM dev-builder AS dev
#############################

WORKDIR /application

ENTRYPOINT [ "/entrypoint.sh" ]

#############################
FROM settings AS prod-builder
#############################

WORKDIR /application/

RUN poetry install

#############################
FROM ${DEV_REGISTRY}/python-production:${PYTHON_VERSION} AS production
#############################

WORKDIR /application


COPY --chmod=700 ./entrypoint.sh /entrypoint.sh
COPY --from=settings /config/ /config/
COPY --from=static /frontend/dist /static
COPY --from=prod-builder /application /application
COPY --from=prod-builder /config/schema.json /config/schema.json
COPY backend/config/production.json /config/default.json
COPY location.snippet upstream.snippet /snippets/

ENTRYPOINT [ "/entrypoint.sh" ]