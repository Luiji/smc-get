#!/usr/bin/env sh
options='--line-numbers --inline-source --main README.rdoc'
files='README.rdoc COPYING smc-get.rb'
rdoc $options $files $@
