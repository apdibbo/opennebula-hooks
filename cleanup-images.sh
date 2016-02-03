#!/bin/bash
pool="cloud-dev"
user="cloud-dev"
daystokeep=7
now=$(date +%s)
secondstokeep=$daystokeep*24*60*60
#get list of rbd images
if [ -z "${ONE_LOCATION}" ]; then
    TMCOMMON=/var/lib/one/remotes/tm/tm_common.sh
else
    TMCOMMON=$ONE_LOCATION/var/remotes/tm/tm_common.sh
fi

DRIVER_PATH=$(dirname $0)

source $TMCOMMON
RBD="rbd --user $user"
list=`$RBD ls $pool | sort -r`


 rm_children(){
        local rbd_snap rbd snap_id child snap_list

        rbd_snap=$1
        rbd=${rbd_snap%%@*}

        snap_list=$(set +e; rbd snap ls \$rbd)

        if [ -n "$snap_list" ]; then
            CHILDREN=$(set +e; rbd children \$rbd_snap 2>/dev/null)

            for child in $CHILDREN; do
                snap_id=${child##*-}
                child=$child@$snap_id
                rm_children $child
            done

            $RBD snap unprotect $rbd_snap
            $RBD snap rm $rbd_snap
        fi

        $RBD rm $rbd
    }


while read -r line; do
#check if images should be removed
    if [[ $line =~ one-([0-9]*) ]]; then
        imageid="${BASH_REMATCH[1]}"

        if [[ $line =~ one-[0-9]*-([0-9]*)-([0-9]*) ]]; then
            vmid="${BASH_REMATCH[1]}"
            diskid="${BASH_REMATCH[2]}"
            vmshow=`onevm show -x $vmid`
            state=`echo -e  "$vmshow" | grep "<STATE>" | sed "s/<STATE>//g" | sed "s/<\/STATE>//g" `
            etimearr=`echo -e "$vmshow" | grep "<ETIME>" | sed "s/<ETIME>//g" | sed "s/<\/ETIME>//g"`
            etime=0
            while  read -r time; do
                if [[ "$time" -gt "$etime" ]] ; then
                    etime=$time;
                fi
            done <<< "$etimearr"
            if [[ $line =~ one-[0-9]*-[0-9]*-[0-9]*-([0-9]*) ]]; then
                snapshotid="${BASH_REMATCH[1]}"
            fi
            deletetime=$(( $etime+$secondstokeep ))
            if [[ "$state" =~ 6 ]]; then
                if [[ "$now" -gt "$deletetime" ]] ; then
                    tbd="$pool/$line"
                    RBD_FORMAT=$($RBD info $RBD_SRC | sed -n 's/.*format: // p')
                    RBD_SRC=$tbd
                    if [ "$RBD_FORMAT" = "2" ]; then
                        has_snap_shots=$($RBD info $RBD_SRC-0@0 2>/dev/null)

                        if [ -n "$has_snap_shots" ]; then
                            rm_children $RBD_SRC-0@0
                        else
                            $RBD rm $RBD_SRC
                        fi
                    else
                        $RBD rm $RBD_SRC
                    fi

                    # Remove the snapshot of the original image used to create a CLONE
                    if [ "$RBD_FORMAT" = "2" ]; then
                        $RBD snap unprotect $SRC@$RBD_SNAP
                        $RBD snap rm $SRC@$RBD_SNAP
                    fi

                fi
            fi
        fi
    fi
done <<< "$list"

