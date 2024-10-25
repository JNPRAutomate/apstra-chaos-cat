#!/bin/bash

apstraserver=""
apstrapass=""
ifprefix=""
delay=0.5

bp_label=""

###
### Let's define some functions first...
###

breakcablemap() {
  link1_endpoints=`curl -s -k --location --request GET "https://$apstraserver/api/blueprints/$bpid/experience/web/cabling-map" --header "AUTHTOKEN: $authtoken" --data-raw "" | jq '.links[] | select(.label == "spine1<->evpn_esi_001_leaf2[1]") | {endpoints}'`
  link2_endpoints=`curl -s -k --location --request GET "https://$apstraserver/api/blueprints/$bpid/experience/web/cabling-map" --header "AUTHTOKEN: $authtoken" --data-raw "" | jq '.links[] | select(.label == "spine2<->evpn_esi_001_leaf2[1]") | {endpoints}'`

  if [ $(echo $link1_endpoints | jq --raw-output '.endpoints[0].system.label') = 'spine1' ]; then
    link1_spineid=`echo $link1_endpoints | jq --raw-output '.endpoints[0].interface.id'`
    link1_spine_ifname=`echo $link1_endpoints | jq --raw-output '.endpoints[0].interface.if_name'`
    link1_leafid=`echo $link1_endpoints | jq --raw-output '.endpoints[1].interface.id'`
    link1_leaf_ifname=`echo $link1_endpoints | jq --raw-output '.endpoints[1].interface.if_name'`
  else 
    link1_spineid=`echo $link1_endpoints | jq --raw-output '.endpoints[1].interface.id'`
    link1_spine_ifname=`echo $link1_endpoints | jq --raw-output '.endpoints[1].interface.if_name'`
    link1_leafid=`echo $link1_endpoints | jq --raw-output '.endpoints[0].interface.id'`
    link1_leaf_ifname=`echo $link1_endpoints | jq --raw-output '.endpoints[0].interface.if_name'`
  fi 

  if [ $(echo $link2_endpoints | jq --raw-output '.endpoints[0].system.label') = 'spine2' ]; then
    link2_spineid=`echo $link2_endpoints | jq --raw-output '.endpoints[0].interface.id'`
    link2_spine_ifname=`echo $link2_endpoints | jq --raw-output '.endpoints[0].interface.if_name'`
    link2_leafid=`echo $link2_endpoints | jq --raw-output '.endpoints[1].interface.id'`
    link2_leaf_ifname=`echo $link2_endpoints | jq --raw-output '.endpoints[1].interface.if_name'`
  else 
    link2_spineid=`echo $link2_endpoints | jq --raw-output '.endpoints[1].interface.id'`
    link2_spine_ifname=`echo $link2_endpoints | jq --raw-output '.endpoints[1].interface.if_name'`
    link2_leafid=`echo $link2_endpoints | jq --raw-output '.endpoints[0].interface.id'`
    link2_leaf_ifname=`echo $link2_endpoints | jq --raw-output '.endpoints[0].interface.if_name'`
  fi 

  curl -s -k --location --request PATCH "https://$apstraserver/api/blueprints/$bpid/cabling-map" \
    --header "AUTHTOKEN: $authtoken" \
    --header "Content-Type: application/json" \
    --data-raw " {
      \"links\": [
        {
          \"endpoints\": [
            {
              \"interface\": {
                \"id\": \"$link1_leafid\",
                \"if_name\": \"$link2_leaf_ifname\"
              }
            },
            {
              \"interface\": {
                \"id\": \"$link1_spineid\",
                \"if_name\": \"$link1_spine_ifname\"
              }
            }
          ],
          \"id\": \"spine1<->evpn_esi_001_leaf2[1]\"
        },
        {
          \"endpoints\": [
            {
              \"interface\": {
                \"id\": \"$link2_leafid\",
                \"if_name\": \"$link1_leaf_ifname\"
              }
            },
            {
              \"interface\": {
                \"id\": \"$link2_spineid\",
                \"if_name\": \"$link2_spine_ifname\"
              }
            }
          ],
          \"id\": \"spine2<->evpn_esi_001_leaf2[1]\"
        }
      ]
    }"

  for (( i = 5 ; i > 0 ; i-- )); do
      echo -n -e "\r\e[0KCommitting change in $i seconds..."
      sleep 1
  done
  commitcurrent
}

changeswasn() {
  getswitchinfo
  ( echo 'conf';echo 'set routing-options autonomous-system 645135';echo 'commit and-quit' ) | sshpass -proot123 ssh -o StrictHostKeyChecking=no root@"$switch_ip" "cli"
  sleep 2
}

commitcurrent() {
  commitversion=`curl -s -k --location --request GET "https://$apstraserver/api/blueprints/$bpid/deploy" --header "AUTHTOKEN: $authtoken" | jq '.version'  --raw-output`
  echo "version is $commitversion"
  curl -k --location -g --request PUT "https://$apstraserver/api/blueprints/$bpid/deploy" \
    --header "AUTHTOKEN: $authtoken" \
    --header "Content-Type: application/json" \
    --data-raw "{
      \"version\": "$commitversion",
      \"description\": \"Committed by script at `date`\"
  }"
}

disableint() {
  getswitchinfo
  ( echo 'conf';echo "set int $ifprefix-0/0/1 disable";echo 'commit and-quit' ) | sshpass -proot123 ssh -o StrictHostKeyChecking=no root@"$switch_ip" "cli"
  sleep 2
}

flapif() {
  getswitchinfo
  echo "NB: This is a pretty bad hack, and will continue rapidly flapping the interface until you hit Control-C.  Please also be advised that it might leave the IF in a down state when you do stop it. If that happens either reboot the switch, or login and kill flap.sh (ps aux | grep flap.sh, and kill the PID)"
  (echo "echo \"while true; do ifconfig $ifprefix-0/0/0 down; sleep $delay; ifconfig $ifprefix-0/0/0 up; sleep $delay; done\"> flap.sh"; echo "sh ./flap.sh") | sshpass -proot123 ssh -o StrictHostKeyChecking=no root@$switch_ip sh
}

get_auth_token () {
  authtoken=`curl -s -k --location --request POST "https://$apstraserver/api/user/login" --header 'Content-Type: application/json' --data-raw "{
    \"username\": \"admin\",
    \"password\": \"$apstrapass\"
  }" | awk '{print $2}' | sed s/[\"\,]//g`
  echo "authtoken is $authtoken"
}

get_bp_id() { 
  bp_label_list=`curl -s -k --location --request GET "https://$apstraserver/api/blueprints/" \
    --header "AUTHTOKEN: $authtoken" --header "Content-Type: application/json" \
    | jq -r '.items[].id' | tr '\n' ' ' `
  
  declare -a blueprints
  for bp in $bp_label_list; do
    blueprints+=($bp)
  done

  MENU_OPTIONS=
  COUNT=0
  PS3="Please enter your choice (q to quit): "
  select target in "${blueprints[@]}" "quit"; do
    case "$target" in 
      "quit")
        echo "Exited"
        break
        ;;
      *)
        bp_label=$target
        bpid=`curl -s -k --location --request GET "https://$apstraserver/api/blueprints" \
          --header "AUTHTOKEN: $authtoken" --data-raw "" | \
          jq -r '.items[] | select(.id == '\"$bp_label\"') | .id' `
        echo "ID for $bp_label is $bpid"
        break
        ;;
    esac
  done

}

getswitchinfo() {
  declare -A switches `curl -s -k --location --request POST "https://$apstraserver/api/blueprints/$bpid/qe?type=staging" \
  --header "AUTHTOKEN: $authtoken" --header "Content-Type: application/json" --data-raw "{ \"query\": \"match(node('system', name='system', role=is_in(['leaf', 'access', 'spine', 'superspine'])))\"}" | jq -r '.items[].system | "switches" + "[" + .label + "]" + "=" + .system_id' |tr '\n' ' '`

  MENU_OPTIONS=
  COUNT=0

  PS3="Please enter your choice (q to quit): "
  select target in "${!switches[@]}" "quit";
  do
    case "$target" in
      "quit")
        echo "Exited"
        break
        ;;
      *)
        selected_systemid=${switches["$target"]}
        selected_switch="$target"
	      switch_ip=`curl -k --location --request GET "https://$apstraserver/api/systems/$selected_systemid" --header "AUTHTOKEN: $authtoken" --data-raw "" | jq -r '.facts .mgmt_ipaddr'`
        echo "$selected_switch system id is $selected_systemid and has IP $switch_ip"
	      break
	      ;;
    esac
  done
}

prompt_missing_opts() {
  if [ -z $apstraserver ]; then
    read -p "Server name/IP (optionally ending with :portNumber if not 443): " apstraserver
  fi
  if [ -z $apstrapass ]; then
    read -sp "Password for user 'admin': " apstrapass
    echo \n
  fi
  if [ -z $ifprefix ]; then
    read -p "Interface name prefix (e.g., ge/xe/lt): " ifprefix
  fi
}

rampcpu() {
  getswitchinfo
  echo "NB: This is a pretty bad hack, but should peg the cpu @100% on a vQFX. Hit ^C (Control-C) to stop the pain. Make certain that the Device System Health probe is enabled, and note also that it will take 6 minutes and 1 second to raise an anomaly"
  sshpass -proot123 ssh -o StrictHostKeyChecking=no root@$switch_ip 'dd if=/dev/zero of=/dev/null & ; dd if=/dev/random of=/dev/null & ; dd if=/dev/urandom of=/dev/null &'
}

rebootall() {
  declare -A switches `curl -s -k --location --request POST "https://$apstraserver/api/blueprints/$bpid/qe?type=staging" --header "AUTHTOKEN: $authtoken" --header "Content-Type: application/json" --data-raw "{ \"query\": \"match(node('system', name='system', role=is_in(['leaf', 'access', 'spine', 'superspine'])))\"}" | jq -r '.items[].system | "switches" + "[" + .label + "]" + "=" + .system_id' |tr '\n' ' '`
  for dev in "${switches[@]}"; do
    switch_ip=`curl -k --location --request GET "https://$apstraserver/api/systems/$dev" --header "AUTHTOKEN: $authtoken" --data-raw "" | jq -r '.facts .mgmt_ipaddr'`;
    ( echo 'request system reboot'; echo 'yes'; echo 'quit' ) | sshpass -proot123 ssh -o StrictHostKeyChecking=no root@"$switch_ip" "cli"
    echo $switch_ip
  done
}

savetv() {
  commitversion=`curl -s -k --location --request GET "https://$apstraserver/api/blueprints/$bpid/deploy" --header "AUTHTOKEN: $authtoken" | jq .version --raw-output`
  echo "version is $commitversion"
  sleep 1
  curl -s -k --location --request POST "https://$apstraserver/api/blueprints/$bpid/revisions/$commitversion/keep" --header "AUTHTOKEN: $authtoken" --header "Content-Type: application/json" --data-raw "{ \"description\": \"Saved by Apstra Chaos Cat at `date` \"}"
}

setstaticrt() {
  getswitchinfo 
  (echo 'conf';echo 'set routing-options static route 7.7.7.7/32 next-hop 8.8.8.8';echo 'commit and-quit' ) | sshpass -proot123 ssh -o StrictHostKeyChecking=no root@"$switch_ip" "cli"
}

###
### Script execution begins in earnest here...
###

while getopts ":s:i:p:h" option; do
  case $option in
    s)
      apstraserver="$OPTARG"
      ;;
    i)
      ifprefix="$OPTARG"
      ;;
    p)
      apstrapass="$OPTARG"
      ;;
    *)
      echo "Usage: [chaoscat -s server_name/ip -i interface_name (eg: xe lt ge) -p Apstra_password]"
      exit 1
      ;;
  esac
done

prompt_missing_opts
echo "Interface names use $ifprefix as prefix"
get_auth_token
echo \n; echo "Starting menu in 3 seconds..."
sleep 3

TITLE="How Would You Like to Break Your Environment Today?"
	
items=( 1 "Save Current Blueprint Version"
        2 "Commit Apstra Blueprint"
	      3 "Break Cabling Map"
        4 "Change Blueprint Name"
	      5 "Disable switch Interface $ifprefix-0/0/1"
	      6 "Change the ASN of a device"
	      7 "Add a static route to a device"
        8 "Ramp a device CPU to raise device Health anomaly"
        9 "Flap $ifprefix-0/0/0 on selected device"
	      r "Reboot all junos devices under Apstra management"
        s "Select a blueprint to act on"
      )

while choice=$(dialog --title "$TITLE" \
                 --menu "Please select (current blueprint is $bp_label)" \
                 50 80 12 "${items[@]}" 2>&1 >/dev/tty)
do
  case $choice in
  	1) savetv; sleep 1 ;;
    2) commitcurrent ; sleep 5 ;;
    3) breakcablemap ; sleep 4 ;;
    4) get_bp_id; sleep 3 ;;
    5) disableint ;sleep 4 ;;
    6) changeswasn ; sleep 4 ;;
    7) setstaticrt ; sleep 2 ;;
    8) rampcpu ; ;; 
    9) flapif ; sleep 2 ;;
    r) rebootall ; sleep 3 ;;
    s) get_bp_id ; sleep 3 ;;
     *) ;; 
  esac
done
#clear # clear after user pressed Cancel
