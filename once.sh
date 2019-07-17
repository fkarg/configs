#!/bin/sh

git config --global credential.helper cache
# not working for some reason:
# git config --global credential.helper 'store --file ~/.credentials-git'
