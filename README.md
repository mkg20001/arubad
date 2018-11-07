# arubad

Daemon that automatically logs you in to arubanetworks.com captive portals

# Why?

My school uses that, and my laziness got me to create a script for that (It requires typing in login credentials. Too! Much! Work!)

# Usage & Installation

- Requires `curl` and `grep`
- Network MUST be managed by network manager

Install as daemon, with credentials (systemd-only):

```
$ sudo bash arubad.sh install <username> <password>
```

Just run it!™
```
$ export ARUBA_USER=YourUser
$ export ARUBA_PW=YourPW
$ bash arubad.sh
```
