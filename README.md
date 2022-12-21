# Update.sh 

Update.sh is a shell script that will auto-update applications that don't have that feature built-in.
It works by checking GitHub for the latest release and comparing that to the locally installed version number.

## Requirements

This script requires curl, jq, and wget. It also looks for an environment variable named GHPT, or GitHub Personal Token. This should be a read-only key to increase GitHub's API limits.

You should be able to navigate around this requirement by removing the 

``` -H "Authorization: Bearer $GHPT"\ ```

line from the curl_cmd function.

In addition, you'll need to replace the apps with your own and update the urls accordingly.

## Installation

Download the update-apps.sh file.

## License

[MIT](https://choosealicense.com/licenses/mit/)
