# Changes to the original apstra chaos cat
## Last updated by Greg B on 28 October 2024
------------------------------------------------------------------

## Changes from 28 October 2024

- Added an option to select from multiple blueprints on an Apstra server.
  Now you can pick, instead of always using the blueprint with the ID
  `evpn-vex-virtual`.  There is a stand-alone option on the main menu for this,
  but the function is also called from other functions that rely on there
  being a selected blueprint (e.g., `Commit Apstra Blueprint`).

- Updated the `Commit Apstra Blueprint` option so that chaoscat retrieves the
  current blueprint revision number from `/api/blueprints/$bpid`, rather than
  from `/api/blueprints/$bpid/deploy`.  The latter could sometimes lag the
  former, leading to cases where the most recent changes to the blueprint
  wouldn't commit.

## Changes from 1 October 2024

- Line 5:  Changed the value of `ifprefix` from `xe` to `ge` as it seems
  Apstra Cloudlabs is using ge-x/y/z as the default interface naming on
  Junos VM's now.

- Line 7 (getopts):  Added support for `-s` to include a server hostname or
  IP address on the command line.  Now you can run chaos cat interactively
  from anywhere!

- Function disableint():  Changed from single quotes to double quotes around
  the `set` command to allow for expansion of `$ifprefix` in the command.

- Function flapif():  Changed from single quotes to double quotes encasing
  the `echo` payload, and escaping the double quotes in the payload, to allow
  for the expansion of `$ifprefix` in the script text.  Also added a delay
  between the 'down' and 'up' commands, with the `$delay` set in line 6.

- Function breakcablemap():  Rewrote this function so that it swaps the
  uplinks from leaf2 in the evpn_esi_001 rack.  So what used to go to
  spine1 now goes to spine2 and vice versa.  This is a change that will
  trigger Connectivity Root Cause model to provide something useful.

- Function rampcpu():  Starting three instances of `dd` to spike all 3 vCPU's
  allocated to the vJunos-Switch instances in Cloudlabs.