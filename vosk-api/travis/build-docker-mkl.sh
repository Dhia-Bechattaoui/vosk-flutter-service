#!/bin/bash

set -e -x 
docker build --file Dockerfile.manylinux-mkl --tag dhia-bechattaoui/kaldi-manylinux-mkl:latest .
docker run --rm -v `realpath ..`:/io dhia-bechattaoui/kaldi-manylinux-mkl /io/travis/build-wheels-mkl.sh
