#!/usr/local/bin/bash
mysql=/usr/local/bin/mysql # path to mysql
MYSQL_HOST="localhost"
MYSQL_PORT="3306"
MYSQL_PASS=/root/.my.cnf # path to password file mysql
http_ok () {
echo -e "HTTP/1.1 200 OK\r\n"
echo -e "Content-Type: Content-Type: text/plain\r\n"
echo -e "\r\n"
echo -e "$1"
echo -e "\r\n"
}

http_no_access () {
echo -e "HTTP/1.1 503 Service Unavailable\r\n"
echo -e "Content-Type: Content-Type: text/plain\r\n"
echo -e "\r\n"
echo -e "$1"
echo -e "\r\n"
}
MYSQL_INSTANCE=`service mysql-server status | grep -o not`
if [ "$MYSQL_INSTANCE" = 'not' ]; then
    http_no_access "MySQL instance is reported not running.\r\n"
    exit 
fi

status_query () {
  SQL_QUERY=`$mysql --defaults-extra-file=$MYSQL_PASS --silent --raw -N -e "$1"`
  RESULT=`echo $SQL_QUERY|cut -d ' ' -f 2` # just remove the value label
  echo $RESULT
}

GALERA_STATUS=$(status_query "SHOW STATUS LIKE 'wsrep_local_state_comment';" 2>/dev/null)

SST_METHOD=$(status_query "SHOW VARIABLES LIKE 'wsrep_sst_method';" 2>/dev/null)

MYSQL_READONLY=$(status_query "SELECT @@global.read_only;" 2>/dev/null)

if [ "$GALERA_STATUS" == "Synced" ]; then
  if [ "$MYSQL_READONLY" -eq 0 ]; then
     http_ok "Galera status is $GALERA_STATUS\r\n"
  else
     http_no_access "Galera status is $GALERA_STATUS but the local MySQL instance is reported to be read-only.\r\n"
  fi
elif [ "$GALERA_STATUS" == "Donor" ]; then # node is acting as 'Donor' for another node
  if [ "$SST_METHOD" == "xtrabackup" ] || [ "$SST_METHOD" == "xtrabackup-v2" ]; then
     http_ok "Galera status is $GALERA_STATUS.\r\n" # xtrabackup is a non-blocking method
  else
     http_no_access "Galera status is $GALERA_STATUS.\r\n"
  fi
else
  http_no_access "Galera status is $GALERA_STATUS.\r\n"
fi

