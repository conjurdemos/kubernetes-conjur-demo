#!/bin/bash 
set -eo pipefail

# authn creds in environment vars
# CONJUR_APPLIANCE_URL
# CONJUR_SSL_CERTIFICATE
# CONJUR_AUTHN_TOKEN_FILE

################  MAIN   ################
# $1 - name of variable to retrieve
main() {
  if [[ $# -ne 1 ]] ; then
    printf "\n\tUsage: %s <variable-name>\n\n" $0
    exit -1
  fi
  VAR_ID=$1

  CONT_SESSION_TOKEN=$(cat $CONJUR_AUTHN_TOKEN_FILE | base64 | tr -d '\r\n')

  urlify "$VAR_ID"
  VAR_ID=$URLIFIED

  VAR_VALUE=$(curl -s -k \
	--request GET \
	-H "Content-Type: application/json" \
	-H "Authorization: Token token=\"$CONT_SESSION_TOKEN\"" \
	$CONJUR_APPLIANCE_URL/variables/$VAR_ID/value)

  echo $VAR_VALUE
}

################
# URLIFY - converts '/' and ':' in input string to hex equivalents
# in: $1 - string to convert
# out: URLIFIED - converted string in global variable
urlify() {
        local str=$1; shift
        str=$(echo $str | sed 's= =%20=g')
        str=$(echo $str | sed 's=/=%2F=g')
        str=$(echo $str | sed 's=:=%3A=g')
        URLIFIED=$str
}

main "$@"

exit
