#!/bin/bash

set -e -x 
docker build --file Dockerfile.win --tag dhia-bechattaoui/kaldi-win:latest .
docker run --rm -v `realpath ..`:/io dhia-bechattaoui/kaldi-win /io/travis/build-wheels-win.sh
