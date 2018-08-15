#!/bin/bash

if [[ ! -f "/Library/Battelle/Receipts/.OutlookSetupDone" ]]; then
	touch /Library/Battelle/Receipts/.OutlookSetupDone
	sh /Library/Battelle/Scripts/OfficeSignInHelper.sh
	osascript /Library/Battelle/Scripts/OutlookExchangeSetup.scpt
fi

exit 0