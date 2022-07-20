#!/bin/bash



http_conf='/etc/httpd/conf/httpd.conf'
http_backup_dir='/root/BACKUP/famoc/httpd'

fpm_conf='/etc/php-fpm.d/www.conf'
fpm_backup_dir='/root/BACKUP/famoc/php-fpm'

backups_to_display=10

mkdir -p $http_backup_dir
mkdir -p $fpm_backup_dir


RED='\033[0;31m'
GRE='\033[0;32m' 
NC='\033[0m'

if [ "$EUID" -ne 0 ] ; then
  echo -e "${RED}Please run as root${NC}"
  exit
fi

getFileNameFromDate() {
    echo $1$(date +%Y-%m-%d_%H-%M.%S)
    }


drawMenu() {

echo -e "${GRE}\nFACTS:
httpd config file = $http_conf\t\tphp-fpm config file = $fpm_conf                  
httpd backup directory =  $http_backup_dir\t\tfpm backup directory = $fpm_backup_dir
              
${NC}
                            ESC - print this menu
                            p - show processes count and memory stats
                            m - mysqld basic stats
                            a - Apache fullstatus
                            s - set file limit for operation 3&4 ($backups_to_display)
                            = - status of httpd and php-fpm service
                            
                            q - quit" 
                            

echo -e  "
1 - backup & edit httpd.conf (httpd)                2 - backup & edit www.conf (php-fpm)
3 - view/restore previous httpd.conf (httpd)        4 - view/restore previous www.conf (php-fpm)"
echo -e "${RED}
h - apply httpd config (httpd reload)               f - apply php-fpm config (php-fpm reload)
H - apply httpd config (httpd RESTART)              F - apply php-fpm config (php-fpm RESTART)
${NC}
"
}

doBackup() {

    if [[ $1 == $http_conf ]] ; then
        
        backup_dest="$http_backup_dir/$(getFileNameFromDate 'httpd.conf_')"
        printf "\nBACKUP: WORKING WITH ${RED} Apache httpd.conf${NC}\n"

    elif [[ $1 == $fpm_conf ]] ; then

        backup_dest="$fpm_backup_dir/$(getFileNameFromDate 'www.conf_')"
        printf "\nBACKUP: WORKING WITH ${RED} php-fpm www.conf${NC}\n"
    else
        echo "${RED}Some serious problem with doBackup function!"
    fi

    printf "backing up $1 to $backup_dest"       
    cp $1 $backup_dest
    printf "...done\n"
    
    printf "editing $1 ..."
    vi $1
    printf "done\n"

}

doRestore () {
    
    if [[ $1 == $http_conf ]] ; then
        
        backup_src="$http_backup_dir"
        printf "\nRESTORE: WORKING WITH ${RED} Apache httpd.conf${NC}\n"

    elif [[ $1 == $fpm_conf ]] ; then

        backup_src="$fpm_backup_dir"
        printf "\nRESTORE: WORKING WITH ${RED} php-fpm www.conf${NC}\n"

    else
        echo "${RED}Some serious problem with doRestore function!"
    fi    

    printf "\nLast $backups_to_display backup files (newest) for $backup_src:\n"
    declare -a dir
    IFS=$'\n'
    dir=($( ls -t $backup_src | head -n $backups_to_display))
    
    for (( f=0; f<${#dir[@]}; f++ )); do
        echo -e "$f:\t"${dir[f]}
    done    

    printf "\nv:x - ${RED}view${NC} entry x (ie v:3 to display entry 3)\nr:x - ${RED}restore${NC} entry x (ie r:1 to restore entry 1)\nq - exit\n"

    while :
    do
        printf "#: " ; read command
        action=$(echo $command | cut -d":" -f1)
        value=$(echo $command | cut -d":" -f2)

        if [[ $action == 'q' ]] ; then
            drawMenu
            break
        elif [[ $action == 'v' ]] ; then
            printf  "displaying entry $value - $backup_src/${dir[$value]}\n"
            less $backup_src/${dir[$value]}
        elif [[ $action == 'r' ]] ; then
        printf  "${RED}restoring entry${NC} $value - $backup_src/${dir[$value]}\n"
        cp $backup_src/${dir[$value]} $1 || echo "${RED}WRONG entry!${NC}"
        fi
    done

}

systemCtl() {
    printf "\n${RED}$2 $1${NC}..."
    systemctl $1 $2
    printf "done\n"
    systemctl status $2


}

clear
drawMenu

while : ; do
    read -rsn1 key

        case "$key" in
    
            "1") 
                
                doBackup $http_conf
                ;;

            "2")
                doBackup $fpm_conf
                ;;

            "3")
                doRestore $http_conf
                ;;
            
            "4")
                doRestore $fpm_conf
                ;;

            "h") 
                systemCtl reload httpd
                ;;

            "H") 
                systemCtl restart httpd
                ;;

            "f") 
                systemCtl reload php-fpm
                ;;

            "F") 
                systemCtl restart php-fpm
                ;;

            "p")
                printf "${GRE}Processes: ${NC}\n"
                for f in {"php-fpm","httpd","mysql"} ; do printf $f": "; ps -eLf | grep -c $f ; done
                printf "${GRE}memory: ${NC}\n"
                free -h
                ;;

            "m")
                printf "${GRE}mysqld stats: ${NC}\n"
                mysqladmin stat
                ;;

            "a")
                apachectl fullstatus
                ;;

            "s")
                printf "\nnew limit: "
                read backups_to_display
                ;;

            "=")
                systemctl status php-fpm httpd
                ;;

            "q")
                exit 0
                ;;

            $'\e')
                drawMenu
                ;;

            *)
                
                ;;
        esac
done
