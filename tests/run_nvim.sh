#!/usr/bin/env sh
DIR=$(dirname $0)
HOME=$DIR/dummy_home nvim -u $DIR/vimrc "$@"
