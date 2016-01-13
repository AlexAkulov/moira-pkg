#!/bin/bash

HELP="
This script can be create deb/rpm packages or doker image
contained last version for Moira monitoring system (https://github.com/moira-alert)

Requirements: Golang, fpm, rpmbuild (for rpm), dpkg (for deb), docer (for docker)

Usage:
   ./build.sh MICROSERVICE PACKAGETYPE VERSION
   MICROSERVICE must be notifier|cache|web|worker|full|all
   PACKAGETYPE must be deb|rpm|docker|all
   VERSION must be release|last default be release

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
VERSION=$3
PARAMS=$#
DIST="$(pwd)/dist"
#TMP="$(pwd)/tmp"
TMP="/tmp/moira"
NPMBIN="$(which npm 2>/dev/null)"
GOBIN="$(which go 2>/dev/null)" # default golang
#GOROOT=/usr/local/go1.5.2/bin/go
#GOROOT=/usr/local/go1.4.2/bin/go
GOPATH="$TMP/gocode"

check() {
  if [ "$PARAMS" -ne 3 ]; then
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
  "web")
    if ! [ -x "$NPMBIN" ]; then
      echo "npm not found "
      exit 1
    fi
  ;;
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
      exit 1
    fi
  ;;
#  "deb")
#    if ! [ -x "$(which dpkg 2>/dev/null)" ]; then
#      echo "dpkg not found "
#      exit 1
#    fi
#  ;;
  "docker")
    if ! [ -x "$(which docker 2>/dev/null)" ]; then
      echo "docker not found "
      exit 1
    fi
  ;;
  "all")
    for tool in "rpmbuild" "dpkg" "docker"; do
      if ! [ -x "$(which $tool 2>/dev/null)" ]; then
        echo "$tool not found "
        exit 1
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

setup_web() {
  git clone https://github.com/moira-alert/web.git $TMP/web
  cd $TMP/web
  $NPMBIN install --production
  $NPMBIN run build
  cd -
 
  mkdir -p $TMP/package/var/www/moira
  mkdir -p $TMP/package/etc/nginx/conf.d

  cp $TMP/web/favicon.ico $TMP/package/var/www/moira/
  cp $TMP/web/index.html $TMP/package/var/www/moira/ 
  cp -R $TMP/web/dist $TMP/package/var/www/moira/
  cp ./files/web/config.json $TMP/package/var/www/moira/
  cp ./files/web/moira-nginx.conf $TMP/package/etc/nginx/conf.d/moira.conf
}

package_web() {
  PT=$1
  WEB_COMMIT=$(git --git-dir $TMP/web/.git log --pretty=format:"%h" -n 1)
  WEB_DATE_COMMIT=$(date -d $(git --git-dir $TMP/web/.git log --date=short --pretty=format:"%cd" -n 1) +%Y%m%d)
  WEB_VERSION="$WEB_DATE_COMMIT$WEB_COMMIT"

  fpm -t $PT \
    -s "dir" \
    --description "Moira Web" \
    -C $TMP/package \
    --vendor "$VENDOR" \
    --url "$URL" \
    --license "$LICENSE" \
    --maintainer "$MAINTEINER" \
    --name "moira-web" \
    --version "$WEB_VERSION" \
    --config-files "/var/www/moira/config.json" \
    --config-files "/etc/nginx/conf.d/moira.conf" \
    --depends nginx \
    -p $DIST
}

setup_worker() {
  echo "Install worker"
  git clone "https://github.com/moira-alert/worker" $TMP/worker
  
}

setup_notifier() {
  PT=$1
  echo "Install dependencies for moira-notifier"
  $GOBIN get -v "github.com/moira-alert/notifier"
  $GOBIN get -v "github.com/moira-alert/notifier/notifier"

  #$GOBIN build -v "github.com/moira-alert/notifier/notifier"
  $GOBIN install -v "github.com/moira-alert/notifier/notifier"
  
  mkdir -p $TMP/package/etc/init.d
  mkdir -p $TMP/package/etc/moira
  mkdir -p $TMP/package/usr/sbin
  mkdir -p $TMP/package/usr/lib/systemd/system

  cp ./files/notifier/$PT/init.d/moira-notifier $TMP/package/etc/init.d/moira-notifier
  cp ./files/notifier/$PT/systemd/moira-notifier.service $TMP/package/usr/lib/systemd/system/moira-notifier.service
  cp ./files/config.yml $TMP/package/etc/moira/config.yml
  cp $GOPATH/bin/notifier $TMP/package/usr/sbin/moira-notifier
}

package_notifier() {
  PT=$1
  NOTIFIER_COMMIT=$(git --git-dir $GOPATH/src/github.com/moira-alert/notifier/.git log --pretty=format:"%h" -n 1)
  NOTIFIER_DATE_COMMIT=$(date -d $(git --git-dir $GOPATH/src/github.com/moira-alert/notifier/.git log --date=short --pretty=format:"%cd" -n 1) +%Y%m%d)
  NOTIFIER_VERSION="$NOTIFIER_DATE_COMMIT$NOTIFIER_COMMIT"

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
  PT=$1
  echo "Install dependencies for moira-cache"
  $GOBIN get -v "github.com/moira-alert/cache"
  $GOBIN install -v "github.com/moira-alert/cache"
  
  mkdir -p $TMP/package/etc/init.d
  mkdir -p $TMP/package/etc/moira
  mkdir -p $TMP/package/usr/sbin
  mkdir -p $TMP/package/usr/lib/systemd/system

  cp ./files/cache/$PT/init.d/moira-cache $TMP/package/etc/init.d/moira-cache
  cp ./files/cache/$PT/systemd/moira-cache.service $TMP/package/usr/lib/systemd/system/moira-cache.service
  cp ./files/config.yml $TMP/package/etc/moira/config.yml
  cp $GOPATH/bin/cache $TMP/package/usr/sbin/moira-cache
}

package_cache() {
  PT=$1
  CACHE_COMMIT=$(git --git-dir $GOPATH/src/github.com/moira-alert/cache/.git log --pretty=format:"%h" -n 1)
  CACHE_DATE_COMMIT=$(date -d $(git --git-dir $GOPATH/src/github.com/moira-alert/cache/.git log --date=short --pretty=format:"%cd" -n 1) +%Y%m%d)
  CACHE_VERSION="$NOTIFIER_DATE_COMMIT$NOTIFIER_COMMIT"

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
  PT=$1
  MOIRA_VERSION=$(date +%Y%m%d)
  
  fpm -t $PT \
    -s "dir" \
    --description "Moira Full" \
    -C $TMP/package \
    --vendor "$VENDOR" \
    --url "$URL" \
    --license "$LICENSE" \
    --maintainer "$MAINTEINER" \
    --name "moira" \
    --version "$MOIRA_VERSION" \
    # common
    --config-files "/etc/moira/config.yml" \
    --after-install "./files/notifier/$PT/postinst" \
    --depends redis \
    # cache
    --config-files "/etc/init.d/moira-cache" \
    --config-files "/usr/lib/systemd/system/moira-cache.service" \
    --after-install "./files/notifier/$PT/postinst" \
    # notifier
    --config-files "/etc/init.d/moira-notifier" \
    --config-files "/usr/lib/systemd/system/moira-notifier.service" \
    # web
    --config-files "/var/www/moira/config.json" \
    --config-files "/etc/nginx/conf.d/moira.conf" \
    --depends nginx \
    -p $DIST
}

check
clean

call_setup() {
    echo ""
  # MODULE_NAME="test"
  #FUNCTION_NAME="run"

  #${MODULE_NAME}_${FUNCTION_NAME}
}

call_package() {
    echo ""
}
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
  "web")
    clean_package
    setup_web
    case "$PACKAGETYPE" in
      "deb") package_web "deb" ;;
      "rpm") package_web "rpm" ;;
      "docker")
        package_web "rpm"
        echo "Generate Docker Image"
      ;;
      "all")
        package_web "rpm"
        clean_package
        package_web "deb"
      ;;
    esac
  ;;
  "full")
    echo "full"
    clean_package
    setup_notifier "rpm"
    setup_cache "rpm"
    setup_web
    package_full "rpm"
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
