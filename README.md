UpdateExtensionAttributes
=========================

Casper Suite - Update Extension Attributes

##Description
This set of scripts was designed to work with the Casper Suite for Mac management.
The purpose of the scripts is to allow a Mac Casper Suite administrator to update any number of Extension Attribute values on their managed Macs, on as frequent a basis as they want, without needing to perform a full inventory collection.

##Compatibility
The "update-extension-attributes.sh" bash script will work in the Casper Suite 8 and 9 series.
The companion "download-extension-attributes.sh" bash script will only work in the Casper Suite 9 series.

###Requirements and Workflow
The requirements to enable this functionality is as follows
- A JSS API account with both *read* and *write* privileges to your JSS
- A copy of any or all Extension Attributes scripts that can be distributed to your clients
Note: Each Extension Attribute script must contain a line indicating the EA Display Name as it appears in the JSS (see below for details)

###The general workflow is as follows:
- A directory is distributed to your Mac clients containing any number of Extension Attribute scripts
- The "update-extension-attributes.sh" script is run on Macs that contain this directory, typically using a Casper Suite policy
- The script will cycle through all scripts in the given directory, capturing their results
- Each result is placed into a final xml file that is then uploaded to the Mac's JSS record using the Casper Suite API PUT function

###Setting up your EA scripts:
In order for the script to properly set up the final xml file for upload, it needs to know the correct EA Display Name for each script as it encounters it.
To do this, you will need to edit each script to contain a single commented out line in the following format:
```
\#ea_display_name	Actual Display Name
```
