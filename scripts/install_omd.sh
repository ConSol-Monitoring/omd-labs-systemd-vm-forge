#!/usr/bin/env bash
# $1 = OS
# $2 = OMD version (master/latest/vX.XX)

# script must fail on errors, otherwise build would just continue and result in a broken image
set -e
set -x

function main() {
  BRANCH=$2
  BRANCH=${BRANCH#refs/heads/}
  BRANCH=${BRANCH#v}

  case $1 in
    rocky)  install_omd_rocky  $BRANCH;;
    debian) install_omd_debian $BRANCH;;
    *) { echo "$1: Unknown OS type!"; exit 1; }
  esac

  # Logrotate settings
  find /omd/versions/default/skel/etc/logrotate.d -type f -exec sed -i 's/rotate [0-9]*/rotate 0/' {} \;
}

function pkgName() {
  case $1 in
    "master")
      echo "omd-labs-edition-daily"
      ;;
    "latest")
      echo "omd-labs-edition"
      ;;
    *)
      echo "omd-${1}-labs-edition"
      ;;
  esac
}

function repoVersion() {
  if [ "x$1" == "xlatest" ] || [[ "x$1" =~ [0-9].[0-9]{2} ]]; then
    echo "stable"
  else
    echo "testing"
  fi
}

function install_omd_rocky() {
  VERSION=$1
  PACKAGENAME=`pkgName $VERSION`
  REPOVERSION=`repoVersion $VERSION`

  # --replacepkgs: Stage 2 base images already carry the lab channel repo(s),
  # so this can be a same-version reinstall, which plain `rpm -Uvh` rejects
  # ("package ... is already installed"). Same version -> no-op reinstall;
  # a newer repo rpm -> normal upgrade. Fresh installs are unaffected.
  rpm -Uvh --replacepkgs "https://labs.consol.de/repo/${REPOVERSION}/rhel10/x86_64/labs-consol-${REPOVERSION}.rhel10.noarch.rpm"
  # -y: non-interactive, symmetric with install_common.sh's `dnf -y update`.
  # A bare `yum update` prompts "Is this ok [y/N]:" whenever a baseos
  # point release landed in the mirror between the base stage's update pass
  # and this layer (mirror sync skew) - with stdin at EOF in a build the
  # prompt aborts the transaction (EMPIRICAL 2026-11-17: the el10_3.24
  # util-linux release broke the amd64 master test build exactly here).
  yum -y update
  yum -y install $PACKAGENAME
  test -f /usr/bin/ping && chmod +s /usr/bin/ping
}

function install_omd_debian() {
  VERSION=$1
  PACKAGENAME=`pkgName $VERSION`
  REPOVERSION=`repoVersion $VERSION`

  export DEBIAN_FRONTEND=noninteractive
  curl -fsS "https://labs.consol.de/repo/stable/monitoring-repo-consol-de-gpg-2026.asc" -o /etc/apt/trusted.gpg.d/monitoring-repo-consol-de-gpg-2026.asc
  echo "deb http://labs.consol.de/repo/${REPOVERSION}/debian $(lsb_release -cs) main" > /etc/apt/sources.list.d/labs-consol-${REPOVERSION}.list
  apt-get update
  apt-get install -y ${PACKAGENAME}
  apt-get clean

  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
}


main $@
