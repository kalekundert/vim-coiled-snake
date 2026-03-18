#!/usr/bin/env sh

rm -rf repo
git init repo
cd repo

cp ../demo_v1.py demo.py
git add
git commit -m 'Add foo()'

cp ../demo_v2.py demo.py

vim -u ../vimrc demo.py
