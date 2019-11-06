#!/bin/bash 

#auto install mysql5.7.10
   
#setting default directory
Port=$1
SoftDir="/data/software/"
tarbag="mysql-5.7.27-1.el7.x86_64.rpm-bundle.tar"   
BaseDir="/data/mysql_install/$Port/"
DataDir="/data/$Port"
   
#remove before being installed mysql
function rmMysql() {
        yum -y erase mysql >/dev/null 2>&1
        yum -y erase mysql-server >/dev/null 2>&1
        ret=`rpm -aq | grep -i "mysql-5" | wc -l`
        num=`rpm -aq | grep -i "mysql-server" | wc -l`
        test $ret -eq 1 && echo "mysql uninstall failed" && exit 1
        test $num -eq 1 &&  echo "mysql-server uninstall failed" && exit 2
}
#libaio package is needed for mysql5.7.10
function chkEnv() {
        yum -y install libaio >/dev/null 2>&1
        res=`rpm -aq|grep libaio | wc -l`
        test $res -ne 1 && echo "libaio package install failed..." && exit 3
}
   
#create mysql user and group, authorization, extract
function preInstall() {
        /usr/sbin/groupadd mysql
        /usr/sbin/useradd -r -g mysql -s /bin/false mysql
        mkdir -p $BaseDir
        mkdir -p $DataDir/data
        chown mysql.mysql $DataDir
        if test -f $SoftDir/$tarbag.tar.gz
          then
                cd $SoftDir && tar -zxf $tarbag.tar.gz
                cd $SoftDir/$tarbag && cp -r * $BaseDir
          else
                echo "$tarbag.tar.gz is not found..."
                exit 10
        fi
}
   
function multPreInstall() {
    mkdir -p $DataDir/data
        chown mysql.mysql $DataDir
}
   
function install_mysql() {
        #initialize mysql database
        $BaseDir/bin/mysqld \
        --initialize \
        --user=mysql \
        --basedir=$BaseDir \
        --datadir=$DataDir/data \
        --character-set-server=utf8 \
        --collation-server=utf8_general_ci \
        --initialize-insecure >/dev/null 2>&1
}
#get my.cnf and start/stop script, attention alter parameters by your envionment
function conf_mysql() {
        cp $SoftDir/my.cnf $DataDir
        cp $SoftDir/mysql.server $DataDir
/usr/bin/vim $DataDir/my.cnf<<EOF >/dev/null 2>&1
:%s/3306/$Port/g
:wq
EOF
        sed -i "s/port=3306/port=$Port/" $DataDir/mysql.server
        sed -i "s%CmdPath=\"\"%CmdPath=\"${BaseDir}\/bin\"%" $DataDir/mysql.server
        sed -i "s%mysql_sock=\"\"%mysql_sock=\"${DataDir}\/mysql.sock\"%" $DataDir/mysql.server
        chmod 600 $DataDir/my.cnf
        chmod 700 $DataDir/mysql.server
        $DataDir/mysql.server start >/dev/null 2>&1
        sleep 3
#        ren=`netstat -natp|grep mysqld | grep "$1" | wc -l`
       
        if test -e $DataDir/mysql.sock;then
        echo "$DataDir/mysql.sock"
                echo -e "\033[33;1mmysql install success...\033[0m"
        pro=`grep $BaseDir /root/.bash_profile | wc -l`
        if test "$pro" -ne 1;then
            sed -i "s%PATH=\$PATH\:\$HOME\/bin%PATH=\$PATH\:\$HOME\/bin\:$BaseDir\/bin%" /root/.bash_profile
            source /root/.bash_profile
                fi
        else
                echo -e "\033[31;1mmysql install failed...\033[0m"
        fi
}
   
if [[ "$1" =~ ^[0-9]+$ ]]; then
   # inPort=`netstat -natp | grep "mysqld" | grep "LISTEN" | awk '{print $4}' | cut -b 9-`
   inPort=`ss -antp  | grep mysqld |awk '{print $4}' |awk -F':' '{print $2}'`
   if test ! -z "$inPort";then
       for myPort in $inPort
       do
           if test "$myPort" -eq "$1";then
               echo -e "\033[33;1m$1 instance has already existed...\033[0m"
               exit 1
           fi
       done
       echo -e "\033[32;1m===========================================\033[0m"
       echo -e "\033[32;1mStarting create new instance $1\033[0m"
       multPreInstall
       install_mysql
       echo -e "\033[32;1m===========================================\033[0m"
       echo -e "\033[32;1mconfiguration and starting $1 instance...\033[0m"
       conf_mysql
   else
       echo -e "\033[32;1m===========================================\033[0m"
       echo -e "\033[32;1mremove before being installed mysql...\033[0m"
       rmMysql
       echo -e "\033[32;1m===========================================\033[0m"
       echo -e "\033[32;1minstall libaio package...\033[0m"
       chkEnv
       echo -e "\033[32;1m===========================================\033[0m"
       echo -e "\033[32;1mget ready install envionment...\033[0m"  
       preInstall
       echo -e "\033[32;1m===========================================\033[0m"
       echo -e "\033[32;1mStarting install mysql ver5.7.10...\033[0m"
       install_mysql
       echo -e "\033[32;1m===========================================\033[0m"
       echo -e "\033[32;1mconfiguration mysql and starting mysql...\033[0m"
       conf_mysql
   fi
else
   echo "Usage: $0 Port (Port is inteager)"
fi
