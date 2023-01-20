#!/bin/bash

if [ -s projects-array-like-list.txt ]; then

  echo -e "\n\n######################## SEARCHING FOR PROJECTS API TOKENS ######################## \n" | tee -a projects-api-tokens.log

  while read -r PROJECT
    do 
      PROJECT_NAME="$(echo "$PROJECT" | cut -d ';' -f1)"
      PROJECT_SLUG="$(echo "$PROJECT" | cut -d ';' -f2)"

      #### This is only necessary for the case of GitLab organizations, where the value of PROJECT_NAME can contain spaces.
      #### Using the same approach for all VCS allows us to have unique 'search' scripts, rather than distinct VCS-specific ones.
      PROJECT_FILENAME="$(echo "$PROJECT_NAME" | sed -r 's/ +/-spaces-/')"
      ###########################################################################################################################

      curl -s -G "https://circleci.com/api/v1.1/project/$PROJECT_SLUG/token" -H "circle-token: $CIRCLE_TOKEN" > project-tokens-"$PROJECT_FILENAME".json
        if [[ $(jq '.|length' project-tokens-"$PROJECT_FILENAME".json) -gt 0 ]]; then
          #### The below 'echo' triggers the 'SC2005' ShellCheck error but it's the only way I found to use the same file as both input and output of the `jq` command.
          echo "$(jq --arg PROJECT_NAME "$PROJECT_NAME" '(.projects[] | select(.name == "'"$PROJECT_NAME"'")) .project_api_tokens |= . + input' all-projects-report.json project-tokens-"$PROJECT_FILENAME".json)" > all-projects-report.json
          echo -e "Project $PROJECT_NAME has $(jq '.|length' project-tokens-"$PROJECT_FILENAME".json) project tokens --> https://app.circleci.com/settings/project/$PROJECT_SLUG/api \n" | tee -a projects-api-tokens.log
        else
          echo -e "There are no Project API tokens in project '$PROJECT_NAME' \n\n" | tee -a projects-api-tokens.log
          #### The below 'echo' triggers the 'SC2005' ShellCheck error but it's the only way I found to use the same file as both input and output of the `jq` command.
          echo "$(jq --arg PROJECT_NAME "$PROJECT_NAME" '(.projects[] | select(.name == "'"$PROJECT_NAME"'")) .project_api_tokens |= .' all-projects-report.json)" > all-projects-report.json
        fi
  done < projects-array-like-list.txt

  #### Clean up
  rm -f project-tokens-*.json

else
  echo "No projects to search in." | tee -a projects-env-vars.log
fi  