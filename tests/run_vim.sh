#!/usr/bin/env sh
DIR=$(dirname $0)
HOME=$DIR/dummy_home vim -u $DIR/vimrc "$@"
