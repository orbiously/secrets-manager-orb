#!/bin/bash

if [ -s projects-array-like-list.txt ]; then

  echo -e "\n\n######################## SEARCHING FOR PROJECTS ENVIRONMENT VARIABLES ######################## \n" | tee -a projects-env-vars.log

  while read -r PROJECT
    do
      PROJECT_NAME="$(echo "$PROJECT" | cut -d ';' -f1)"
      PROJECT_SLUG="$(echo "$PROJECT" | cut -d ';' -f2)"

      #### This is only necessary for the case of GitLab organizations, where the value of PROJECT_NAME can contain spaces.
      #### Using the same approach for all VCS allows us to have unique 'search' scripts, rather than distinct VCS-specific ones.
      PROJECT_FILENAME="$(echo "$PROJECT_NAME" | sed -r 's/ +/-spaces-/')"
      ###########################################################################################################################

      ENV_VARS_PAGE=1
      
      curl -s -G "https://circleci.com/api/v2/project/$PROJECT_SLUG/envvar" -H "circle-token: $CIRCLE_TOKEN" > project-env-vars-API-response.json

      PAGE_TOKEN=$(jq -r '.next_page_token' project-env-vars-API-response.json)

      if [[ $(jq '.items|length' project-env-vars-API-response.json) -gt 0 ]]; then
        jq '.items' project-env-vars-API-response.json  > project-env-vars-"$PROJECT_FILENAME".json
      else
        echo -e "Project '$PROJECT_NAME' doesn't have any stored environment variables." | tee -a projects-env-vars.log
        echo -e "View in the CircleCI UI --> https://app.circleci.com/settings/project/$PROJECT_SLUG/environment-variables \n\n" | tee -a projects-env-vars.log
        #### The below 'echo' triggers the 'SC2005' ShellCheck error but it's the only way I found to use the same file as both input and output of the `jq` command.
        echo "$(jq --arg PROJECT_NAME "$PROJECT_NAME" '(.projects[] | select(.name == "'"$PROJECT_NAME"'")) .envvars |= .' all-projects-report.json)" > all-projects-report.json
        continue
      fi

      if [[ "$PAGE_TOKEN" != "null" ]]; then
        while [[ "$PAGE_TOKEN" != "null" ]]
        do
          ((ENV_VARS_PAGE++))
          curl -s -G "https://circleci.com/api/v2/project/$PROJECT_SLUG/envvar&page-token=$PAGE_TOKEN" -H "circle-token: $CIRCLE_TOKEN" > project-env-vars-API-response.json
          #### The below 'echo' triggers the 'SC2005' ShellCheck error but it's the only way I found to use the same file as both input and output of the `jq` command.
          echo "$(jq '. + input' project-env-vars-"$PROJECT_FILENAME".json project-env-vars-API-response.json)" > project-env-vars-"$PROJECT_FILENAME".json
          PAGE_TOKEN=$(jq -r '.next_page_token' project-env-vars-API-response.json)
        done
      fi

      #### The below 'echo' triggers the 'SC2005' ShellCheck error but it's the only way I found to use the same file as both input and output of the `jq` command.
      echo "$(jq --arg PROJECT_NAME "$PROJECT_NAME" '(.projects[] | select(.name == "'"$PROJECT_NAME"'")) .envvars |= . + input' all-projects-report.json project-env-vars-"$PROJECT_FILENAME".json)" > all-projects-report.json

      echo -e "Project '$PROJECT_NAME' has $(jq 'length' project-env-vars-"$PROJECT_FILENAME".json) environment variable(s)." | tee -a projects-env-vars.log
      echo -e "View in the CircleCI UI --> https://app.circleci.com/settings/project/$PROJECT_SLUG/environment-variables \n\n" | tee -a projects-env-vars.log
  done < projects-array-like-list.txt

else
  echo "No projects to search in." | tee -a projects-env-vars.log
fi

#Clean-up
rm -f project-env-vars-API-response.json
rm -f project-env-vars-*.json