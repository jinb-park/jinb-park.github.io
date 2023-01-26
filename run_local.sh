#!/bin/sh

cp -f posts_in_progress/2000*.md _posts/
sync

bundle exec jekyll serve
