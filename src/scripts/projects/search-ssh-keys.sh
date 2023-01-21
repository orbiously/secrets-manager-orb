#!/bin/bash

if [ -s projects-array-like-list.txt ]; then

  echo -e "\n\n######################## SEARCHING FOR SSH KEYS ########################\n" | tee -a projects-ssh-keys.log

  while read -r PROJECT
  #### Search for Checkout SSH keys
    do
      PROJECT_NAME="$(echo "$PROJECT" | cut -d ';' -f1)"
      PROJECT_SLUG="$(echo "$PROJECT" | cut -d ';' -f2)"

      #### This is only necessary for the case of GitLab organizations, where the value of PROJECT_NAME can contain spaces.
      #### Using the same approach for all VCS allows us to have unique 'search' scripts, rather than distinct VCS-specific ones.
      PROJECT_FILENAME="$(echo "$PROJECT_NAME" | sed -r 's/ +/-spaces-/')"
      ###########################################################################################################################

      curl -s -G "https://circleci.com/api/v2/project/$PROJECT_SLUG/checkout-key" -H "circle-token: $CIRCLE_TOKEN" > project-checkout-keys-API-response.json
        if [[ $(jq '.items|length' project-checkout-keys-API-response.json) -gt 0 ]]; then
          jq '.items' project-checkout-keys-API-response.json > checkout-keys-"$PROJECT_FILENAME".json
          #### The below 'echo' triggers the 'SC2005' ShellCheck error but it's the only way I found to use the same file as both input and output of the `jq` command.
          echo "$(jq --arg PROJECT_NAME "$PROJECT_NAME" '(.projects[] | select(.name == "'"$PROJECT_NAME"'")) .checkout_keys |= . + input' all-projects-report.json checkout-keys-"$PROJECT_FILENAME".json)" > all-projects-report.json
          echo -e "Project '$PROJECT_NAME' has $(jq '.|length' checkout-keys-"$PROJECT_FILENAME".json) Checkout SSH key(s)" | tee -a projects-ssh-keys.log
        else
          echo -e "There are no Checkout SSH keys in project '$PROJECT_NAME'."
          #### The below 'echo' triggers the 'SC2005' ShellCheck error but it's the only way I found to use the same file as both input and output of the `jq` command.
          echo "$(jq --arg PROJECT "$PROJECT_NAME" '(.projects[] | select(.name == "'"$PROJECT_NAME"'")) .checkout_keys |= .' all-projects-report.json)" > all-projects-report.json
        fi
  #### Search for Additional SSH keys
        curl -s -G "https://circleci.com/api/v1.1/project/$PROJECT_SLUG/settings" -H "circle-token: ${!PARAM_CIRCLE_TOKEN}" > project-settings-API-response.json
        if [[ $(jq '.ssh_keys | length' project-settings-API-response.json) -gt 0 ]]; then
          #### Saving response of this API call to use in later search for third-party integrations secxrets.
          cp project-settings-API-response.json project-settings-"$PROJECT_FILENAME".json
          jq '.ssh_keys' project-settings-API-response.json > extra-ssh-"$PROJECT_FILENAME".json
          #### The below 'echo' triggers the 'SC2005' ShellCheck error but it's the only way I found to use the same file as both input and output of the `jq` command.
          echo "$(jq --arg PROJECT_NAME "$PROJECT_NAME" '(.projects[] | select(.name == "'"$PROJECT_NAME"'")) .additional_ssh |= . + input' all-projects-report.json extra-ssh-"$PROJECT_FILENAME".json)" > all-projects-report.json
          echo -e "Project '$PROJECT_NAME' has $(jq '. | length' extra-ssh-"$PROJECT_FILENAME".json) Additional SSH key(s)." | tee -a projects-ssh-keys.log
        else
          echo -e "There are no Additional SSH keys in project '$PROJECT_NAME'."  | tee -a projects-ssh-keys.log
          #### The below 'echo' triggers the 'SC2005' ShellCheck error but it's the only way I found to use the same file as both input and output of the `jq` command.
          echo "$(jq --arg PROJECT "$PROJECT_NAME" '(.projects[] | select(.name == "'"$PROJECT_NAME"'")) .additional_ssh |= .' all-projects-report.json)" > all-projects-report.json
        fi

        echo -e "View in the CircleCI UI --> https://app.circleci.com/settings/project/$PROJECT_SLUG/ssh \n\n" | tee -a projects-ssh-keys.log
  done < projects-array-like-list.txt

  #### Clean-up
  rm -f project-settings-API-response.json
  rm -f checkout-keys-*.json
  rm -f extra-ssh-*.json

else
  echo "No projects to search in." | tee -a projects-env-vars.log
fi  