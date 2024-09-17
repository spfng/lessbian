#!/usr/bin/make -f
SHELL := /bin/bash

all: build

clean:
	rm -rf build.*

build:
	bash build-iso-hybrid.sh
