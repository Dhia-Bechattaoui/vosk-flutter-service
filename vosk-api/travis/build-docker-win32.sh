#!/bin/bash

set -e -x 
docker build --file Dockerfile.win32 --tag dhia-bechattaoui/kaldi-win32:latest .
docker run --rm -v `realpath ..`:/io dhia-bechattaoui/kaldi-win32 /io/travis/build-wheels-win32.sh
