X11=DISPLAY=host.docker.internal:0

up-xpra:
	docker compose --profile xpra up -d --build

up-x11:
	$(X11) docker compose --profile x11 up -d --build

down:
	docker compose down

ros:
	docker exec -it ros bash

gz:
	docker exec -it gz bash

cmu:
	docker exec -it cmu bash

logs:
	docker compose logs -f --tail=200

xpra-start:
	docker compose exec ros_xpra bash -lc 'xpra control :100 start xterm'
	docker compose exec gz_xpra  bash -lc 'xpra control :100 start xterm'
	docker compose exec cmu_xpra bash -lc 'xpra control :100 start xterm'