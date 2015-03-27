#
yum -y install nginx
chkconfig nginx on

mkdir /var/log/httpd
cd /etc/nginx
curl https://raw.githubusercontent.com/torumaki/config/master/nginx/nginx.conf -o nginx.conf

service nginx start
