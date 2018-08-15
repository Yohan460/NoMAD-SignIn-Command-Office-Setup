#!/bin/sh
#set -x

TOOL_NAME="Microsoft Office for Mac Sign In Helper"
TOOL_VERSION="1.0"

## Copyright (c) 2018 Microsoft Corp. All rights reserved.
## Scripts are not supported under any Microsoft standard support program or service. The scripts are provided AS IS without warranty of any kind.
## Microsoft disclaims all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a 
## particular purpose. The entire risk arising out of the use or performance of the scripts and documentation remains with you. In no event shall
## Microsoft, its authors, or anyone else involved in the creation, production, or delivery of the scripts be liable for any damages whatsoever 
## (including, without limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary 
## loss) arising out of the use of or inability to use the sample scripts or documentation, even if Microsoft has been advised of the possibility
## of such damages.
## Feedback: pbowden@microsoft.com

## This script is Jamf Pro compatible and can be pasted directly, without modification, into a new script window in the Jamf admin console.
## When running under Jamf Pro, no additional parameters need to be specified.

# Shows tool usage and parameters
function ShowUsage {
	echo $TOOL_NAME - $TOOL_VERSION
	echo "Purpose: Detects UPN of logged-on user and pre-fills Office and Skype for Business Sign In page"
	echo "Usage: $0 [--Verbose]"
	echo
	exit 0
}

# Checks to see if the script is running as root
function RunningAsRoot {
	if [ "$EUID" = "0" ]; then
		echo "1"
	else
		echo "0"
	fi
}

# Returns the name of the logged-in user, which is useful if the script is running in the root context
function GetLoggedInUser {
	# The following line is courtesy of @macmule - https://macmule.com/2014/11/19/how-to-get-the-currently-logged-in-user-in-a-more-apple-approved-way/
	local LOGGEDIN=$(/usr/bin/python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");')
	if [ "$LOGGEDIN" == "" ]; then
		echo "0"
	else
		echo "$LOGGEDIN"
	fi
}

# Detects whether a given preference is managed
function IsPrefManaged {
	local PREFKEY="$1"
	local PREFDOMAIN="$2"
	local MANAGED=$(python -c "from Foundation import CFPreferencesAppValueIsForced; print CFPreferencesAppValueIsForced('${PREFKEY}', '${PREFDOMAIN}')")
	if [ "$MANAGED" == "True" ]; then
		echo "1"
	else
		echo "0"
	fi
}

# Detect Kerberos cache
function DetectKerbCache {
	local KERB=$(${CMD_PREFIX} /usr/bin/klist 2> /dev/null)
	if [ "$KERB" == "" ]; then
		echo "0"
	else
		echo "1"
	fi
}

# Get the Kerberos principal from the cache
function GetPrincipal {
	local PRINCIPAL=$(${CMD_PREFIX} /usr/bin/klist | grep -o 'Principal: .*' | cut -d : -f2 | cut -d' ' -f2 2> /dev/null)
	if [ "$PRINCIPAL" == "" ]; then
		echo "0"
	else
		echo "$PRINCIPAL"
	fi
}

# Extract account name from principal
function GetAccountName {
	local PRINCIPAL="$1"
	echo "$PRINCIPAL" | cut -d @ -f1
}

# Extract domain name from principal
function GetDomainName {
	local PRINCIPAL="$1"
	echo "$PRINCIPAL" | cut -d @ -f2
}

# Get the defaultNamingContext from LDAP
function GetDefaultNamingContext {
	local DOMAIN="$1"
	local DOMAINNC=$(${CMD_PREFIX} /usr/bin/ldapsearch -H "ldap://$DOMAIN" -LLL -b '' -s base defaultNamingContext | grep -o 'defaultNamingContext:.*' | cut -d : -f2 | cut -d' ' -f2 2> /dev/null)
	if [ "$DOMAINNC" == "" ]; then
		echo "0"
	else
		echo "$DOMAINNC"
	fi
}

# Get the UPN for the user account
function GetUPN {
	local DOMAIN="$1"
	local NAMESPACE="$2"
	local ACCOUNT="$3"
	local UPN=$(${CMD_PREFIX} /usr/bin/ldapsearch -H "ldap://$DOMAIN" -LLL -b "$NAMESPACE" -s sub samAccountName=$ACCOUNT userPrincipalName | grep -o 'userPrincipalName:.*' | cut -d : -f2 | cut -d' ' -f2 2> /dev/null)
	if [ "$UPN" == "" ]; then
		echo "0"
	else
		echo "$UPN"
	fi
}

# Set Sign In keys
function SetPrefill {
	local UPN="$1"
	SetPrefillOffice "$UPN"
	SetPrefillSkypeForBusiness "$UPN"
	### Comment out the next line if you don't want to enable automatic sign in, or you are setting it separately in a Configuration Profile
	SetAutoSignIn
}

# Set Home Realm Discovery for Office apps
function SetPrefillOffice {
	local UPN="$1"
	local KEYMANAGED=$(IsPrefManaged "OfficeActivationEmailAddress" "com.microsoft.office")
	if [ "$KEYMANAGED" == "1" ]; then
		echo ">>ERROR - Cannot override managed preference 'OfficeActivationEmailAddress'"
	else
		${CMD_PREFIX} /usr/bin/defaults write com.microsoft.office OfficeActivationEmailAddress -string ${UPN}
		if [ "$?" == "0" ]; then
			echo ">>SUCCESS - Set 'OfficeActivationEmailAddress' to ${UPN}"
		else
			echo ">>ERROR - Did not set value for 'OfficeActivationEmailAddress'"
			exit 1
		fi
	fi
}

# Set Office Automatic Office Sign In
function SetAutoSignIn {
	local KEYMANAGED=$(IsPrefManaged "OfficeAutoSignIn" "com.microsoft.office")
	if [ "$KEYMANAGED" == "1" ]; then
		echo ">>WARNING - Cannot override managed preference 'OfficeAutoSignIn'"
	else
		${CMD_PREFIX} /usr/bin/defaults write com.microsoft.office OfficeAutoSignIn -bool TRUE
		if [ "$?" == "0" ]; then
			echo ">>SUCCESS - Set 'OfficeAutoSignIn' to TRUE"
		else
			echo ">>ERROR - Did not set value for 'OfficeAutoSignIn'"
			exit 1
		fi
	fi
}

# Set Skype for Business Sign In
function SetPrefillSkypeForBusiness {
	local UPN="$1"
	local KEYMANAGED=$(IsPrefManaged "userName" "com.microsoft.SkypeForBusiness")
	if [ "$KEYMANAGED" == "1" ]; then
		echo ">>ERROR - Cannot override managed preference 'userName'"
	else
		${CMD_PREFIX} /usr/bin/defaults write com.microsoft.SkypeForBusiness userName -string ${UPN}
		if [ "$?" == "0" ]; then
			echo ">>SUCCESS - Set 'userName' to ${UPN}"
		else
			echo ">>ERROR - Did not set value for 'userName'"
			exit 1
		fi
	fi
	local SIP="$1"
	local KEYMANAGED=$(IsPrefManaged "sipAddress" "com.microsoft.SkypeForBusiness")
	if [ "$KEYMANAGED" == "1" ]; then
		echo ">>ERROR - Cannot override managed preference 'sipAddress'"
	else
		${CMD_PREFIX} /usr/bin/defaults write com.microsoft.SkypeForBusiness sipAddress -string ${SIP}
		if [ "$?" == "0" ]; then
			echo ">>SUCCESS - Set 'sipAddress' to ${SIP}"
		else
			echo ">>ERROR - Did not set value for 'sipAddress'"
			exit 1
		fi
	fi
}

# Detect Domain Join
function DetectDomainJoin {
	local DSCONFIGAD=$(${CMD_PREFIX} /usr/sbin/dsconfigad -show)
	if [ "$DSCONFIGAD" == "" ]; then
		echo "0"
	else
		echo "1"
	fi
}

# Detect Jamf presence
function DetectJamf {
	if [ -e "/Library/Preferences/com.jamfsoftware.jamf.plist" ]; then
		echo "1"
	else
		echo "0"
	fi
}

# Detect NoMAD presence
function DetectNoMAD {
	local NOMAD=$(${CMD_PREFIX} /usr/bin/defaults read com.trusourcelabs.NoMAD 2> /dev/null)
	if [ "$NOMAD" == "" ]; then
		echo "0"
	else
		echo "1"
	fi
}

# Get the UPN from NoMAD's preference cache
function GetUPNfromNoMAD {
	local NMUPN=$(${CMD_PREFIX} /usr/bin/defaults read com.trusourcelabs.NoMAD UserUPN 2> /dev/null)
	if [ "$NMUPN" == "" ]; then
		echo "0"
	else
		echo "$NMUPN"
	fi
}

# Detect Enterprise Connect presence
function DetectEnterpriseConnect {
	local EC=$(${CMD_PREFIX} /usr/bin/defaults read com.apple.Enterprise-Connect 2> /dev/null)
	if [ "$EC" == "" ]; then
		echo "0"
	else
		echo "1"
	fi
}

# Evaluate command-line arguments
while [[ $# > 0 ]]
do
	key="$1"
	case "$key" in
    	--Help|-h|--help)
    	ShowUsage
    	exit 0
		shift # past argument
    	;;
    	--Verbose|-v|--verbose)
    	set -x
    	shift # past argument
    	;;
	esac
	shift # past argument or value
done

## Main
# Determine whether we need to use a sudo -u prefix when running commands
# NOTE: CMD_PREFIX is intentionally implemented as a global variable
CMD_PREFIX=""
ROOTLOGON=$(RunningAsRoot)
if [ "$ROOTLOGON" == "1" ]; then
	CURRENTUSER=$(GetLoggedInUser)
	if [ ! "$CURRENTUSER" == "0" ]; then
		echo ">>INFO - Script is running in the root security context - running commands as user: $CURRENTUSER"
		CMD_PREFIX="/usr/bin/sudo -u ${CURRENTUSER}"
	else
		echo ">>ERROR - Could not obtain the logged in user name"
		exit 1
	fi
fi

# Detect Active Directory connection style
DJ=$(DetectDomainJoin)
if [ "$DJ" == "1" ]; then
	echo ">>INFO - Detected that this machine is domain joined"
fi
NM=$(DetectNoMAD)
if [ "$NM" == "1" ]; then
	echo ">>INFO - Detected that this machine is running NoMAD"
fi
EC=$(DetectEnterpriseConnect)
if [ "$EC" == "1" ]; then
	echo ">>INFO - Detected that this machine is running Enterprise Connect"
fi

# Find out if a Kerberos principal and ticket is present
UPN="0"
KERBCACHE=$(DetectKerbCache)
if [ "$KERBCACHE" == "1" ]; then
	echo ">>INFO - Detected Kerberos cache"
	PRINCIPAL=$(GetPrincipal)
	if [ ! "$PRINCIPAL" == "0" ]; then
		echo ">>INFO - Detected Kerberos principal: $PRINCIPAL"
		# Get the account and domain name
		ACCOUNT=$(GetAccountName "$PRINCIPAL")
		DOMAIN=$(GetDomainName "$PRINCIPAL")
		# Find the default naming context for Active Directory
		NAMESPACE=$(GetDefaultNamingContext "$DOMAIN")
		if [ ! "$NAMESPACE" == "0" ]; then
			echo ">>INFO - Detected naming context: $NAMESPACE"
			# Now to get the UPN
			UPN=$(GetUPN "$DOMAIN" "$NAMESPACE" "$ACCOUNT")
			if [ ! "$UPN" == "0" ]; then
				echo ">>INFO - Found UPN: $UPN"
				SetPrefill "$UPN" 
				exit 0
			else
				echo ">>WARNING - Could not find UPN"
			fi
		else
			echo ">>WARNING - Could not retrieve naming context"
		fi
	else
		echo ">>WARNING - Could not retrieve principal"
	fi
else
	echo ">>WARNING - No Kerberos cache present"
fi

# If we haven't got a UPN yet, see if we can get it from NoMAD's cache
if [ "$UPN" == "0" ] && [ "$NM" == "1" ]; then
	UPN=$(GetUPNfromNoMAD)
	if [ ! "$UPN" == "0" ]; then
		echo ">>INFO - Found UPN from NoMAD: $UPN"
		SetPrefill "$UPN"
		exit 0
	else
		echo ">>WARNING - Could not retrieve UPN from NoMAD"
	fi
fi

# If we still haven't got a UPN yet, show an error
if [ "$UPN" == "0" ]; then
	echo ">>ERROR - Could not detect UPN"
	exit 1
fi

exit 0