#!/bin/bash
sed -i s/localhost/$HOSTNAME/g /etc/slurm/slurm.conf
/etc/init.d/nginx start
/etc/init.d/postfix start
/etc/init.d/cron start
chown munge /etc/munge/munge.key
/etc/init.d/munge start
/etc/init.d/slurmctld start
/etc/init.d/slurmd start


# undrain node if needed
#
scontrol update NodeName=node_name State=RESUME

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
    perl /home/production/cxgn/sgn/bin/sgn_server.pl --fork -r -d -p 8080
else
    /etc/init.d/sgn start
    chmod 777 /var/log/sgn/error.log
    tail -f /var/log/sgn/error.log
fi
