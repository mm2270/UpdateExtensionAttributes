#!/bin/bash

## Script name:		update-extension-attributes.sh
## Author:			Mike Morales (mm2270 on JAMFNation)
##					https://jamfnation.jamfsoftware.com/viewProfile.html?userID=1927
## Last change:		2014-05-14

## Description:		Script to update any Extension Attribute values based on scripts located
##					in a specified directory, by using the Casper Suite API

## Casper Suite API assignments
##
## Hardcode the API username/password and JSS URL below, or, assign Casper Suite script parameters
## for each item to have them passed down to the script at execution time

apiUser=""		## Assign Parameter 4 if using Casper Suite script parameter
apiPass=""		## Assign Parameter 5 if using Casper Suite script parameter
jssURL=""		## (Optional - see below) Assign Parameter 6 if using Casper Suite script parameter
				## Special note: The script will use the following priority order to assign the JSS URL:
				## 1)	If the JSS URL is hardcoded into the script it will be used first
				## 2)	If the JSS URL variable is empty in the script and a Casper Suite parameter is
				##		assigned for parameter 6, it will be used
				## 3)	If the JSS URL variable is empty in the script and no Casper Suite parameter has
				##		been assigned, the script will attempt to get the JSS URL from the client's
				##		com.jamfsoftware.jamf.plist file.
				## 4)	If the JSS URL variable is empty in the script, there is no Casper Suite parameter
				##		assigned, and the script cannot get the JSS URL from the client, the script will
				##		exit with an error since any upload of the resulting xml will be impossible.
				##
				## If you assign the JSS URL, either hardcoded or by script parameter, leave off the
				## trailing slash from the string. Ex: "https://my.jssserver.com:8443"

## Set the following variable to "yes" if its required to have the Mac check to see if
## it is on your internal network.
## Explanation : This will be required in cases where you have a Limited Access JSS.
## Although the JSS Connection test will pass, an API upload attempt will fail because Tomcat
## is required, which is disabled on the external WebApp instance.
## If your JSS is openly accessible from the outside, you can leave this setting blank.
##
## Note: You must also specify either an internal http address or hostname to check for
## internal connection verification in the next variable.

internal_check_req="yes"

## If internal_check_req is set to yes, enter an internal address (hostname or http URL) the
## script can use for checking internal connectivity.
## Some examples of what you can enter are full http://www. style URLs (http://www.school.org),
## or a base hostname (school.org). Be sure what you enter is accurate or it may result in
## false failures, which will cause the script to exit.

## You may also assign parameter 7 to the script in Casper Suite for the internal_address variable.

internal_address=""		## Assign Parameter 7 if using Casper Suite script parameter

## OPTIONAL: Set the following to:
## a) path to the base directory that contains the extension attribute scripts
## b) path to the final xml file to be used in the API PUT upload.
## You may also leave these as is.
## Be sure to drop your EA script files into the basePath directory at the top level
basePath="/Library/Application Support/JAMF/extension_attributes"
xmlDir="/Library/Application Support/JAMF/extension_attributes_xml"

################################ DO NOT EDIT BELOW THIS LINE ################################

function get_ea_results ()
{

## Make sure the xml result directory exists. If not, create it
if [[ ! -d "$xmlDir" ]]; then
	mkdir "$xmlDir"
fi

## Set the xml path for the upload based on the directory assignment
xmlPath="${xmlDir}/ea_updates_xml.xml"

## Get the MAC address for en0 on this Mac
MacID=$( /usr/sbin/networksetup -getmacaddress en0 | awk '{print $3}' | sed 's/:/./g' )

## Generate the header of the xml file
echo "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>
<computer>
<extension_attributes>" > "${xmlPath}"

## Loop through each script in the base dir
while read ea_script; do
	## Get the ea_display_name line from the scripts contents
	ea_name=$(awk -F'[\t]' '/ea_display_name/{print $2}' < "$ea_script")
	
	ea_result=$("$ea_script" | sed -e 's/<result>//;s/<\/result>//')
	if [[ ! -z "$ea_name" && "$ea_result" ]]; then
	echo "<attribute>
<name>"${ea_name}"</name>
<value>$(echo "${ea_result}")</value>
</attribute>" >> "${xmlPath}"
	fi
done < <(find "${basePath}" -maxdepth 1 -type f | egrep ".sh$|.pl$|.py$")

## Finish off the xml file
echo "</extension_attributes>
</computer>" >> "${xmlPath}"

## Upload the final xml to the JSS
echo "Finished collecting Extension Attribute results. Updating the computer record with new data..."
curl -skfu "${apiUser}:${apiPass}" "${jssURL}/JSSResource/computers/macaddress/$MacID" -T "${xmlPath}" -X PUT
uploadResult="$?"

## Check the exit status of the upload
if [[ "$uploadResult" == "0" ]]; then
	echo "API upload successful. Cleaning up and exiting..."
	## Delete the xml file after successful upload
	rm -f "${xmlPath}"
else
	echo -e "API upload failed.\n\t1 - Check the \"ea_updates_xml.xml\" file located in \"${xmlDir}\" to make sure it was properly formed.\n\t2 - Check the network connectivity on this Mac."
fi

}

## Function for checking JSS availability
function jss_check ()
{

/usr/sbin/jamf checkJSSConnection -retry 2
jss_check_result="$?"

if [[ "$jss_check_result" == "0" ]]; then
	echo "Move on to getting Extension Attribute results"
	get_ea_results
else
	echo "JSS is not currently available. Exit the script"
	exit 0
fi

}

## Function for checking the internal network availability
function internal_check ()
{

if [[ "$checkType" == "ping" ]]; then
	echo "Running ping against ${internal_address}..."
	ping -c 2 -o "$internal_address" 2>&1 > /dev/null
	check_result="$?"
elif [[ "$checkType" == "curl" ]]; then
	echo "Running curl against ${internal_address}..."
	curl -s -I "$internal_address"
	check_result="$?"
fi

if [[ "$check_result" == "0" ]]; then
	echo "Internal check was successful. Move to checking JSS connectivity"
	jss_check
else
	echo "Internal check failed. Exit the script."
	exit 0
fi

}

## Main script starts here
## Check and assign API information
if [[ "$apiUser" == "" ]] && [[ "$4" != "" ]]; then
	apiUser="$4"
else
	echo "Error: The apiUser variable was not defined in the script and no parameter was assigned."
	exit 1
fi

if [[ "$apiPass" == "" ]] && [[ "$5" != "" ]]; then
	apiPass="$5"
else
	echo "Error: The apiPass variable was not defined in the script and no parameter was assigned."
	exit 1
fi

if [[ "$jssURL" != "" ]]; then
	jssURL="$jssURL"
fi

if [[ "$jssURL" == "" ]] && [[ "$6" == "" ]]; then
	jssURL=$( defaults read /Library/Preferences/com.jamfsoftware.jamf jss_url | sed 's/\/$//' )
elif [[ "$jssURL" == "" ]] && [[ "$6" != "" ]]; then
	jssURL="$6"
else
	echo "Error: The jssURL variable was not defined in the script, no parameter was assigned and we were unable to pull the address from the client. Exiting..."
	exit 1
fi

if [[ "$internal_address" == "" ]] && [[ "$7" != "" ]]; then
	internal_address="$7"
fi

## Find any shell, perl or python scripts in the source directory. Make sure there is at least one.
if [[ $(find "${basePath}" -maxdepth 1 -type f -print | egrep ".sh$|.pl$|.py$") ]]; then
	echo "We have at least one extension attribute script to run"
else
	echo "No extension attribute scripts were located"
	exit 0
fi

## Now check to see if the internal_check_req flag was set.
## If yes, assess the type of check we need to perform and run the internal check function.
if [[ "$internal_check_req" == "yes" ]]; then
	echo "internal_check_req flag is set to \"yes\""
	if [[ "$internal_address" != "" ]]; then
		if [[ $(echo "$internal_address" | grep "^http") ]]; then
			checkType="curl"
			internal_check
		else
			checkType="ping"
			internal_check
		fi
	else
		## Exit if internal_check flag was set to yes and we didn't get an address to check against
		echo "No internal_address was specified in the script, but the internal_check_req flag was set. Enter an address to check and retry."
		exit 1
	fi
else
	## internal_check_req was not set, so skip to the JSS check phase
	echo "No internal check required. Skipping to JSS Connection check"
	jss_check
fi