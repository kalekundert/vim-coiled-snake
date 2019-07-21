#!/usr/bin/env sh
DIR=$(dirname $0)
HOME=$DIR/dummy_home/plug nvim -u $DIR/vimrc "$@"
