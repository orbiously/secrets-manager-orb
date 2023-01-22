#!/bin/bash

# #### These scripts will produce a 'projects-array-like-list.txt' file.
# #### Each line of the file is a project's name and its slug, separated by a ';' (semi-colon).
# if [[ "$PARAM_VCS" = "bitbucket" ]]; then eval "$SCRIPT_GET_PROJECTS_BITBUCKET";
# elif [[ "$PARAM_VCS" = "github" ]]; then eval "$SCRIPT_GET_PROJECTS_GITHUB";
# elif [[ "$PARAM_VCS" = "gitlab" ]]; then eval "$SCRIPT_GET_PROJECTS_GITLAB";
# fi

PROJECTS_PAGE=1
echo "Fetching organization projects... | tee -a fetch-projects.log

curl -s -G "https://circleci.com/api/private/project?organization-id=$ORG_ID" -H "Circle-Token: ${!PARAM_CIRCLE_TOKEN}" > projects-list-page-"$PROJECTS_PAGE".json

PAGE_TOKEN=$(jq -r '.next_page_token' projects-list-page-$PROJECTS_PAGE.json)

if [[ $(jq '.items|length' projects-list-page-$PROJECTS_PAGE.json) -gt 0 ]]; then
    echo -e "Found $(jq '.items|length' projects-list-page-$PROJECTS_PAGE.json) project(s) on page #$PROJECTS_PAGE." | tee -a fetch-projects.log
    jq -r '.items[]|.name +";" +.slug' projects-list-page-$PROJECTS_PAGE.json >> potential-projects-array-like-list.txt
else
    echo -e "Organization '${PARAM_ORG_NAME}' doesn't have any projects in CircleCI \n\n" | tee -a fetch-projects.log
fi

if [[ "$PAGE_TOKEN" != "null" ]]; then
    while [[ "$PAGE_TOKEN" != "null" ]]
      do
        ((PROJECTS_PAGE++))
        echo "Fetching organization projects..." | tee -a fetch-projects.log
        curl -s -G "https://circleci.com/api/private/project?organization-id=$ORG_ID&page-token=$PAGE_TOKEN" -H "circle-token: ${!PARAM_CIRCLE_TOKEN}" > projects-list-page-"$PROJECTS_PAGE".json
        echo -e "Found $(jq '.items|length' projects-list-page-"$PROJECTS_PAGE".json) project(s) on page #$PROJECTS_PAGE." | tee -a fetch-projects.log
        jq -r '.items[]|.name +";" +.slug' projects-list-page-"$PROJECTS_PAGE".json >> potential-projects-array-like-list.txt
        PAGE_TOKEN=$(jq -r '.next_page_token' projects-list-page-"$PROJECTS_PAGE".json)
    done
fi

#### Filtering out GitHub and Bitbucket repos that are not and never were CircleCI projects.
if [[ -s potential-projects-array-like-list.txt ]]; then
  while read -r PROJECT
    do
      PROJECT_NAME="$(echo "$PROJECT" | cut -d ';' -f1)"
      PROJECT_SLUG="$(echo "$PROJECT" | cut -d ';' -f2)"

      #### This is only necessary for the case of GitLab organizations, where the value of PROJECT_NAME can contain spaces.
      #### Using the same approach for all VCS allows us to have unique 'search' scripts, rather than distinct VCS-specific ones.
      PROJECT_FILENAME="$(echo "$PROJECT_NAME" | sed -r 's/ +/-spaces-/')"
      ###########################################################################################################################

      curl -s -G "https://circleci.com/api/v1.1/project/$PROJECT_SLUG/settings" -H "circle-token: ${!PARAM_CIRCLE_TOKEN}" > project-settings-API-response.json
      #### Saving response of this API call to use in later search for additional SSH keys and third-party integrations secrets.
      cp project-settings-API-response.json project-settings-"$PROJECT_FILENAME".json

      
      if [[ "$PARAM_VCS" == "github" || "$PARAM_VCS" == "bitbucket" ]] then
        if [[ $(jq '.branches|length' project-settings-API-response.json) -gt 0 ]]; then
          echo $PROJECT >> projects-array-like-list.txt
        fi
      else
        #### For GitLab organizations the '/private/project?organization-id=***' only returns projects that were explicitly set up in CircleCI.
        #### So there is no need to filter out.
        cp potential-projects-array-like-list.txt projects-array-like-list.txt
      fi        
  done < potential-projects-array-like-list.txt
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
  echo "$(jq '.projects = null' all-projects-report.json)" > all-projects-report.json
fi

#### Clean-up
rm -f projects-list-page-*.json
rm -f potential-projects-array-like-list.txt