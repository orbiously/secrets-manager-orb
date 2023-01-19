#!/bin/bash

if [[ $(curl -s "https://circleci.com/api/v2/me" -H "Circle-Token: ${!PARAM_CIRCLE_TOKEN}" -I -w "%{http_code}" -o /dev/null) != 200 ]]; then
  echo "The CircleCI API token you specified is not valid."
  exit 1
fi

case "$PARAM_VCS" in
  "bitbucket")
    DISPLAY_VCS="Bitbucket"
    ;;
  "github")
    DISPLAY_VCS="GitHub"    
    ;;
  "gitlab")
    DISPLAY_VCS="GitLab"
    ;;
esac


if  ! curl -s "https://circleci.com/api/v2/me/collaborations" -H "Circle-Token: ${!PARAM_CIRCLE_TOKEN}" | jq -r '.[].name' | grep -q "${PARAM_ORG_NAME}"; then
  echo "Unable to confirm access to the organization."
  echo -e "Either there is no $DISPLAY_VCS organization named \'$PARAM_ORG_NAME\' known to CircleCI,\n"
  echo -e "or the user who owns this API token is not a member of the '$PARAM_ORG_NAME' organization in $DISPLAY_VCS."
  echo "Make sure you specified the correct name (with the exact capitulization) and that make sure the CircleCI personal API token is valid."
  exit 1
fi