SHELL := /bin/bash
.DEFAULT_GOAL := help

DATA_DIR := data
HOST ?= 127.0.0.1
PORT ?= 8000
APP_URL := http://$(HOST):$(PORT)

.PHONY: help generate-data sidecar-start sidecar-stop server-start server-stop start stop restart status logs clean open

help:
	@echo "Targets:"
	@echo "  make generate-data   Generate the TPC-H DuckLake catalog + Parquet data"
	@echo "  make start           Start the Quack sidecar and static server, then open the browser"
	@echo "  make stop            Stop both background processes"
	@echo "  make restart         Stop then start both"
	@echo "  make status          Show whether the sidecar/server are running (with PIDs)"
	@echo "  make logs            Tail the sidecar and server logs"
	@echo "  make open            Open the dashboard in the default browser"
	@echo "  make sidecar-start   Start only the Quack sidecar"
	@echo "  make sidecar-stop    Stop only the Quack sidecar"
	@echo "  make server-start    Start only the static server"
	@echo "  make server-stop     Stop only the static server"
	@echo "  make clean           Stop everything and remove PID/log files"

generate-data:
	python3 generate_data.py

sidecar-start:
	./start_quack_sidecar.sh

sidecar-stop:
	./stop_quack_sidecar.sh

server-start:
	./start_server.sh

server-stop:
	./stop_server.sh

start: sidecar-start server-start open

open:
	@echo "Waiting for $(APP_URL) to respond..."; \
	for i in $$(seq 1 40); do \
		if curl -sf -o /dev/null "$(APP_URL)"; then break; fi; \
		sleep 0.25; \
	done; \
	if command -v open >/dev/null 2>&1; then open "$(APP_URL)"; \
	elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$(APP_URL)"; \
	else echo "Open manually: $(APP_URL)"; fi

stop: sidecar-stop server-stop

restart: stop start

status:
	@echo "Quack sidecar:"; \
	if [ -f "$(DATA_DIR)/quack_sidecar.pid" ] && kill -0 "$$(cat $(DATA_DIR)/quack_sidecar.pid)" 2>/dev/null; then \
		echo "  running (PID $$(cat $(DATA_DIR)/quack_sidecar.pid))"; \
	else \
		echo "  not running"; \
	fi; \
	echo "Static server:"; \
	if [ -f "$(DATA_DIR)/server.pid" ] && kill -0 "$$(cat $(DATA_DIR)/server.pid)" 2>/dev/null; then \
		echo "  running (PID $$(cat $(DATA_DIR)/server.pid))"; \
	else \
		echo "  not running"; \
	fi

logs:
	@echo "--- quack_sidecar.log ---"; tail -n 40 "$(DATA_DIR)/quack_sidecar.log" 2>/dev/null || echo "(no log yet)"; \
	echo "--- server.log ---"; tail -n 40 "$(DATA_DIR)/server.log" 2>/dev/null || echo "(no log yet)"

clean: stop
	rm -f "$(DATA_DIR)/quack_sidecar.pid" "$(DATA_DIR)/quack_sidecar.log" "$(DATA_DIR)/server.pid" "$(DATA_DIR)/server.log"
