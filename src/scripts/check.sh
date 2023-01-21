#!/bin/bash

if [[ $(curl -s "https://circleci.com/api/v2/me/collaborations" -H "Circle-Token: ${!PARAM_CIRCLE_TOKEN}" -I -w "%{http_code}" -o collab-API-response.json) != 200 ]]; then
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


if  ! jq -r '.[].name' collab-API-response.json | grep -q "${PARAM_ORG_NAME}"; then
  echo -e "Unable to confirm access to the '${PARAM_ORG_NAME}' organization."
  echo -e "Either there is no $DISPLAY_VCS organization named '$PARAM_ORG_NAME' known to CircleCI,\n"
  echo -e "or the user who owns this API token is not a member of the '$PARAM_ORG_NAME' organization in $DISPLAY_VCS."
  echo "Make sure you specified the correct name (with the exact capitulization)."
  exit 1
else
  ORG_SLUG=$(jq -r --arg ORG_NAME "$PARAM_ORG_NAME" '.[] | select(.name == "'"$PARAM_ORG_NAME"'") | .slug' collab-API-response.json)
fi

echo "export ORG_SLUG=$ORG_SLUG" >> "$BASH_ENV"