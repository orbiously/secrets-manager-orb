#!/bin/bash

echo -e "\n\n######################## SEARCHING FOR CONTEXTS ENVIRONMENT VARIABLES ######################## \n" | tee -a contexts-env-vars.log

#### Get a list of the organization's contexts
CONTEXTS_PAGE=1
curl -s -G "https://circleci.com/api/v2/context?owner-slug=$ORG_SLUG" -H "circle-token: $CIRCLE_TOKEN" > contexts-API-response.json
jq -r '.items[]|.name +";" +.id' contexts-API-response.json > contexts-array-like-list.txt
PAGE_TOKEN=$(jq -r '.next_page_token' contexts-API-response.json)

if [[ "$PAGE_TOKEN" != "null" ]]; then
  while [[ "$PAGE_TOKEN" != "null" ]]
   do
     ((CONTEXTS_PAGE++))
     curl -s -G "https://circleci.com/api/v2/context?owner-slug=$ORG_SLUG&page-token=$PAGE_TOKEN" -H "circle-token: $CIRCLE_TOKEN" > contexts-API-response.json
     jq -r '.items[]|.name +";" +.id' contexts-API-response.json >> contexts-array-like-list.txt
     PAGE_TOKEN=$(jq -r '.next_page_token' contexts-API-response.json)
  done
fi

echo '{"contexts": []}' > all-contexts-report.json

if [ -s contexts-array-like-list.txt ]; then
  # jq -s '.' <<< $(cat contexts-items-all-objects.json) > contexts-items-all-array.json
  # printf "Found $(jq '.|length' contexts-items-all-array.json) contexts \n\n"
  echo -e "Found $(cat contexts-array-like-list.txt | wc -l) contexts in $ORG_NAME organization.\n\n" | tee -a contexts-env-vars.log
  
  #### Populating the report JSON file with names and ids of all identified contexts for the organization.
  while read CONTEXT
    do
      CONTEXT_NAME="$(echo $PROJECT | cut -d ';' -f1)"
      CONTEXT_ID="$(echo $PROJECT | cut -d ';' -f2)"

      echo "$(jq --arg PROJECT_NAME "$CONTEXT_NAME" --arg PROJECT_SLUG "$CONTEXT_ID" '.contexts += [{"'"name"'" : "'"$CONTEXT_NAME"'"}] | (.contexts[] | select(.name == "'"$CONTEXT_NAME"'")) += {"id" : "'"$CONTEXT_ID"'"}' all-contexts-report.json)" > all-contexts-report.json
  done < projects-array-like-list.txt


  #### For each of these contexts, determine if there are environment variables
  # for CONTEXT_ID in $(jq -r '.id' contexts-items-all-objects.json)
  while read CONTEXT
    do
      CONTEXT_NAME="$(echo $PROJECT | cut -d ';' -f1)"
      CONTEXT_ID="$(echo $PROJECT | cut -d ';' -f2)"

      CONTEXT_ENV_VARS_PAGE=1

      curl -s -G "https://circleci.com/api/v2/context/$CONTEXT_ID/environment-variable" -H "circle-token: $CIRCLE_TOKEN" > context-env-vars-API-response.json instead

      PAGE_TOKEN=$(jq -r '.next_page_token' context-env-vars-API-response.json instead)

      if [ $(jq '.items|length' context-env-vars-API-response.json instead) -gt 0 ]; then
        jq '.items' context-env-vars-API-response.json  > context-$CONTEXT_ID-env-vars.json
      else
        echo "Context \'$CONTEXT_NAME\' doesn't have any stored environment variables." | tee -a projects-env-vars.log
        echo -e "View in the CircleCI UI --> https://app.circleci.com/settings/organization/$ORG_SLUG/contexts/$CONTEXT_ID.\n\n" | tee -a projects-env-vars.log
        echo "$(jq --arg CONTEXT_ID "$CONTEXT_ID" '(.contexts[] | select(.id == "'"$CONTEXT_ID"'")) .envvars |= .' all-contexts-report.json)" > all-contexts-report.json
        continue
      fi

      if [[ "$PAGE_TOKEN" != "null" ]]; then
        while [[ "$PAGE_TOKEN" != "null" ]]
          do
            ((CONTEXT_ENV_VARS_PAGE++))
            curl -s -G "https://circleci.com/api/v2/context/$CONTEXT_ID/environment-variable?page=$PAGE_TOKEN" -H "circle-token: $CIRCLE_TOKEN" > context-env-vars-API-response.json
            echo "$(jq '. + input' context-$CONTEXT_ID-env-vars.json context-env-vars-API-response.json)" > context-$CONTEXT_ID-env-vars.json
        done

      echo "$(jq --arg CONTEXT_ID "$CONTEXT_ID" '(.contexts[] | select(.id == "'"$CONTEXT_ID"'") | .envvars) |= . + input' all-contexts-report.json context-$CONTEXT_ID-env-vars.json)" > all-contexts-report.json

      echo "Context \'$CONTEXT_NAME\' has $(jq 'length' context-$CONTEXT_ID-env-vars.json) environment variable(s)"
      echo -e "View in the CircleCI UI --> https://app.circleci.com/settings/organization/$ORG_SLUG/contexts/$CONTEXT_ID.\n\n" | tee -a contexts-env-vars.log 

  done < contexts-array-like-list.txt
else
  echo "No contexts found for organization \'$ORG_NAME\'\n" | tee -a contexts-env-vars.log
  echo $(jq '. .contexts = null' all-contexts-report.json) > all-contexts-report.json
fi

#### Clean-up
rm -f contexts-API-response.json
rm -f context-*-env-vars.json
rm -f contexts-array-like-list.txt