#!/usr/bin/env bash
#
# A script to use 1secmail temp mail service in terminal
#
#/ Usage:
#/   ./onesecmail.sh [-i <inbox>|-m <uid>|-d <uid>|-s]
#/
#/ Options:
#/   no option        Optional, randamly get an inbox
#/   -i <inbox>       Optional, get an inbox by its mail address
#/   -m <uid>         Optional, show mail by its uid
#/   -s               Optional, show available domains
#/   -h | --help      Display this help message
#/
#/ Examples:
#/   \e[32m- Generate a random inbox:\e[0m
#/     ~$ ./onesecmail.sh
#/
#/   \e[32m- Get mails in test@1secmail.org:\e[0m
#/     ~$ ./onesecmail.sh \e[33m-i 'test@1secmail.org'\e[0m
#/
#/   \e[32m- Show mail 897283223 detail: \e[0m
#/     ~$ ./onesecmail.sh \e[33m-i 'test@1secmail.org' -m 897283223\e[0m
#/
#/   \e[32m- Show all available domains: \e[0m
#/     ~$ ./onesecmail.sh \e[33m-s\e[0m

set -e
set -u

usage() {
    # Display usage message
    printf "\n%b\n" "$(grep '^#/' "$0" | cut -c4-)" && exit 0
}

set_var() {
    # Declare variables
    _HOST="http://1secmail.net/api/v1"
    _INBOX_URL="$_HOST/?action=getMessages"
    _MESSAGE_URL="$_HOST/?action=readMessage"
}

set_command() {
    # Declare commands
    _CURL="$(command -v curl)" || command_not_found "curl" "https://curl.haxx.se/download.html"
    _JQ="$(command -v jq)" || command_not_found "jq" "https://stedolan.github.io/jq/"
    _W3M="$(command -v w3m)" || true
    _FAKER="$(command -v faker-cli)" || true
}

set_args() {
    # Declare arguments
    expr "$*" : ".*--help" > /dev/null && usage
    while getopts ":hsi:m:" opt; do
        case $opt in
            i)
                _INBOX="$OPTARG"
                ;;
            m)
                _MESSAGE_UID="$OPTARG"
                _FLAG_GET_MESSAGE=true
                ;;
            s)
                _FLAG_SHOW_DOMAIN=true
                ;;
            h)
                usage
                ;;
            \?)
                echo "Invalid option: -$OPTARG" >&2
                usage
                ;;
        esac
    done
}

command_not_found() {
    # Show command not found message
    # $1: command name
    # $2: installation URL
    printf "%b\n" '\033[31m'"$1"'\033[0m command not found!'
    [[ -n "${2:-}" ]] && printf "%b\n" 'Install from \033[31m'"$2"'\033[0m'
    exit 1
}

fake_username () {
    # Create a fake user
    if [[ -z "$_FAKER" ]]; then
        tr -dc 'a-z0-9' < /dev/urandom \
            | head -c9
    else
        sed -E 's/"//g' <<< "$($_FAKER -n firstName).$($_FAKER -n lastName)" \
            | tr '[:upper:]' '[:lower:]'
    fi
}

get_inbox() {
    # Get inbox by mailbox address
    # $1: address
    local login domain
    login=$(awk -F '@' '{print $1}' <<< "$1")
    domain=$(awk -F '@' '{print $2}' <<< "$1")
    $_CURL -sSL "${_INBOX_URL}&login=${login}&domain=${domain}" | $_JQ
}

get_message() {
    # Get message by id
    # $1: address
    # $2: id
    local login domain message
    login=$(awk -F '@' '{print $1}' <<< "$1")
    domain=$(awk -F '@' '{print $2}' <<< "$1")
    message="$($_CURL -sSL "${_MESSAGE_URL}&login=${login}&domain=${domain}&id=${2}")"
    if [[ "$message" == "Message not found" ]]; then
        echo "$message"
        exit 0
    else
        if [[ -z $_W3M ]]; then
            $_JQ -r '.htmlBody' <<< "$message"
        else
            $_W3M -T "text/html" <<< "$($_JQ -r '.htmlBody' <<< "$message")"
        fi
    fi
}

show_domain() {
    # Show available domains
    echo -e "1secmail.com\n1secmail.org\n1secmail.net"
}

get_random_inbox() {
    # Get a randam inbox
    local u d
    u=$(fake_username)
    d=$(show_domain | shuf | tail -1)

    get_inbox "$u@$d"
    echo "$u@$d"
}

main() {
    set_args "$@"
    set_command
    set_var

    if [[ -z "$*" ]]; then
        get_random_inbox
    else
        [[ -n "${_FLAG_SHOW_DOMAIN:-}" ]] && show_domain
        if [[ -n "${_INBOX:-}" ]]; then
            if [[ "${_FLAG_GET_MESSAGE:-}" == true ]]; then
                get_message "$_INBOX" "${_MESSAGE_UID:-}"
            else
                get_inbox "$_INBOX"
            fi
        fi
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
