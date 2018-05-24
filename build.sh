#!/bin/bash

set -e

curr_dir=$(cd $(dirname $0); pwd)

[ -f $curr_dir/common.sh ] && source "$curr_dir/common.sh"

build_dir="./build"
openssl_branch="OpenSSL_1_0_2-stable"
nginx_branch="stable-1.14-linux"
git_label_tracking=".nginx.github.build.tar.gz.git.commit"
touch "$git_label_tracking"
hashcmd="md5sum"

# return os in lower case
function detect_os() {
  local osname=""
  if [ -f "/etc/os-release" ] ; then
    osname=$(awk -F= '/^NAME/{print $2}' /etc/os-release | tr -d '"' | tr "[:upper:]" "[:lower:]")
  elif [ -f "/etc/redhat-release" ] ; then
    osname=$(cat "/etc/redhat-release" | tr "[:upper:]" "[:lower:]")
  elif [ "$(which uname)" != "" ] ; then
    osname=$(uname | tr "[:upper:]" "[:lower:]")
  else
    >&2 echo "fatal - unsupported OS to run this script!"
    osname="unknown"
  fi
  echo $osname
}

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
  local hcmd=$1
  local orig=$2
  local h1=$3
  local h2=$4

  combined_hash=$(echo "$h1$h2" | $hcmd)
  if [ "$orig" = "$combined_hash" ] ; then
    echo 0
  else
    echo 1
  fi
}

osname=$(detect_os)
echo "ok - detected os $osname, installing and configuring docker"
case $osname in
  ubuntu*)
      sudo apt-get remove -y docker docker-engine docker.io
      sudo apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        software-properties-common
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
      sudo apt-key fingerprint 0EBFCD88
      sudo add-apt-repository \
        "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) \
        stable"
      sudo apt-get update
      sudo apt-get install -y docker-ce
      # The user needs to re-login to take effect on the new group
      # curr_grp=$(id -ng)
      sudo usermod -a -G docker $USER
      # newgrp docker
      # newgrp $curr_grp
      sudo systemctl restart docker
      sudo systemctl enable docker
    ;;
  darwin*)
      hashcmd='md5'
    ;;
  *)
    ;;
esac

mkdir -p "$build_dir"
ret0=$(git_update "$build_dir" "https://github.com/openssl/openssl.git" $openssl_branch)
ret1=$(git_update "$build_dir" "https://github.com/matr1xc0in/nginx.git" $nginx_branch)
comp_ret=$(compare_hashs $hashcmd $(cat $git_label_tracking) "$ret0" "$ret1")

if [ "$comp_ret" != "0" -o ! -f ./nginx.github.build.tar.gz ] ; then
  rm -f ./nginx.github.build.tar.gz
  tar --exclude .git -czf nginx.github.build.tar.gz ./build
  echo "$ret0$ret1" | $MD5CMD > "$git_label_tracking"
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
