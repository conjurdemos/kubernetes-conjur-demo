#!/bin/bash 

declare VAR_ID=secrets/db-password
#declare VAR_ID="DemoVault/CICD/CICD_Secrets/Cloud Service-AWSAccessKeys-ec2_user/username"
#declare VAR_ID="DemoVault/CICD/CICD_Secrets/Cloud Service-AWSAccessKeys-ec2_user/password"

main() {
  CONT_SESSION_TOKEN=$(cat $CONJUR_AUTHN_TOKEN_FILE | base64 | tr -d '\r\n')

  urlify "$VAR_ID"
  VAR_ID=$URLIFIED

  VAR_VALUE=$(curl -s -k \
	--request GET \
	--cacert $CONJUR_CERT_FILE \
	-H "Content-Type: application/json" \
	-H "Authorization: Token token=\"$CONT_SESSION_TOKEN\"" \
	$CONJUR_APPLIANCE_URL/variables/$VAR_ID/value)

  echo
  echo "The retrieved value is: $VAR_VALUE"
  echo
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
