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

while IFS= read -r xss_line ; do

    xss_payload=$(echo "$xss_line" | awk -F "§" '{print $1}')

    xss=$(echo "$xss_line" | awk -F "§" '{print $2}')

        while IFS= read -r xss_target ; do

                xss_url_check=$(echo "$xss_target" | grep "=")

                        if [ -n "$xss_url_check" ] ; then

                        xss_url=$(echo "$xss_url_check" | qsreplace "$xss_payload")

                        echo "Testing $xss_target"

                        xss_resp=$(curl -s "$xss_target")

                                if [[ $? -ne 0 ]] ; then

                                continue

                                fi

                                xss_check_result=$(echo "$xss_resp" | grep -q "$xss")

                                        if [[ $? -eq 0 ]] ; then

                                        echo -e "Possible XSS found: $xss_url" | notify

                                        fi

                        fi

        done < final_links

done < xsspayloads.txt

echo "[+] Testing for SQLi"

echo "Testing for SQLi" | notify

while IFS= read -r sqli_payload ; do

    cat "$filename".txt | qsreplace "$sqli_payload" >> testforsqli.txt

    done < sqlipayloads.txt

    httpx -l testforsqli.txt -mrt '>4' -o sqli_finds.txt

    rm testforsqli.txt

        if [ -e "sqli_finds.txt" ]; then

        echo 'Possible SQL injections found:' | notify

        cat "sqli_finds.txt" | notify

        fi

fi

echo "[+] Testing for LFI"

while IFS= read -r lfi_payload ; do

    while IFS= read -r lfi_target ; do

        lfi_url_check=$( echo "$lfi_target" | grep "=" )

        if [ -n "$lfi_url_check" ] ; then

                lfi_url=$(echo "$lfi_url_check" | qsreplace "$lfi_payload")

        echo "Testing $lfi_url"

        lfi_resp=$(curl -s "$lfi_url")

        if [[ $? -ne 0 ]] ; then

            continue

        fi

        lfi_check_result=$(echo "$lfi_resp" | grep -q "root:x")

        if [[ $? -eq 0 ]] ; then

            echo -e "Possible LFI found: $lfi_url" | notify

        fi

        fi

    done < final_links

done < LFIpayloads.txt

echo "Testing for SSRF" | notify

nuclei -l final_links -t /root/fuzzing-templates/ssrf -o ssrf_finds.txt

    if [ -e "ssrf_finds.txt" ]; then

        echo 'Possible SSRFs found:' | notify

        cat "ssrf_finds.txt" | notify

    fi

fi

echo "Testing for credential exposures" | notify

cat final_links | grep '.js|.php|.json|.asp|.aspx|.config|.env|.cgi' >> sensitive_files

nuclei -l sensitive_files -t /root/nuclei-templates/http/exposures -o sensitive_finds.txt

rm sensitive_files

if [ -e "sensitive_finds.txt" ]; then

        echo 'Possible sensitive data found:' | notify

        cat "sensitive_finds.txt" | notify

    fi

rm final_links

echo "[+] Midnight is done" | notify
