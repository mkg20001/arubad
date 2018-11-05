#!/bin/bash

log() {
  echo "$(date +%s): $*"
}

die() {
  echo "ERROR: $*" >&2
  exit 2
}

instFile() {
  install -m 755 -g root -o root "$@"
}

tryLogin() {
  JAR="/tmp/arubad.cookiejar.txt"
  rm -f "$JAR"

  log "Detecting captive portal..."
  captiveReturn=$(curl -sc "$JAR" http://detectportal.firefox.com/)

  if [ "$captiveReturn" == "success" ]; then
    log "No captive portal found! Yay!"
    return
  fi

  extracted=$(echo "$captiveReturn" | sed -r "s|.+(http:\/\/detectportal.+)'.+|\1|g")

  if [ -z "$extracted" ]; then
    log "ERROR: Couldn't extract captive url! Not aruba captive!"
    return
  fi

  log "Extracted captive URL: $extracted"

  log "Follow redirect..."

  redir=$(curl -skILc "$JAR" "$extracted" | grep ^Location | tail -n 1 | sed "s|^Location: ||g")

  if [ -z "$redir" ]; then
    log "ERROR: Failed to follow"
    return
  fi

  log "Followed to $URL"
  post=$(echo "$redir" | sed "s|\\?.+||g")
  log "Posting to $post"

  log "Logging in as $ARUBA_USER..."

  # TODO: guest email login (just email field)

  curl -skLc "$JAR" --header "Referrer: $redir" --data "user=$ARUBA_USER" --data "password=$ARUBA_PW" --data "cmd=authenticate" --data "agreementAck=Accept" "$post"
  ex=$?

  if [ $ex -ne 0 ]; then
    log "ERROR: Login failed"
    return
  fi

  log "Checking again..."
  tryLogin
}

inst() {
  if [ $(id -u) -ne 0 ]; then
    die "Not root"
  fi

  if [ -z "$1" ] || [ -z "$2" ]; then
    die "Missing credentials"
  fi

  log "Writing config /etc/arubad..."

  echo "ARUBA_USER='$1'
ARUBA_PW='$2'" > /etc/arubad
  chmod 005 /etc/arubad
  chown root:root /etc/arubad

  log "Installing arubad.service..."

  SELF=$(readlink -f "$0")
  instFile "$SELF" "/usr/bin/arubad"
  SERV=${SELF/".sh"/".service"}
  instFile "$SERV" "/etc/systemd/system/arubad.service"

  log "Starting arubad.service..."

  systemctl daemon-reload
  systemctl enable arubad
  systemctl restart arubad

  log "DONE"
}

watchdog() {
  while read line; do
    intf=$(echo "$line" | sed -r "s|(^.+): .+|\1|g")
    if [ ! -z "$NM_DEBUG" ]; then
      log "DEBUG@$intf: $line"
    fi

    case "$line" in
      [a-z0-9._-]*": connected"|[a-z0-9._-]*": disconnected")
        log "Detected connection change on network interface $intf, check"
        log "[CAPTIVE]"
        tryLogin
        log "[/CAPTIVE]"
        ;;
    esac
  done
}

run() {
  if [ -z "$ARUBA_USER" ] || [ -z "$ARUBA_PW" ]; then
    die "Credentials not set"
  fi

  log "Starting monitoring of network..."

  LC_ALL=C nmcli m | watchdog
}

main() {
  case "$1" in
    install)
      shift
      inst "$@"
      ;;
    "run"|"")
      run
      ;;
    *)
      echo "Usage:"
      echo " $0 install <username> <password> # installs as systemd daemon"
      echo " $0 run # just runs, reads creds from \$ARUBA_USER and \$ARUBA_PW"
      exit 2
      ;;
  esac
}

main "$@"
