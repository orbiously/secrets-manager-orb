#!/bin/bash

if [[ $(curl -s "https://circleci.com/api/v2/me" -H "Circle-Token: ${!PARAM_CIRCLE_TOKEN}" -I -w "%{http_code}" -o /dev/null) != 200 ]]; then
  echo "The CircleCI API token you specified is not valid."
  exit 1
fi

case "$PARAM_VCS" in
  "bitbucket")
    DISPLAY_VCS="Bitbucket"
    VCS_SLUG="bb"
    ORG_SLUG="$VCS_SLUG/$PARAM_ORG_NAME"
    ;;
  "github")
    DISPLAY_VCS="GitHub"
    VCS_SLUG="gh"
    ORG_SLUG="$VCS_SLUG/$PARAM_ORG_NAME"
    ;;
  "gitlab")
    DISPLAY_VCS="GitLab"
    VCS_SLUG="circleci"
    ORG_SLUG=$(curl -s -G "https://circleci.com/api/v2/me/collaborations" -H "Circle-Token: ${!PARAM_CIRCLE_TOKEN}" | jq -r --arg ORG_NAME "$PARAM_ORG_NAME" '.[] | select(.name == "'"$PARAM_ORG_NAME"'") | .slug')
    ;;
esac


if  ! curl -s "https://circleci.com/api/v2/me/collaborations" -H "Circle-Token: ${!PARAM_CIRCLE_TOKEN}" | jq -r '.[].name' | grep -q "${PARAM_ORG_NAME}"; then
  echo "Unable to confirm access to the organization."
  echo -e "Either there is no $DISPLAY_VCS organization named '$PARAM_ORG_NAME' known to CircleCI,\n"
  echo -e "or the user who owns this API token is not a member of the '$PARAM_ORG_NAME' organization in $DISPLAY_VCS."
  echo "Make sure you specified the correct name (with the exact capitulization) and that make sure the CircleCI personal API token is valid."
  exit 1
fi

echo "export VCS_SLUG=$VCS_SLUG" >> "$BASH_ENV"
echo "export ORG_SLUG=$ORG_SLUG" >> "$BASH_ENV"