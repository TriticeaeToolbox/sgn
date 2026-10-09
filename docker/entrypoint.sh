#!/bin/bash
/etc/init.d/postfix start
/etc/init.d/cron start
#/etc/init.d/postgres start

# start the job backend configured in sgn_local.conf ("backend Tsp" or "backend Slurm")
#
JOB_BACKEND=$(awk 'tolower($1) == "backend" { b = tolower($2) } END { print b }' /home/production/cxgn/sgn/sgn.conf /home/production/cxgn/sgn/sgn_local.conf)

if [ "$JOB_BACKEND" = "tsp" ] && ! command -v tsp > /dev/null; then
    echo "ERROR: backend Tsp is configured in sgn_local.conf, but tsp is not installed (Debian package task-spooler). Background jobs will fail."
elif [ "$JOB_BACKEND" = "tsp" ]; then
    # task-spooler. The tsp server uses the default per-user socket unless
    # TS_SOCKET is set (in the container environment, so that docker exec
    # shells and scripts talk to the same server); TS_MAXFINISHED is the
    # number of finished jobs it keeps track of.
    export TS_MAXFINISHED=${TS_MAXFINISHED:-10000}
    TSP_SLOTS=${TSP_SLOTS:-$(( $(nproc) > 1 ? $(nproc) / 2 : 1 ))}
    tsp -S $TSP_SLOTS
    # tsp job ids start at 0, which is false in Perl; use up id 0
    tsp -L reserved-job-id true > /dev/null
    echo "Started task-spooler with $TSP_SLOTS slots"
    if [ -n "$BB_JOB_PODMAN_URL" ]; then
        echo "Jobs will run in podman containers via $BB_JOB_PODMAN_URL"
    fi
else
    sed -i s/localhost/$HOSTNAME/g /etc/slurm/slurm.conf
    chown munge /etc/munge/munge.key
    /etc/init.d/munge start
    /etc/init.d/slurmctld start
    /etc/init.d/slurmd start

    # undrain node if needed
    #
    scontrol update NodeName=$HOSTNAME State=RESUME
fi

chown root /etc/crontab # in case it was mounted from local dir

if [ "${MODE}" = 'TESTING' ]; then
    exec perl t/test_fixture.pl --carpalways -v "${@}"
fi

# Fix file permissions
/usr/local/bin/fix_file_permissions

# Set Git Info
/usr/local/bin/set_git_info

# Fix Bio::Chado::Schema unfound in INC problem
ln -s /home/production/cxgn/Bio-Chado-Schema/lib/Bio/Chado /home/production/cxgn/local-lib/lib/perl5/Bio/Chado

if [ "$MODE" == "DEVELOPMENT" ]; then
    perl /home/production/cxgn/sgn/bin/sgn_server.pl --fork -r -p 8080
else
    /etc/init.d/sgn start
    touch /var/log/sgn/error.log
    chmod 777 /var/log/sgn/error.log
    tail -f /var/log/sgn/error.log
fi
