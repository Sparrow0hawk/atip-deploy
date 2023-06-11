# Deploy ATIP Cloud Build and Terraform

## Cloud Build Trigger with GitHub Service Agent

Based on steps here -
https://cloud.google.com/build/docs/automating-builds/github/connect-repo-github#connecting_a_github_host_programmatically

PAT Token secret is managed locally as a file that is loaded by Terraform (would
be nicer to use a keyvault).
