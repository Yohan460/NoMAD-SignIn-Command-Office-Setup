#!/bin/bash

if [[ ! -f "/Library/NoMADOfficeSetup/Receipts/.OutlookSetupDone" ]]; then
	touch /Library/NoMADOfficeSetup/Receipts/.OutlookSetupDone
	sh /Library/NoMADOfficeSetup/Scripts/OfficeSignInHelper.sh
	osascript /Library/NoMADOfficeSetup/Scripts/OutlookExchangeSetup.scpt
fi

exit 0
