# Redmine CAS plugin

Plugin to CASify your Redmine installation.

## Compatibility

Tested with Redmine 2.2.x, 2.3.x, 2.4.x and 2.5.x but it should work fine with Redmine 2.x and possibly 1.x.
We use [CASino](http://casino.rbcas.com) as CAS server, but it might work with others as well.

## Installation

1. Download or clone this repository and place it in the Redmine `plugins` directory as `redmine_cas`
2. Restart your webserver
3. Open Redmine and check if the plugin is visible under Administration > Plugins
4. Follow the "Configure" link and set the parameters
5. Party

## Notes

### Usage

If your installation has no public areas ("Authentication required") and you are not logged in, you will be
redirected to the CAS-login page.  The default login page will still work when you access it directly 
(http://example.com/path-to-redmine/login).

If your installation is not "Authentication required", the login page will show a link that lets you login
with CAS.

### Single Sign Out, Single Logout

The sessions have to be stored in the database to make Single Sign Out work.
You can achieve this with a tiny plugin: [redmine_activerecord_session_store](https://github.com/pencil/redmine_activerecord_session_store)

### Auto-create users

By enabling this setting, successfully authenticated users will be automatically added into Redmine if they do not already exist. You *must* define the attribute mapping for at least firstname, lastname and mail attributes for this to work.

## About

This redmine plugin is currently maintained and funded by [nine](https://nine.ch).

[![logo of the company 'nine'](https://logo.apps.at-nine.ch/Dmqied_eSaoBMQwk3vVgn4UIgDo=/trim/500x0/logo_claim.png)](https://www.nine.ch)

