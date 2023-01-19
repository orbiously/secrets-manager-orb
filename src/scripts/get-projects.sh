#!/bin/bash

echo '{"projects": []}' > all-projects-report.json

#### These scripts will produce a 'projects-array-like-list.txt' file.
#### Each line of the file is a project's name and its slug, separated by a ';' (semi-colon).
if [[ "$PARAM_VCS" = "bitbucket" ]]; then eval "$SCRIPT_GET_PROJECTS_BITBUCKET";
elif [[ "$PARAM_VCS" = "github" ]]; then eval "$SCRIPT_GET_PROJECTS_GITHUB";
elif [[ "$PARAM_VCS" = "gitlab" ]]; then eval "$SCRIPT_GET_PROJECTS_GITLAB";
fi

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
fi

