#!/bin/bash

echo -e "\n\n######################## SEARCHING FOR PROJECTS API TOKENS ######################## \n" | tee -a projects-api-tokenss.log

while read PROJECT
  do 
    PROJECT_NAME="$(echo $PROJECT | cut -d ';' -f1)"
    PROJECT_SLUG="$(echo $PROJECT | cut -d ';' -f2)"

    #### This is only necessary for the case of GitLab organizations, where the value of PROJECT_NAME can contain spaces.
    #### Using the same approach for all VCS allows us to have unique 'search' scripts, rather than distinct VCS-specific ones.
    PROJECT_FILENAME="$(echo $PROJECT_NAME | sed -r 's/ +/-spaces-/')"
    ###########################################################################################################################

    curl -s -G "https://circleci.com/api/v1.1/project/$PROJECT_SLUG/token" -H "circle-token: $CIRCLE_TOKEN" > project-tokens-$PROJECT_FILENAME.json
      if [ $(jq '.|length' project-tokens-$PROJECT_FILENAME.json) -gt 0 ]; then
        echo "$(jq --arg PROJECT "$PROJECT" '(.projects[] | select(.name == "'"$PROJECT"'") | .project_api_tokens) |= . + input' all-projects-report.json project-tokens-$PROJECT_FILENAME.json)" > all-projects-report.json
        echo -e "Project $PROJECT has $(jq '.|length' project-tokens-$PROJECT_FILENAME.json) project tokens --> https://app.circleci.com/settings/project/$PROJECT_SLUG/api \n" | tee -a projects-api-tokens.log
      else
        printf "There are no Project API tokens in project '%s' \n\n" "$PROJECT" | tee -a projects-api-tokens.log
        echo "$(jq --arg PROJECT "$PROJECT" '(.projects[] | select(.name == "'"$PROJECT"'")) .project_api_tokens |= .' all-projects-report.json)" > all-projects-report.json
      fi
done < projects-array-like-list.txt

#### Clean up
rm -f project-tokens-*.json