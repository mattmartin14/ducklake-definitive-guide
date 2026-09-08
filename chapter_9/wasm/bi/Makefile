SHELL := /bin/bash
.DEFAULT_GOAL := help

DATA_DIR := data
HOST ?= 127.0.0.1
PORT ?= 8000
APP_URL := http://$(HOST):$(PORT)

.PHONY: help deploy destroy generate-data seed-data tunnel-start tunnel-stop server-start server-stop start stop restart status logs open clean

help:
	@echo "Targets:"
	@echo "  make deploy          Terraform apply the EC2 Quack/DuckLake backend"
	@echo "  make destroy         Terraform destroy the EC2 backend (bucket untouched)"
	@echo "  make generate-data   Generate sample_data/ CSVs + seed insert SQL"
	@echo "  make seed-data       Pre-populate dl1.sales_data (needs tunnel-start first)"
	@echo "  make start           Start SSH tunnel + static server, then open the browser"
	@echo "  make stop            Stop both background processes"
	@echo "  make status          Show whether the tunnel/server are running (with PIDs)"
	@echo "  make logs            Tail the tunnel and server logs"
	@echo "  make tunnel-start    Start only the SSH tunnel to EC2"
	@echo "  make tunnel-stop     Stop only the SSH tunnel"
	@echo "  make server-start    Start only the static server"
	@echo "  make server-stop     Stop only the static server"
	@echo "  make clean           Stop everything and remove PID/log files"

deploy:
	./scripts/deploy.sh

destroy:
	./scripts/destroy.sh

generate-data:
	python3 scripts/generate_sales_data.py

seed-data:
	./scripts/seed_sales_data.sh

tunnel-start:
	./scripts/start_ssh_tunnel.sh

tunnel-stop:
	./scripts/stop_ssh_tunnel.sh

server-start:
	./scripts/start_server.sh

server-stop:
	./scripts/stop_server.sh

start: tunnel-start server-start open

open:
	@echo "Waiting for $(APP_URL) to respond..."; \
	for i in $$(seq 1 40); do \
		if curl -sf -o /dev/null "$(APP_URL)"; then break; fi; \
		sleep 0.25; \
	done; \
	if command -v open >/dev/null 2>&1; then open "$(APP_URL)"; \
	elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$(APP_URL)"; \
	else echo "Open manually: $(APP_URL)"; fi

stop: tunnel-stop server-stop

restart: stop start

status:
	@echo "SSH tunnel:"; \
	if [ -f "$(DATA_DIR)/ssh_tunnel.pid" ] && kill -0 "$$(cat $(DATA_DIR)/ssh_tunnel.pid)" 2>/dev/null; then \
		echo "  running (PID $$(cat $(DATA_DIR)/ssh_tunnel.pid))"; \
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
	@echo "--- ssh_tunnel.log ---"; tail -n 40 "$(DATA_DIR)/ssh_tunnel.log" 2>/dev/null || echo "(no log yet)"; \
	echo "--- server.log ---"; tail -n 40 "$(DATA_DIR)/server.log" 2>/dev/null || echo "(no log yet)"

clean: stop
	rm -f "$(DATA_DIR)/ssh_tunnel.pid" "$(DATA_DIR)/ssh_tunnel.log" "$(DATA_DIR)/server.pid" "$(DATA_DIR)/server.log"
