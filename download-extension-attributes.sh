#!/bin/bash

## Script name:		download-extension-attributes.sh
## Author:		Mike Morales (@mm2270 on JAMFNation)
##			https://jamfnation.jamfsoftware.com/viewProfile.html?userID=1927
## Last change:		2014-05-14

## Description:		Script to download all Extension Attribute scripts from a
##			Casper Suite version 9.x JSS. For more detailed information,
##			run the script in Terminal with the -h flag

## The following section contains the only variables that should be manually edited in
## the script. They can also be assigned to the script as Casper Suite parameters.
## Read the descriptions for more info.

## If you choose to hardcode API information into the script, set the API Username and
## API Password here. Note: The API account only needs 'read' privileges to pull
## Extension Attribute scripts

apiUser=""		## Set the API Username here if you want it hardcoded
apiPass=""		## Set the API Password here if you want it hardcoded
jssURL=""		## Set the JSS URL here if you want it hardcoded

## Set the script downloads folder path here.
## Default path is within the JAMF directory in "extension_attributes"
scriptDownloadDir="/Library/Application Support/JAMF/extension_attributes"

################################ DO NOT EDIT BELOW THIS LINE ################################

script=$(basename $0)
directory="$( cd "$( dirname "$0" )" && pwd )"

## Help / Usage function
usage ()
{
cat << EOF
SYNOPSIS
	sudo script.sh -a "api_user" -p "api_password" -s "server"
	or
	sudo jamf runScript -script "script.sh" -path "/path/to/" -p1 "api_user" -p2 "api_password" -p3 "server"

COMPATIBILITY:
	Casper Suite version 9.x
	
OPTIONS:
	-h	Show this usage screen
	-a	API account username
	-p	API account password
	-s	JSS Server address [optional]

DESCRIPTION:
	This script can be used to download a copy of all Extension Attribute scripts
	located on the Casper Suite server specified in the server option.
	The Casper Suite server URL is optional. If not specified at run time, the script
	will attempt to obtain the JSS address from the client's settings.
	
	The script can be run in two primary ways.
	1. Calling the script directly on the shell
	
	Example:
	sudo "$0" -a "api_username" -p "api_password" -s "https://jss.server.com:8443"
	
	2. Using the jamf binary
	
	Example:
	sudo jamf runScript -script "$script" -path "$directory" -p1 "api_username" -p2 "api_password" -p3 "https://jss.server.com:8443"
	
	You may also use the script directly in a JSS policy, specifying the API username,
	API password and (optionally) the JSS URL in parameters 4 through 6, respectively.

NOTES:
	It is recommended to enclose the API username, API password and JSS URL in double quotes
	to protect the script against any special characters or spaces in the strings.
		
EOF
exit
}

## Run loop to check for passed args on the command line
while getopts ha:p:s option; do
	case "${option}" in
		a) apiUser=${OPTARG};;
		p) apiPass=${OPTARG};;
		s) jssURL=${OPTARG};;
		h) usage;;
	esac
done

## Check to see if the script was passed any script parameters from Casper
if [[ "$apiUser" == "" ]] && [[ "$4" != "" ]]; then
	apiUser="$4"
fi

if [[ "$apiPass" == "" ]] && [[ "$5" != "" ]]; then
	apiPass="$5"
fi

if [[ "$jssURL" == "" ]] && [[ "$6" != "" ]]; then
	jssURL="$6"
fi

## Finally, make sure we got at least an apiUser & apiPass variable, else we exit
if [[ -z "$apiUser" ]] || [[ -z "$apiPass" ]]; then
	echo "API Username = $apiUser\nAPI Password = $apiPass"
	echo "One of the required variables was not passed to the script. Exiting..."
	exit 1
fi

## If no server address was passed to the script, get it from the Mac's com.jamfsoftware.jamf.plist
if [[ -z "$jssURL" ]]; then
	jssURL=$( /usr/bin/defaults read /Library/Preferences/com.jamfsoftware.jamf.plist jss_url 2> /dev/null | sed 's/\/$//' )
	if [[ -z "$jssURL" ]]; then
		echo "JSS URL = $jssURL"
		echo "Oops! We couldn't get the JSS URL from this Mac, and none was passed to the script"
		exit 1
	else
		echo "JSS URL = $jssURL"
	fi
else
	## Make sure to remove any trailing / in the passed parameter for the JSS URL
	jssURL=$( echo "$jssURL" | sed 's/\/$//' )
fi

## Set up the JSS Extension Attribute URL
jssEAURL="${jssURL}/JSSResource/computerextensionattributes"

## Run quick check on access to the JSS API
curl -skfu "${apiUser}:${apiPass}" "${jssEAURL}" 2>&1 > /dev/null

if [[ "$?" != "0" ]]; then
	echo "There was an error retrieving information from the JSS.
Please check your API credentials and/or the JSS URL, and ensure the JSS is accessible from your location. Exiting now..."
	exit 1
fi

## Create the extension_attributes directory if not present
if [[ ! -d "$scriptDownloadDir" ]]; then
	mkdir "$scriptDownloadDir"
fi

## Begin Extension Attribute script download process
echo "Step 1:	Gathering all Extension Attribute IDs from the JSS..."
## Generate a list of all Extension Attribute IDs we can pull from the JSS using the API
allExtAttrIDs=$( curl -skfu "${apiUser}:${apiPass}" "${jssEAURL}" | xpath /computer_extension_attributes/computer_extension_attribute/id[1] 2>&1 | sed -e 's/<id>//;s/<\/id>//;s/-- NODE --//' | sed -e '/Found/d;/^$/d' | sort -n )

## Now read through each ID gathered and get specific information on each EA from the JSS
echo "Step 2:	Pulling down each Extension Attribute from the JSS..."

downloadCount=0
while read ID; do
	## Get the EA name from its JSS ID
	ea_Name=$( curl -sku "${apiUser}:${apiPass}" "${jssEAURL}/id/${ID}" | xpath /computer_extension_attribute/name[1] 2>&1 | sed -e 's/<name>//;s/<\/name>//;s/-- NODE --//' | sed -e '/Found/d;/^$/d' )
	## Get the actual script contents from the API record for the EA
	ea_Script=$( curl -sku "${apiUser}:${apiPass}" "${jssEAURL}/id/${ID}" | xpath /computer_extension_attribute/input_type/script[1] 2>&1 | sed -e 's/<script>//;s/<\/script>//;s/-- NODE --//;s/:/\\:/' | sed -e '/Found/d;/^$/d' )
	## Get the first line, which should be a shebang of some kind
	firstLine=$( echo "${ea_Script}" | head -1 )
	## If it looks like the first line begins with a shebang...
	if [[ $( echo "$firstLine" | grep "^#\!" ) ]]; then
		## ...grab the script's interpreter
		shellEnv=$( echo "$firstLine" | awk -F'/' '{print $NF}' | perl -pi -e 'tr/\cM//d;')
		## If the script's interpreter ends in sh (.sh, .bash, .ksh, csh, etc)...
		if [[ "$shellEnv" =~ sh$ ]]; then
			## ...set the script extension to .sh
			scriptExt="sh"
		else
			## Otherwise, use whatever we grabbed as the interpreter (might be .py, .pl, etc)
			scriptExt=$(echo "${shellEnv}" | sed 's/^M//')
		fi
	else
		## We didn't see a shebang as the first line, so assume its a shell script. Set the extension to .sh
		scriptExt="sh"
	fi
	## Now echo the entire script contents to a new file, using the display name and whatever extension we set
	echo "${ea_Script}" > "${scriptDownloadDir}/${ea_Name}.${scriptExt}"
	echo "Downloaded script \"${ea_Name}.${scriptExt}\"..."
	let downloadCount+=1
	
done < <(echo "${allExtAttrIDs}")

echo "Finished downloading all Extension Attribute scripts from the JSS"

echo "Step 3:	Cleaning up script file contents...
	Adding ea_display_name line to end of each file (if needed)...
	Cleaning up ^M carriage returns in script contents...
	Setting executable flag for all script files..."

## Loop through all downloaded scripts, stripping out problem characters and adding the ea_display_name line
while read downloadedScript; do
	scriptBaseName="${downloadedScript%.*}"
	## Replace '&lt' with proper '<' symbol in script contents
	sed -i '' 's/&lt;/</g' "${scriptDownloadDir}/${downloadedScript}"
	## Replace '&amp' with proper '&' symbol in script contents
	sed -i '' 's/&amp;/\&/g' "${scriptDownloadDir}/${downloadedScript}"
	## Remove all Windows carriage returns (^M) from the script contents
	perl -pi -e 'tr/\cM//d;' "${scriptDownloadDir}/${downloadedScript}"
	## If the script doesn't already contain a #ea_display_name line, add one using the base file name
	if [[ ! $(grep "#ea_display_name" "${scriptDownloadDir}/${downloadedScript}") ]]; then
		echo -e "\n\n#ea_display_name	${scriptBaseName}" >> "${scriptDownloadDir}/${downloadedScript}"
	fi
	## Make sure all the scripts have the executable flag set for them
	chmod +x "${scriptDownloadDir}/${downloadedScript}"
done < <(ls "${scriptDownloadDir}")

echo "Step 4:	Running all downloaded scripts to check output..."

## Create a directory for any scripts with problems (if needed)
if [[ ! -d "${scriptDownloadDir}/Problem_scripts/" ]]; then
	mkdir "${scriptDownloadDir}/Problem_scripts/"
fi

## Create a directory for any scripts that fail (if needed)
if [[ ! -d "${scriptDownloadDir}/Failed_scripts/" ]]; then
	mkdir "${scriptDownloadDir}/Failed_scripts/"
fi

## Run through each downloaded script, echo result and check exit status and output
successCount=0
failCount=0
problemCount=0
while read finalScript; do
	echo "Running script:	\"$finalScript\""
	scriptResult=$("${scriptDownloadDir}/$finalScript" 2>/dev/null)$?
	if [[ "$?" == "0" ]]; then
		finResult=$(echo "$scriptResult" | sed -e 's/<result>//;s/<\/result>0//')
		echo -e "Script result:	${finResult}"
		if [[ $(echo "${finResult}" | egrep "\*|<*>|,|%" ) ]]; then
			echo -e "PROBLEM:	The script \"$finalScript\" ran successfully but contains some known illegal characters that will cause the update to fail.\nPlease check the script output."
			echo "Moving \"$finalScript\" to Problem_scripts directory..."
			mv "${scriptDownloadDir}/$finalScript" "${scriptDownloadDir}/Problem_scripts/"
			let problemCount+=1
		else
			echo "PASSED:		The script \"$finalScript\" appears to have been successful..."
			let successCount+=1
		fi
	else
		echo "FAILED:		The script \"$finalScript\" exited with error code ${scriptResult}..."
		echo -e "Script error code:	$scriptResult"
		failure="yes"
		let failCount+=1
		echo "Moving \"$finalScript\" to Failed_scripts directory..."
		mv "${scriptDownloadDir}/$finalScript" "${scriptDownloadDir}/Failed_scripts/"
	fi
	echo -e "\n"
done < <(ls -p "${scriptDownloadDir}" | grep -v / | egrep ".sh$|.pl$|.py$")

## Display final results
if [[ -z "$failure" ]] && [[ "$problemCount" == "0" ]]; then
	echo -e "\nFinal results:
A total of ${downloadCount} scripts were downloaded.
Congratulations! All ${downloadCount} scripts ran successfully!
However, you may want to check the output for each script to verify that the results are what you expect."

elif [[ "$failure" == "yes" ]] && [[ "$problemCount" == "0" ]]; then
	echo -e "\nFinal results:
A total of ${downloadCount} scripts were downloaded.
${successCount} scripts ran successfully.
${failCount} scripts exited with a failure code.
Failed scripts have been moved to a sub directory called \"Failed_scripts\""

elif [[ "$failure" == "yes" ]] && [[ "$problemCount" != "0" ]]; then
	echo -e "\nFinal results:
A total of ${downloadCount} scripts were downloaded.
${successCount} scripts ran successfully.
${failCount} scripts exited with a failure code.
Failed scripts have been moved to a sub directory called \"Failed_scripts\"
${problemCount} scripts passed, but may have illegal characters in their results. Please check the script output above (Look for \"PROBLEM\")
Problem scripts have been moved to a sub directory called \"Problem scripts\""

elif [[ -z "$failure" ]] && [[ "$problemCount" != "0" ]]; then
	echo -e "\nFinal results:
A total of ${downloadCount} scripts were downloaded.
All ${downloadCount} scripts passed, but $problemCount scripts have illegal characters in their results. Please check the script output above (Look for \"PROBLEM\")"

fi

echo -e "\nStep 5:	Done!"

exit
