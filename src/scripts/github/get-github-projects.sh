#!/bin/bash

#### The scripts for GitHub and Bitbucket are identical. The reason they are duplicated is to facilitate maintenance.
#### If there are future changes in the GitHub integration that are not implemented in the Bitbucket one (or vice-versa),
#### it'll be easier to modify only one script to update the orb.

REPOS_PAGE=1
echo -e "Fetching repositories - Page #$REPOS_PAGE\n" | tee -a fetch-projects.log

#### The response from the below endpoint will also include 'archived' repos.
curl -s -G "https://circleci.com/api/v1.1/user/repos/$PARAM_VCS?page=$REPOS_PAGE&per-page=100" -H "Circle-Token: ${!PARAM_CIRCLE_TOKEN}" > repos-list-page-"$REPOS_PAGE".json
jq -r --arg PARAM_ORG_NAME "$PARAM_ORG_NAME" '.[]|select(.owner.login == $PARAM_ORG_NAME)|.name' repos-list-page-"$REPOS_PAGE".json > repos-list.txt


if [[ $(jq 'length' repos-list-page-$REPOS_PAGE.json) -eq 100 ]]; then
  while [[ $(jq 'length' repos-list-page-$REPOS_PAGE.json) -eq 100 ]]
    do
    ((REPOS_PAGE++))
    echo -e "Fetching repositories - Page #$REPOS_PAGE\n" | tee -a fetch-projects.log
    curl -s -G "https://circleci.com/api/v1.1/user/repos/$PARAM_VCS?page=$REPOS_PAGE&per-page=100" -H "Circle-Token: ${!PARAM_CIRCLE_TOKEN}" > repos-list-page-"$REPOS_PAGE".json
    jq -r --arg PARAM_ORG_NAME "$PARAM_ORG_NAME" '.[]|select(.owner.login == $PARAM_ORG_NAME)|.name' repos-list-page-"$REPOS_PAGE".json >> repos-list.txt
  done
fi

#### Identifying which of the retrieved repos are or ever were a CircleCI project.
#### If CircleCI has no knowledge of any branch in a repo, then it isn't and has never been a CircleCI project.
while read -r REPO_NAME
  do
    echo -e "Checking if '$REPO_NAME' is or ever was a CircleCI project...\n" | tee -a fetch-projects.log
    echo "$ORG_SLUG"
    curl -s -G "https://circleci.com/api/v1.1/project/$ORG_SLUG/$REPO_NAME/settings" -H "Circle-Token: ${!PARAM_CIRCLE_TOKEN}" > project-settings-API-response.json
    if [[ $(jq '.branches|length' project-settings-API-response.json) -gt 0 ]]; then
      echo -e "'$REPO_NAME' is a current or past CircleCI project under the '$PARAM_ORG_NAME' organization. \n"  | tee -a fetch-projects.log

      #### These files will be used to search Additional SSH keys and integrations-related settings later in the script.
      cat project-settings-API-response.json > project-settings-API-response-"$REPO_NAME".json
      #### Keeping them so we don't make the same API call again for each project.

      #### This file will be used in all 'search' scripts.
      echo "$REPO_NAME;$ORG_SLUG/$REPO_NAME" >> projects-array-like-list.txt
      #### Keeping it for the entire duration of the job.
    else
      echo -e "'$REPO_NAME' has never been a CircleCI project under the '$PARAM_ORG_NAME' organization. \n"  | tee -a fetch-projects.log
    fi
done < repos-list.txt

#### Clean-up
rm -f repos-list.txt
rm -f repos-list-page-*.json