UpdateExtensionAttributes
=========================

#Casper Suite - Update Extension Attributes

##Description
This set of scripts was designed to work with the Casper Suite for Mac management.
The purpose of the scripts is to allow a Mac Casper Suite administrator to update any number of Extension Attribute values on their managed Macs, on as frequent a basis as they want, without needing to perform a full inventory collection.

##Compatibility
- The *update-extension-attributes.sh* bash script will work in the Casper Suite 8 and 9 series.
- The companion *download-extension-attributes.sh* bash script will only work in the Casper Suite 9 series.

##Requirements and Workflow
The requirements to enable this functionality is as follows
- A JSS API account with both **read** and **write** privileges to your JSS
- A copy of any or all Extension Attributes scripts that can be distributed to your clients
Note: Each Extension Attribute script must contain a line indicating the EA Display Name as it appears in the JSS (see below for details)

###General Workflow:
- A directory is distributed to your Mac clients containing any number of Extension Attribute scripts
- The **update-extension-attributes.sh** script is run on Macs that contain this directory, typically using a Casper Suite policy
- The script will cycle through all scripts in the given directory, capturing their results
- Each result is placed into a final xml file that is then uploaded to the Mac's JSS record using the Casper Suite API PUT function

Note that the Extension Attribute scripts directory can be protected by making it hidden and/or protected by having it owned by the root account, as long as the "update" script is running with root privileges.

###Setting up your EA scripts:
In order for the script to properly set up the final xml file for upload, it needs to know the correct EA Display Name for each script as it encounters it.
To do this, you will need to edit each script to contain a single commented out line in the following format:
```
#ea_display_name	Actual Display Name
```

This line can be anywhere in the script. The **update-extension-attributes** script will look for the line and pull the EA Diaplay Name to use for the xml file. The display name can contain spaces and most speacial charcters (see the Known Issues section for more)

In general, this should be the only necessary change to your Extension Attribute scripts. However there are some known issues in relation to the results the scripts may output. See the **Known Issues** section below for more information.

##Using the **download-extension-attributes** companion script:
The **download-extension-attributes.sh** script is a companion script that can be used in conjunction with a Casper Suite 9 series JSS to pull down all Extension Attributes into discrete script files to a given directory. The script will also verify each script by running them against the Mac and checking both the output and exit status. Any scripts that fail will be moved to a sub directory. Any scripts that contain illegal characters in the output will be moved into a separate sub directory.

For usage information, run the scrpt on the command line as follows:
```
/path/to/script/download-extension-attributes.sh -h
```

##Known Issues
###The following are the current known issues with these scripts

There are several illegal characters that, while they may work without errors in your regular Extension Attribute scripts, can cause a failure of the resulting xml file when the upload is attempted.
Here are the currently known characters:
-   < & >   When used in the format of <some data>, this will cause the xml uplaod to fail as it sees these as xml tags and believes the xml file to be malformed
-   %       Cannot be used in the result. Causes the upload to fail with an error
-   ,       Cannot be used in the result. Causes the upload to fail with an error
-   *       Cannot be used in the result. Causes the upload to fail with an error

The **download-extension-attributes** script will make a best effort to identify scripts that contain any of the above characters in the results and move these scripts into a **Problem_scripts** sub directory.
