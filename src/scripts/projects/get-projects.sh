#!/bin/bash

# #### These scripts will produce a 'projects-array-like-list.txt' file.
# #### Each line of the file is a project's name and its slug, separated by a ';' (semi-colon).
# if [[ "$PARAM_VCS" = "bitbucket" ]]; then eval "$SCRIPT_GET_PROJECTS_BITBUCKET";
# elif [[ "$PARAM_VCS" = "github" ]]; then eval "$SCRIPT_GET_PROJECTS_GITHUB";
# elif [[ "$PARAM_VCS" = "gitlab" ]]; then eval "$SCRIPT_GET_PROJECTS_GITLAB";
# fi

PROJECTS_PAGE=1
echo "Fetching organization projects - Page #$PROJECTS_PAGE" | tee -a fetch-projects.log

curl -s -G "https://circleci.com/api/private/project?organization-id=$ORG_ID" -H "Circle-Token: ${!PARAM_CIRCLE_TOKEN}" > projects-list-page-"$PROJECTS_PAGE".json

PAGE_TOKEN=$(jq -r '.next_page_token' projects-list-page-$PROJECTS_PAGE.json)

if [[ $(jq '.items|length' projects-list-page-$PROJECTS_PAGE.json) -gt 0 ]]; then
    echo -e "Found $(jq '.items|length' projects-list-page-$PROJECTS_PAGE.json) project(s) on page #$PROJECTS_PAGE." | tee -a fetch-projects.log
    jq -r '.items[]|.name +";" +.slug' projects-list-page-$PROJECTS_PAGE.json >> projects-array-like-list.txt
else
    echo -e "Organization '${PARAM_ORG_NAME}' doesn't have any projects in CircleCI \n\n" | tee -a fetch-projects.log
fi

if [[ "$PAGE_TOKEN" != "null" ]]; then
    while [[ "$PAGE_TOKEN" != "null" ]]
      do
        ((PROJECTS_PAGE++))
        echo "Fetching organization projects - Page #$PROJECTS_PAGE" | tee -a fetch-projects.log
        curl -s -G "https://circleci.com/api/private/project?organization-id=$ORG_ID&page-token=$PAGE_TOKEN" -H "circle-token: ${!PARAM_CIRCLE_TOKEN}" > projects-list-page-"$PROJECTS_PAGE".json
        echo -e "Found $(jq '.items|length' projects-list-page-"$PROJECTS_PAGE".json) project(s) on page #$PROJECTS_PAGE." | tee -a fetch-projects.log
        jq -r '.items[]|.name +";" +.slug' projects-list-page-"$PROJECTS_PAGE".json >> projects-array-like-list.txt
        PAGE_TOKEN=$(jq -r '.next_page_token' projects-list-page-"$PROJECTS_PAGE".json)
    done
fi


echo '{"projects": []}' > all-projects-report.json


if [[ -s projects-array-like-list.txt ]]; then
  #### Populating the report JSON file with names and slugs of all identified projects for the organization.
  while read -r PROJECT
    do
      PROJECT_NAME="$(echo "$PROJECT" | cut -d ';' -f1)"
      PROJECT_SLUG="$(echo "$PROJECT" | cut -d ';' -f2)"
      #### The below 'echo' triggers the 'SC2005' ShellCheck error but it's the only way I found to use the same file as both input and output of the `jq` command.
      echo "$(jq --arg PROJECT_NAME "$PROJECT_NAME" --arg PROJECT_SLUG "$PROJECT_SLUG" '.projects += [{"'"name"'" : "'"$PROJECT_NAME"'"}] | (.projects[] | select(.name == "'"$PROJECT_NAME"'")) += {"slug" : "'"$PROJECT_SLUG"'"}' all-projects-report.json)" > all-projects-report.json
  done < projects-array-like-list.txt
else
  echo -e "No projects found for organization '$PARAM_ORG_NAME'."
fi

#### Clean-up
rm -f projects-list-page-*.json