#!/bin/bash

set -e -x 
docker build --file Dockerfile.manylinux --tag dhia-bechattaoui/kaldi-manylinux:latest .
docker run --rm -v `realpath ..`:/io dhia-bechattaoui/kaldi-manylinux /io/travis/build-wheels.sh
