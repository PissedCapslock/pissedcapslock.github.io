#!/bin/bash -e

function createTagFile(){
  local tag=$1;
  local tagFile="_generated_tags/${1}.markdown"
  if [ ! -f $tagFile ]; then
    echo "---" >> $tagFile
    echo "layout: posts_by_tag" >> $tagFile
    echo "tag-name: ${tag}" >> $tagFile
    echo "---" >> $tagFile
  fi
}

if [ ! -d _posts ] || [ ! -d _drafts ]; then
  >&2 echo "This script should be called from the root dir"
  exit 1
fi

for folder in _posts _drafts; do
  for post in $(find $folder -name "*.markdown"); do
    # A for loop automatically splits on white space. How convenient !
    for tag in $(grep --extended-regexp "^tags:.*$" $post | sed 's/tags://g'); do
      createTagFile $tag
    done
  done
done