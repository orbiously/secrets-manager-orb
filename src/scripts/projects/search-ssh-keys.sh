#!/bin/bash

echo -e "\n\n######################## SEARCHING FOR SSH KEYS ########################\n" | tee -a projects-ssh-keys.log

while read PROJECT
#### Search for Checkout SSH keys
  do
    PROJECT_NAME="$(echo $PROJECT | cut -d ';' -f1)"
    PROJECT_SLUG="$(echo $PROJECT | cut -d ';' -f2)"

    #### This is only necessary for the case of GitLab organizations, where the value of PROJECT_NAME can contain spaces.
    #### Using the same approach for all VCS allows us to have unique 'search' scripts, rather than distinct VCS-specific ones.
    PROJECT_FILENAME="$(echo $PROJECT_NAME | sed -r 's/ +/-spaces-/')"
    ###########################################################################################################################

    curl -s -G "https://circleci.com/api/v2/project/$PROJECT_SLUG/checkout-key" -H "circle-token: $CIRCLECI_API_TOKEN" > project-checkout-keys-API-response.json
      if [ $(jq '.items|length' project-checkout-keys-API-response.json) -gt 0 ]; then
        jq '.items' project-checkout-keys-API-response.json > checkout-keys-$PROJECT_FILENAME.json
        echo "$(jq --arg PROJECT "$PROJECT" '(.projects[] | select(.name == "'"$PROJECT"'") | .checkout_keys) |= . + input' all-projects-report.json checkout-keys-$PROJECT_FILENAME.json)" > all-projects-report.json
        echo -e "Project $PROJECT has $(jq '.|length' checkout-keys-$PROJECT.json) Checkout SSH keys --> https://app.circleci.com/settings/project/$PROJECT_SLUG/ssh \n" | tee -a projects-ssh-keys.log
      else
        printf "There are no Checkout SSH keys in project '%s' \n\n" "$PROJECT"
        echo "$(jq --arg PROJECT "$PROJECT" '(.projects[] | select(.name == "'"$PROJECT"'")) .checkout_keys |= .' all-projects-report.json)" > all-projects-report.json
      fi
#### Search for Additional SSH keys
    # Using the JSON file generated when fetching the list of projects
      if [ $(jq '.ssh_keys | length' project-settings-API-response-$PROJECT_FILENAME.json) -gt 0 ]; then
        jq '.ssh_keys' project-settings-API-response-$PROJECT_FILENAME.json > extra-ssh-and-integrations-$PROJECT_FILENAME.json
        echo "$(jq --arg PROJECT "$PROJECT" '(.projects[] | select(.name == "'"$PROJECT"'") | .additional_ssh) |= . + input' all-projects-report.json extra-ssh-and-integrations-$PROJECT_FILENAME.json)" > all-projects-report.json
        echo -e "Project $PROJECT has $(jq '. | length' extra-ssh-and-integrations-$PROJECT_FILENAME.json) Additional SSH keys --> https://app.circleci.com/settings/project/$PROJECT_SLUG/ssh \n" | tee -a projects-ssh-keys.log
      else
        printf "There are no Additional SSH keys in project '%s' \n\n" "$PROJECT"
        echo "$(jq --arg PROJECT "$PROJECT" '(.projects[] | select(.name == "'"$PROJECT"'")) .additional_ssh |= .' all-projects-report.json)" > all-projects-report.json
      fi      
done < projects-array-like-list.txt

#### Clean-up
rm -f checkout-keys-*.json
rm -f extra-ssh-and-integrations-$PROJECT_FILENAME.json

#### Temporarily deleting these files in the clean-up.
#### Will remove this last command when implementing search for secrets in Jira and legacy integrations.
rm -f project-settings-API-response-$PROJECT_FILENAME.json