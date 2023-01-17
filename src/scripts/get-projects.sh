#!/bin/bash

if [ $(curl -s "https://circleci.com/api/v2/me" -H "Circle-Token: ${!PARAM_CIRCLE_TOKEN}" -I -w "%{http_code}" -o /dev/null) != 200 ]; then
  echo "The CircleCI API token you specified is not valid."
  exit 1
fi

case $(echo "$PARAM_VCS") in
  "bitbucket")
    DISPLAY_VCS="Bitbucket"
    VCS_SLUG="bb"
    ORG_SLUG="$VCS_SLUG/$PARAM_ORG_NAME"
    ;;
  "github")
    DISPLAY_VCS="GitHub"
    VCS_SLUG="bb"
    ORG_SLUG="$VCS_SLUG/$PARAM_ORG_NAME"
    ;;
  "gitlab")
    DISPLAY_VCS="GitLab"
    VCS_SLUG="circleci"
    ORG_SLUG=$(curl -s -G "https://circleci.com/api/v2/me/collaborations" -H "Circle-Token: ${!PARAM_CIRCLE_TOKEN}" | jq -r --arg ORG_NAME "$PARAM_ORG_NAME" '.[] | select(.name == "'"$PARAM_ORG_NAME"'") | .slug')
    ;;
esac


if [ ! (curl -s "https://circleci.com/api/v2/me/collaborations" | jq -r '.[].name' | grep -q "${PARAM_ORG_NAME}") ]; then
  echo "Unable to confirm access to the organization."
  echo -e "Either there is no $DISPLAY_VCS organization named \'$PARAM_ORG_NAME\' known to CircleCI,\n"
  echo "or the user who owns this API token is not a member of the \'$PARAM_ORG_NAME\' organization in $DISPLAY_VCS."
  echo "Make sure you specified the correct name (with the exact capitulization) and/or make sure the CircleCI personal API token is correct/valid."
  exit 1
fi

echo '{"projects": []}' > all-projects-report.json

#### These scripts will produce a 'projects-array-like-list.txt' file.
#### Each line of the file is a project's name and its slug, separated by a ';' (semi-colon).
if [ "$PARAM_VCS" = "bitbucket" ]; then eval "$SCRIPT_GET_PROJECTS_BITBUCKET";
elif [ "$PARAM_VCS" = "github" ]; then eval "$SCRIPT_GET_PROJECTS_GITHUB";
elif [ "$PARAM_VCS" = "gitlab" ]; then eval "$SCRIPT_GET_PROJECTS_GITLAB";
fi


#### Populating the report JSON file with names and slugs of all identified projects for the organization.
while read PROJECT
  do
    PROJECT_NAME="$(echo $PROJECT | cut -d ';' -f1)"
    PROJECT_SLUG="$(echo $PROJECT | cut -d ';' -f2)"
    
    echo "$(jq --arg PROJECT_NAME "$PROJECT_NAME" --arg PROJECT_SLUG "$PROJECT_SLUG" '.projects += [{"'"name"'" : "'"$PROJECT_NAME"'"}] | (.projects[] | select(.name == "'"$PROJECT_NAME"'")) += {"slug" : "'"$PROJECT_SLUG"'"}' all-projects-report.json)" > all-projects-report.json
done < projects-array-like-list.txt

echo 'export VCS_SLUG="$VCS_SLUG"' >> "$BASH_ENV"
echo 'export ORG_SLUG="$ORG_SLUG"' >> "$BASH_ENV"