#!/bin/bash

yum install -y -e0 wget sqlite patch bzip2 xz file which sudo uuid curl openssl

cp -R data/* "${cw_ROOT}"
