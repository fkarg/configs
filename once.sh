#!/bin/sh

git config --global credential.helper cache
git config --global credential.helper 'store --file ~/.credentials-git'
