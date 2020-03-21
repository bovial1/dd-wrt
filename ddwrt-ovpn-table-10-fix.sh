#!/bin/sh
#export DEBUG= # uncomment/comment to enable/disable debug mode
# ---------------------------------------------------------------------------- #
# ddwrt-ovpn-table-10-fix.sh: v2.0.0, 28 February 2017, by eibgrad
# bug report: http://svn.dd-wrt.com/ticket/5690
# install this script in the dd-wrt startup script
# ---------------------------------------------------------------------------- #
 
SCRIPT_DIR="/tmp"
SCRIPT="$SCRIPT_DIR/ddwrt-ovpn-table-10-fix.sh"
mkdir -p $SCRIPT_DIR
 
cat << "EOF" > $SCRIPT
#!/bin/sh
(
[ "${DEBUG+x}" ] && set -x
 
MAX_PASS=0 # max number of passes through routing tables (0=infinite)
SLEEP=60 # time (in secs) between each pass
 
# ---------------------- DO NOT CHANGE BELOW THIS LINE ----------------------- #
 
TID="10"
ROUTES="/tmp/tmp.$$.routes"
 
# initialize this run
pass_count=0
 
while :; do
    # initialize this pass
    pass_count=$((pass_count + 1))
    table_changed=false
 
    # wait for creation of OpenVPN client alternate routing table
    while [ ! "$(ip route show table $TID)" ]; do sleep 10; done; sleep 3
 
    echo "$(ip route show | \
       grep -Ev '^default|^0.0.0.0/1|^128.0.0.0/1')" > $ROUTES
 
    # add routes to pbr found in main routing table
    while read route; do
        if ! ip route show table $TID | grep -q "$route"; then
            ip route add $route table $TID && table_changed=true
        fi
    done < $ROUTES
 
    echo "$(ip route show table $TID | grep -Ev '^default')" > $ROUTES
 
    # remove routes from pbr not found in main routing table
    while read route; do
        if ! ip route show | grep -q "$route"; then
            ip route del $route table $TID && table_changed=true
        fi
    done < $ROUTES
 
    # force routing system to recognize our changes
    if $table_changed == true; then 
       ip rule add to 208.85.40.0/21 table $TID
       ip route flush cache
    fi
       
    # quit if we've reached any execution limits
    [ $MAX_PASS -gt 0 ] && [ $pass_count -ge $MAX_PASS ] && break
 
    # put it bed for a while
    [ $SLEEP -gt 0 ] && sleep $SLEEP
done
 
# cleanup
rm -f $ROUTES
 
echo "done"
exit 0
 
) 2>&1 | logger -t $(basename $0)[$$]
EOF
 
chmod +x $SCRIPT
nohup $SCRIPT > /dev/null 2>&1 &
