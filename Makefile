IMAGE_NAME=ios_re_tool
CONTAINER_NAME=ios_re

build:
	docker build -t $(IMAGE_NAME) --build-arg SDK_VERSION=$(SDK_VERSION) .

run_without_usbfluxd:
	docker run -d -p 103100:13100 -p 103101:13101 -p 103102:13102 -p 50000:5000 -p 3222:22 -p 8888:8888 --name $(CONTAINER_NAME) \
	-v $(shell pwd):/root/host \
	$(IMAGE_NAME)

run:
	docker run -d -p 10310:13100 -p 10311:13101 -p 10312:13102 -p 50000:5000 -p 3222:22 -p 8888:8888 --name $(CONTAINER_NAME) \
	--privileged -v /dev/bus/usb:/dev/bus/usb \
	-v $(shell pwd):/root/host \
	$(IMAGE_NAME)

shell:
	docker exec -ti $(CONTAINER_NAME) /bin/bash &&  true

clean:
	docker rm -f $(CONTAINER_NAME)

.PHONY: build run run_without_usbfluxd clean

