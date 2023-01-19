#!/bin/bash


#### I haven't yet found out whether or not the response from the below enpoint is paginated (note: for GH and BB, it doesn't appear possible to iterate over pages)
#### So I'm using the '/private' endpoint alternative

# curl -s -G "https://circleci.com/api/v1.1/organization/$ORG_SLUG/settings" -H "Circle-Token: ${!PARAM_CIRCLE_TOKEN}" | jq -r '.projects[].vcs_url'| cut -d "/" -f5 > projects-ids.txt

# while read PROJECT_ID
#   do
#     #### This file will be used in all 'search' scripts.

#     curl -s -G "https://circleci.com/api/v2/project/$PROJECT_ID" -H "Circle-Token: ${!PARAM_CIRCLE_TOKEN}" | jq -r '.name + ";" +.slug' >> projects-array-like-list.txt
#     #### Keeping it for the entire duration of the job.
#     PROJECT_NAME=$()
# done < projects-ids.txt

# #### Clean-up
# rm -f projects-ids.txt



########## Using the '/private' endpoint instead ##########

ORG_ID=$(curl -s -G "https://circleci.com/api/v2/me/collaborations" -H "Circle-Token: ${!PARAM_CIRCLE_TOKEN}" | jq -r --arg ORG_NAME "$ORG_NAME" '.[] | select(.name == "'"$ORG_NAME"'") | .id')

PROJECTS_PAGE=1
echo "Fetching organization projects - Page #$PROJECTS_PAGE" | tee -a fetch-projects.log

curl -s -G "https://circleci.com/api/private/project?organization-id=$ORG_ID" -H "Circle-Token: ${!PARAM_CIRCLE_TOKEN}" > projects-list-page-"$PROJECTS_PAGE".json

PAGE_TOKEN=$(jq -r '.next_page_token' projects-page-$PROJECTS_PAGE.json)

if [[ $(jq '.items|length' projects-page-$PROJECTS_PAGE.json) -gt 0 ]]; then
    echo -e "Found $(jq '.items|length' projects-page-$PROJECTS_PAGE.json) project(s)\n\n" | tee -a fetch-projects.log
    jq -r '.items[]|.name +";" +.slug' projects-page-$PROJECTS_PAGE.json >> projects-array-like-list.txt
else
    printf "Organization '%s' doesn't have any projects in CircleCI \n\n" "$ORG_NAME" | tee -a fetch-projects.log
fi

if [[ "$PAGE_TOKEN" != "null" ]]; then
    while [[ "$PAGE_TOKEN" != "null" ]]
      do
        ((PROJECTS_PAGE++))
        echo "Fetching organization projects - Page #$PROJECTS_PAGE" | tee -a fetch-projects.log
        curl -s -G "https://circleci.com/api/private/project?organization-id=$ORG_ID&page-token=$PAGE_TOKEN" -H "circle-token: ${!PARAM_CIRCLE_TOKEN}" > projects-list-page-"$PROJECTS_PAGE".json
        echo -e "Found $(jq '.items|length' projects-page-"$PROJECTS_PAGE".json) project(s)\n\n" | tee -a fetch-projects.log
        jq -r '.items[]|.name +";" +.slug' projects-page-"$PROJECTS_PAGE".json >> projects-array-like-list.txt
        PAGE_TOKEN=$(jq -r '.next_page_token' project-env-vars-API-response.json)
    done
fi

#### Clean-up
rm -f projects-list-page-*.json