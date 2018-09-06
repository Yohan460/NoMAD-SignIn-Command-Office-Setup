# Automatic Outlook Configuraiton with NoMAD

The advantage of utilizing the NoMAD [SignInCommand](https://nomad.menu/help/preferences-and-what-they-do/) is that there will be a kerberos ticket of the user when Outlook is configured vs there being no guarantee of that being the case. The only issue is that the SignInCommand runs every time a sign in happens. Therefore there is a receipt that is written and checked before configuring Outlook.

The [release installer](https://github.com/Yohan460/NoMAD-SignIn-Command-Office-Setup/releases) utilizes the `/Library/NoMADOfficeSetup` directory to write receipts and save the scripts to. You are welcome to make your own custom installer with the source files.

The NoMAD preference for the release installer appears as such:
`SignInCommand="/Library/NoMADOfficeSetup/Scripts/FullOfficeHelper.sh"`

If you have questions please submit an issue or PM [@Yohan](https://macadmins.slack.com/messages/@U5YEE4DPD) on the [MacAdmins](macadmins.slack.com) Slack channel
