#!/bin/bash

echo -e "\n\n######################## SEARCHING FOR PROJECTS ENVIRONMENT VARIABLES ######################## \n" | tee -a projects-env-vars.log

while read PROJECT
  do
    PROJECT_NAME="$(echo $PROJECT | cut -d ';' -f1)"
    PROJECT_SLUG="$(echo $PROJECT | cut -d ';' -f2)"

    #### This is only necessary for the case of GitLab organizations, where the value of PROJECT_NAME can contain spaces.
    #### Using the same approach for all VCS allows us to have unique 'search' scripts, rather than distinct VCS-specific ones.
    PROJECT_FILENAME="$(echo $PROJECT_NAME | sed -r 's/ +/-spaces-/')"
    ###########################################################################################################################

    ENV_VARS_PAGE=1
    
    curl -s -G "https://circleci.com/api/v2/project/$PROJECT_SLUG/envvar" -H "circle-token: $CIRCLECI_API_TOKEN" > project-env-vars-API-response.json

    PAGE_TOKEN=$(jq -r '.next_page_token' project-env-vars-API-response.json)

    if [[ $(jq '.items|length' project-env-vars-API-response.json) -gt 0 ]]; then
      jq '.items' project-env-vars-API-response.json  >> project-env-vars-$PROJECT_FILENAME.json
    else
      printf "Project \'%s\' doesn't have any stored environment variables \n\n" "$PROJECT_NAME" | tee -a projects-env-vars.log
      echo "$(jq --arg PROJECT "$PROJECT_NAME" '(.projects[] | select(.name == "'"$PROJECT_NAME"'")) .envvars |= .' all-projects-report.json)" > all-projects-report.json
      continue
    fi

    if [[ "$PAGE_TOKEN" != "null" ]]; then
      while [[ "$PAGE_TOKEN" != "null" ]]
      do
        ((ENV_VARS_PAGE++))
        curl -s -G "https://circleci.com/api/v2/project/$PROJECT_SLUG/envvar&page-token=$PAGE_TOKEN" -H "circle-token: $CIRCLECI_API_TOKEN" > project-env-vars-API-response.json
        jq '.items' project-env-vars-API-response.json  >> project-env-vars-$PROJECT_FILENAME.json
        PAGE_TOKEN=$(jq -r '.next_page_token' project-env-vars-API-response.json)
      done
    fi

    echo "$(jq --arg PROJECT "$PROJECT_NAME" --arg PROJECT_SLUG "$PROJECT_SLUG" '(.projects[] | select(.name == "'"$PROJECT_NAME"'") | .envvars) |= . + input' all-projects-report.json project-env-vars-$PROJECT_FILENAME.json)" > all-projects-report.json

    echo -e "Project \'$PROJECT_NAME\' has $(jq -s length project-env-vars-$PROJECT_FILENAME.json) environment variables --> https://app.circleci.com/settings/project/$PROJECT_SLUG/environment-variables \n" | tee -a projects-env-vars.log
done < projects-array-like-list.txt