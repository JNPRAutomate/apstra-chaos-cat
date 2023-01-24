## apstra chaos cat
# Break your topology, so you can more easily demo various failure scenarios for customers.
Written in bash so it's extremely portable, the only dependency is 'jq' (https://stedolan.github.io/jq/) which allows parsing of json files on the command line.  
jq is also available by default on the pre-packaged Apstra VM.

# This script has 9 scenarios, that work either by sending commands to an Apstra managed Junos device, or to the Apstra API itself.

- Disable switch IF (send a set xe-0/0/0 disable to the switch of your choosing
- Break Cabling Map (Change the Spine/Leaf connection spine1<->evpn_esi_001_leaf2 to use a port which will break the cable map)
- Change ASN of Device (again on the switch of your choosing, but JD prefers to demo this on a leaf)
- Add a static route to a device (set routing-options static route 7.7.7.7/32 next-hop 8.8.8.8)
- Flap xe-0/0/0 on a selected device (create a bash file, flap.sh (while true;do ifconfig xe-0/0/0 down;ifconfig xe-0/0/0 up; done), and run it - hacky but it works)
- Try to peg the CPU of a device (sends cat /dev/zero > /dev/null on a chosen switch - this may not work with physical devices, but will definitely CPU bind a vQFX in the typical CPU/Mem configuration of cloudlabs)


# 3 additional pieces of functionality are available, 

- Change Blueprint Name - set the blueprint to a friendly name for demo purposes
- Save Current Blueprint Version (creates a time voyager saved blueprint that can be reverted to after thoroughly breaking your env)
- Run a commit (Send a commit so any of the above changes will be committed without using the Web UI)


# Usage:
- Download the raw file to an Apstra VM.  
- Verify that the Apstra password is correct, or change it to the password of your instance.
- Run it 
```
wget <github raw file link>
vi apstrachaostcat.sh 
bash apstrachaoscat.sh
```

<img width="714" alt="image" src="https://user-images.githubusercontent.com/100955679/207923689-9593fbe2-f3d4-4b22-bdfd-4932c5aff2e9.png">

