# Redmine CAS plugin

Plugin to CASify your Redmine installation.

## Compatibility

Tested with Redmine 2.2.3, but should be working fine with Redmine 2.x and possibly 1.x.

## Installation

1. Download or clone this repository and place it in the Redmine plugin directory
2. Restart your webserver
3. Open Redmine and check if the plugin is visible under Administration > Plugins
4. Follow the "Configure" link and set the parameters
5. Party

## Notes

### Usage

This plugin was made for redmine installations without public areas ("Authentication required").
The default login page will still work when you access it directly (http://example.com/path-to-redmine/login).

### Single Sign Out, Single Logout

Session need to be stored in the database to make Single Sign Out work.
You can achieve this with a tiny plugin: [redmine_activerecord_session_store](https://github.com/pencil/redmine_activerecord_session_store)

## Copyright

Copyright (c) 2013 Nine Internet Solutions AG. See LICENSE.txt for further details.
