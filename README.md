# Bob Status

Send Jenkins build status to Github Api

## Solution

Scraping starts from Feature branch view, so only feature branches are affected

For installation add it to crontab
Set environment variables: `GITHUB_ACCESS_TOKEN` and `JENKINS_ACCESS_TOKEN`
My setup sets them up directly in crontab file

For a moment works only for my commits

For logging setup cron to `ruby status.rb >> cron.log`

