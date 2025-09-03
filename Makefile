.PHONY: build run rebuild up down restart rm-volumes clean-up

##### service #####
build:
	./build-push.sh build local

run:
	./build-push.sh run local

rebuild: build run

static-build:
	cd frontend && npm i && npm run build

run-bc:
	 ./backend/.venv/bin/uvicorn --app-dir ./backend  spread_auth.main:app --timeout-keep-alive 300 --port 5000 --reload

run-fr:
	cd ./frontend && npm run serve

run-all:
	$(MAKE) run-bc &
	$(MAKE) run-fr

###### store ######

up:
	docker run --rm  \
		--name store-starter \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v "awada_composes:/opt/awada" \
		--entrypoint /bin/bash \
		"alpha.awada.systems/spread-store:1.0.3.32" \
		-c "/entrypoint/update.sh alpha.awada.systems"

down:
	docker ps -a --filter 'label=com.docker.compose.project=awada' --format {{.ID}} | \
	xargs -n 1 docker rm --force && sleep 1 || true

restart: down up

rm-volumes:
	docker volume rm awada_composes awada_sockets awada_snippets || true

clean-up: down rm-volumes up

