#!/bin/bash

curr_dir=$(cd $(dirname $0); pwd)

[ -f $curr_dir/common.sh ] && source "$curr_dir/common.sh"

build_dir="./build"
openssl_branch="OpenSSL_1_0_2-stable"
nginx_branch="stable-1.14-linux"
git_label_tracking=".nginx.github.build.tar.gz.git.commit"
touch "$git_label_tracking"

function git_update() {
  local parent_dir=$1
  local gitrepo=$2
  local b=$3

  pushd "$parent_dir"
  ret=""
  gitrepo_name=$(echo $(basename $gitrepo) | cut -d. -f1)
  if [ -d $gitrepo_name ] ; then
    pushd $gitrepo_name
      git pull
      ret=$(git rev-parse $b)
    popd
  else
    git clone -b $b --depth 1 $gitrepo $gitrepo_name
    pushd $gitrepo_name
      git pull
      ret=$(git rev-parse $b)
    popd
  fi
  popd
  echo $ret
}

function compare_hashs() {
  local orig=$1
  local h1=$2
  local h2=$3

  combined_hash=$(echo "$h1$h2" | md5)
  if [ "$orig" = "$combined_hash" ] ; then
    echo 0
  else
    echo 1
  fi
}

mkdir -p "$build_dir"
ret0=$(git_update "$build_dir" "https://github.com/openssl/openssl.git" $openssl_branch)
ret1=$(git_update "$build_dir" "https://github.com/matr1xc0in/nginx.git" $nginx_branch)
comp_ret=$(compare_hashs $(cat $git_label_tracking) "$ret0" "$ret1")

if [ "$comp_ret" != "0" -o ! -f ./nginx.github.build.tar.gz ] ; then
  rm -f ./nginx.github.build.tar.gz
  tar --exclude .git -czf nginx.github.build.tar.gz ./build
  echo "$ret0$ret1" | md5 > "$git_label_tracking"
else
  echo "ok - nginx.github.build.tar.gz shall be the same, don't do anything."
fi

docker build \
  -t securenginx:latest \
  --build-arg NGINX_USER=$NGINX_USER \
  --build-arg NGINX_UID=$NGINX_UID \
  --build-arg NGINX_GID=$NGINX_GID \
  --file Dockerfile \
  .
