#!/bin/bash

HELP="
This script can be create deb/rpm packages or doker image
contained last version for Moira monitoring system (https://github.com/moira-alert)

Requirements: Golang, fpm, rpmbuild (for rpm), dpkg (for deb), docer (for docker)

Usage:
   ./build.sh MICROSERVICE PACKAGETYPE
   MICROSERVICE must be notifier|cache|web|worker|full|all
   PACKAGETYPE must be deb|rpm|docker|all

Examples:
   ./build.sh notifier rpm - created rpm packages contained last version of moira-notifier
   ./build.sh full docker - created docker image contained redis and full moira monitoring ready to working

"
#set -e
URL="https://github.com/moira-alert"
LICENSE="GPLv3"
VENDOR="SKB Kontur"
MAINTEINER="https://gitter.im/moira-alert/moira"
MICROSERVICE=$1
PACKAGETYPE=$2
PARAMS=$#
DIST="$(pwd)/dist"
TMP="$(pwd)/tmp"

GOBIN="$(which go 2>/dev/null)" # default golang
#GOROOT=/usr/local/go1.5.2/bin/go
#GOROOT=/usr/local/go1.4.2/bin/go
GOPATH="$TMP/gocode"

check() {
  if [ "$PARAMS" -ne 2 ]; then
    echo "ERROR! Are expected two params"
    print_help
  fi
  if ! [ -x "$GOBIN" ]; then
    echo "Golang must be installed"
    exit 1
  fi
  if ! [ -x "$(which fpm 2>/dev/null)" ]; then
    echo "FPM must be installed"
    exit 1
  fi
  case "$MICROSERVICE" in
  "notifier"|"cache"|"web"|"worker"|"full"|"all")
  ;;
  *)
    echo "ERROR! Undefined Microservice"
    print_help
  ;;
  esac
  case "$PACKAGETYPE" in
  "rpm")
    if ! [ -x "$(which rpmbuild 2>/dev/null)" ]; then
      echo "rpmbuild not found "
    fi
  ;;
  "deb")
    if ! [ -x "$(which dpkg 2>/dev/null)" ]; then
      echo "dpkg not found "
    fi
  ;;
  "docker")
    if ! [ -x "$(which docker 2>/dev/null)" ]; then
      echo "docker not found "
    fi
  ;;
  "all")
    for tool in "rpmbuild" "dpkg" "docker"; do
      if ! [ -x "$(which $tool 2>/dev/null)" ]; then
        echo "$tool not found "
      fi
    done
  ;;
  *)
    echo "ERROR! Undefined Package type"
    print_help
  ;;
  esac
}

clean() {
  echo "Cleaning"
  rm -rf $DIST
# rm -rf ./gocode
  mkdir $DIST &>/dev/null
  mkdir $GOPATH &>/dev/null
  clean_package
  #rm -rf $TMP
  mkdir $TMP &>/dev/null
}

clean_package() {
  rm -rf $TMP/package
  mkdir $TMP/package &>/dev/null
}

print_help() {
  echo "$HELP"
  exit 1
}

setup_worker() {
  echo "Install worker"
  git clone "https://github.com/moira-alert/worker" $TMP/worker

}

setup_notifier() {
  echo "Install dependencies for moira-notifier"
  $GOBIN get -v "github.com/moira-alert/notifier"
  $GOBIN get -v "github.com/moira-alert/notifier/notifier"

  #$GOBIN build -v "github.com/moira-alert/notifier/notifier"
  $GOBIN install -v "github.com/moira-alert/notifier/notifier"
}

package_notifier() {
  PT=$1
  NOTIFIER_COMMIT=$(git --git-dir $GOPATH/src/github.com/moira-alert/notifier/.git log --pretty=format:"%h" -n 1)
  NOTIFIER_DATE_COMMIT=$(date -d $(git --git-dir $GOPATH/src/github.com/moira-alert/notifier/.git log --date=short --pretty=format:"%cd" -n 1) +%Y%m%d)
  NOTIFIER_VERSION="$NOTIFIER_DATE_COMMIT$NOTIFIER_COMMIT"

  mkdir -p $TMP/package/etc/init.d
  mkdir -p $TMP/package/etc/moira
  mkdir -p $TMP/package/usr/sbin
  mkdir -p $TMP/package/usr/lib/systemd/system

  cp ./files/notifier/$PT/init.d/moira-notifier $TMP/package/etc/init.d/moira-notifier
  cp ./files/notifier/$PT/systemd/moira-notifier.service $TMP/package/usr/lib/systemd/system/moira-notifier.service
  cp ./files/config.yml $TMP/package/etc/moira/config.yml
  cp $GOPATH/bin/notifier $TMP/package/usr/sbin/moira-notifier

  echo "Create $PT package"
  fpm -t $PT \
    -s "dir" \
    --description "Moira Notifier" \
    -C $TMP/package \
    --vendor "$VENDOR" \
    --url "$URL" \
    --license "$LICENSE" \
    --maintainer "$MAINTEINER" \
    --name "moira-notifier" \
    --version "$NOTIFIER_VERSION" \
    --config-files "/etc/init.d/moira-notifier" \
    --config-files "/etc/moira/config.yml" \
    --config-files "/usr/lib/systemd/system/moira-notifier.service" \
    --after-install "./files/notifier/$PT/postinst" \
    -p $DIST
}

setup_cache() {
  echo "Install dependencies for moira-cache"
  $GOBIN get -v "github.com/moira-alert/cache"
  $GOBIN install -v "github.com/moira-alert/cache"
}

package_cache() {
  PT=$1
  CACHE_COMMIT=$(git --git-dir $GOPATH/src/github.com/moira-alert/cache/.git log --pretty=format:"%h" -n 1)
  CACHE_DATE_COMMIT=$(date -d $(git --git-dir $GOPATH/src/github.com/moira-alert/cache/.git log --date=short --pretty=format:"%cd" -n 1) +%Y%m%d)
  CACHE_VERSION="$NOTIFIER_DATE_COMMIT$NOTIFIER_COMMIT"

  mkdir -p $TMP/package/etc/init.d
  mkdir -p $TMP/package/etc/moira
  mkdir -p $TMP/package/usr/sbin
  mkdir -p $TMP/package/usr/lib/systemd/system

  cp ./files/cache/$PT/init.d/moira-cache $TMP/package/etc/init.d/moira-cache
  cp ./files/cache/$PT/systemd/moira-cache.service $TMP/package/usr/lib/systemd/system/moira-cache.service
  cp ./files/config.yml $TMP/package/etc/moira/config.yml
  cp $GOPATH/bin/cache $TMP/package/usr/sbin/moira-cache

  echo "Create $PT package"
  fpm -t $PT \
    -s "dir" \
    --description "Moira Cache" \
    -C $TMP/package \
    --vendor "$VENDOR" \
    --url "$URL" \
    --license "$LICENSE" \
    --maintainer "$MAINTEINER" \
    --name "moira-cache" \
    --version "$NOTIFIER_VERSION" \
    --config-files "/etc/init.d/moira-cache" \
    --config-files "/etc/moira/config.yml" \
    --config-files "/usr/lib/systemd/system/moira-cache.service" \
    --after-install "./files/notifier/$PT/postinst" \
    -p $DIST
}

package_full() {
  echo "Package full"
}

#export GOPATH="$(pwd)/gocode"
check
clean

case "$MICROSERVICE" in
  "notifier")
    clean_package
    setup_notifier
    case "$PACKAGETYPE" in
      "deb") package_notifier "deb" ;;
      "rpm") package_notifier "rpm" ;;
      "docker")
        package_notifier "rpm"
        echo "Generate Docker Image"
      ;;
      "all")
        package_notifier "deb"
        clean_package
        package_notifier "rpm"
      ;;
    esac
  ;;
  "cache")
    clean_package
    setup_cache
    case "$PACKAGETYPE" in
      "deb") package_cache "deb" ;;
      "rpm") package_cache "rpm" ;;
      "docker")
        package_cache "rpm"
        echo "Generate Docker Image"
      ;;
      "all")
        package_cache "rpm"
        clean_package
        package_cache "deb"
      ;;
    esac
  ;;

  "full")
    echo "full"
    setup_notifier
    setup_cache
    package_full
  ;;
  "all")
    clean_package
    setup_notifier
    package_notifier "rpm"
    clean_package
    package_notifier "deb"
    clean_package
    setup_cache
    package_cache "rpm"
    clean_package
    package_cache "deb"

  ;;
  *)
    echo "Fail!"
    exit 1
  ;;
esac

exit 0
