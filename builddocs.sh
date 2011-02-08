#!/usr/bin/env sh
options='--line-numbers --inline-source --main README.rdoc --title smc-get'
files='README.rdoc COPYING smc-get.rb'
rdoc $options $files $@
