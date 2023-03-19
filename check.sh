#!/bin/sh

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
SKYBLUE='\033[0;36m'
PLAIN='\033[0m'
BrowserUA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/99.0.4844.74 Safari/537.36"

function Next() {
    printf "%-60s\n" "-" | sed 's/\s/-/g'
}

function About() {
	echo ""
	echo " ========================================================= "
	echo " \                 Check.sh  Script                      / "
	echo " \                 v1.0.0 (2023-03-19)                   / "
	echo " \                 https://1024.day                      / "
	echo " ========================================================= "
	echo ""
	echo ""
}

function Install_oth(){
    if [ -f "/usr/bin/apt-get" ]; then
        apt-get update -y
        apt-get install -y wget curl tar unzip
    else
        yum update -y
        yum install -y epel-release
        yum install -y wget curl tar unzip
    fi
}

function UnlockNetflixTest() {
    local result1=$(curl --user-agent "${BrowserUA}" -fsL --write-out %{http_code} --output /dev/null --max-time 10 "https://www.netflix.com/title/81280792" 2>&1)
	
    if [[ "$result1" == "404" ]];then
        echo -e " Netflix              : ${YELLOW}Originals Only${PLAIN}" | tee -a $log
	elif  [[ "$result1" == "403" ]];then
        echo -e " Netflix              : ${RED}No${PLAIN}" | tee -a $log
	elif [[ "$result1" == "200" ]];then
		local region=`tr [:lower:] [:upper:] <<< $(curl --user-agent "${BrowserUA}" -fs --max-time 10 --write-out %{redirect_url} --output /dev/null "https://www.netflix.com/title/80018499" | cut -d '/' -f4 | cut -d '-' -f1)` ;
		if [[ ! -n "$region" ]];then
			region="US";
		fi
		echo -e " Netflix              : ${GREEN}Yes (Region: ${region})${PLAIN}" | tee -a $log
	elif  [[ "$result1" == "000" ]];then
		echo -e " Netflix              : ${RED}Network connection failed${PLAIN}" | tee -a $log
    fi   
}

function UnlockYouTubePremiumTest() {
    local tmpresult=$(curl --max-time 10 -sS -H "Accept-Language: en" "https://www.youtube.com/premium" 2>&1 )
    local region=$(curl --user-agent "${BrowserUA}" -sL --max-time 10 "https://www.youtube.com/premium" | grep "countryCode" | sed 's/.*"countryCode"//' | cut -f2 -d'"')
	if [ -n "$region" ]; then
        sleep 0
	else
		isCN=$(echo $tmpresult | grep 'www.google.cn')
		if [ -n "$isCN" ]; then
			region=CN
		else	
			region=US
		fi	
	fi	
	
    if [[ "$tmpresult" == "curl"* ]];then
        echo -e " YouTube Premium      : ${RED}Network connection failed${PLAIN}"  | tee -a $log
        return;
    fi
    
    local result=$(echo $tmpresult | grep 'Premium is not available in your country')
    if [ -n "$result" ]; then
        echo -e " YouTube Premium      : ${RED}No${PLAIN} ${PLAIN}${GREEN} (Region: $region)${PLAIN}" | tee -a $log
        return;
		
    fi
    local result=$(echo $tmpresult | grep 'YouTube and YouTube Music ad-free')
    if [ -n "$result" ]; then
        echo -e " YouTube Premium      : ${GREEN}Yes (Region: $region)${PLAIN}" | tee -a $log
        return;
	else
		echo -e " YouTube Premium      : ${RED}Failed${PLAIN}" | tee -a $log
    fi
}

function YouTubeCDNTest() {
	local tmpresult=$(curl -sS --max-time 10 https://redirector.googlevideo.com/report_mapping 2>&1)    
    if [[ "$tmpresult" == "curl"* ]];then
        echo -e " YouTube Region       : ${RED}Network connection failed${PLAIN}" | tee -a $log
        return;
    fi
	iata=$(echo $tmpresult | grep router | cut -f2 -d'"' | cut -f2 -d"." | sed 's/.\{2\}$//' | tr [:lower:] [:upper:])
	checkfailed=$(echo $tmpresult | grep "=>")
	if [ -z "$iata" ] && [ -n "$checkfailed" ];then
		CDN_ISP=$(echo $checkfailed | awk '{print $3}' | cut -f1 -d"-" | tr [:lower:] [:upper:])
		echo -e " YouTube CDN          : ${YELLOW}Associated with $CDN_ISP${PLAIN}" | tee -a $log
		return;
	elif [ -n "$iata" ];then
		curl $useNIC -s --max-time 10 "https://www.iata.org/AirportCodesSearch/Search?currentBlock=314384&currentPage=12572&airport.search=${iata}" > ~/iata.txt
		local line=$(cat ~/iata.txt | grep -n "<td>"$iata | awk '{print $1}' | cut -f1 -d":")
		local nline=$(expr $line - 2)
		local location=$(cat ~/iata.txt | awk NR==${nline} | sed 's/.*<td>//' | cut -f1 -d"<")
		echo -e " YouTube CDN          : ${GREEN}$location${PLAIN}" | tee -a $log
		rm ~/iata.txt
		return;
	else
		echo -e " YouTube CDN          : ${RED}Undetectable${PLAIN}" | tee -a $log
		rm ~/iata.txt
		return;
	fi
	
}

function UnlockBilibiliTest() {
	#Test Mainland
    local randsession="$(cat /dev/urandom | head -n 32 | md5sum | head -c 32)";
    local result=$(curl --user-agent "${BrowserUA}" -fsSL --max-time 10 "https://api.bilibili.com/pgc/player/web/playurl?avid=82846771&qn=0&type=&otype=json&ep_id=307247&fourk=1&fnver=0&fnval=16&session=${randsession}&module=bangumi" 2>&1);
	if [[ "$result" != "curl"* ]]; then
        result="$(echo "${result}" | grep '"code"' | awk -F 'code":' '{print $2}' | awk -F ',' '{print $1}')";
        if [ "${result}" = "0" ]; then
            echo -e " BiliBili China       : ${GREEN}Yes (Region: Mainland Only)${PLAIN}" | tee -a $log
			return;
        fi
    else
        echo -e " BiliBili China       : ${RED}Network connection failed${PLAIN}" | tee -a $log
		return;
    fi
	
	#Test Hongkong/Macau/Taiwan
	randsession="$(cat /dev/urandom | head -n 32 | md5sum | head -c 32)";
	result=$(curl --user-agent "${BrowserUA}" -fsSL --max-time 10 "https://api.bilibili.com/pgc/player/web/playurl?avid=18281381&cid=29892777&qn=0&type=&otype=json&ep_id=183799&fourk=1&fnver=0&fnval=16&session=${randsession}&module=bangumi" 2>&1);
    if [[ "$result" != "curl"* ]]; then
        result="$(echo "${result}" | grep '"code"' | awk -F 'code":' '{print $2}' | awk -F ',' '{print $1}')";
        if [ "${result}" = "0" ]; then
            echo -e " BiliBili China       : ${GREEN}Yes (Region: HongKong/Macau/Taiwan Only)${PLAIN}" | tee -a $log
			return;
        fi
    else
        echo -e " BiliBili China       : ${RED}Network connection failed${PLAIN}" | tee -a $log
		return;
    fi
	
	#Test Taiwan
	randsession="$(cat /dev/urandom | head -n 32 | md5sum | head -c 32)";
	result=$(curl --user-agent "${BrowserUA}" -fsSL --max-time 10 "https://api.bilibili.com/pgc/player/web/playurl?avid=50762638&cid=100279344&qn=0&type=&otype=json&ep_id=268176&fourk=1&fnver=0&fnval=16&session=${randsession}&module=bangumi" 2>&1);
	if [[ "$result" != "curl"* ]]; then
		result="$(echo "${result}" | grep '"code"' | awk -F 'code":' '{print $2}' | awk -F ',' '{print $1}')";
		if [ "${result}" = "0" ]; then
            echo -e " BiliBili China       : ${GREEN}Yes (Region: Taiwan Only)${PLAIN}" | tee -a $log
			return;
		fi
	else
		echo -e " BiliBili China       : ${RED}Network connection failed${PLAIN}" | tee -a $log
		return;
	fi
	echo -e " BiliBili China       : ${RED}No${PLAIN}" | tee -a $log
}

function UnlockTiktokTest() {
	local result=$(curl --user-agent "${BrowserUA}" -fsSL --max-time 10 "https://www.tiktok.com/" 2>&1);
    if [[ "$result" != "curl"* ]]; then
        result="$(echo ${result} | grep 'region' | awk -F 'region":"' '{print $2}' | awk -F '"' '{print $1}')";
		if [ -n "$result" ]; then
			if [[ "$result" == "The #TikTokTraditions"* ]] || [[ "$result" == "This LIVE isn't available"* ]]; then
				echo -e " TikTok               : ${RED}No${PLAIN}" | tee -a $log
			else
				echo -e " TikTok               : ${GREEN}Yes (Region: ${result})${PLAIN}" | tee -a $log
			fi
		else
			echo -e " TikTok               : ${RED}Failed${PLAIN}" | tee -a $log
			return
		fi
    else
		echo -e " TikTok               : ${RED}Network connection failed${PLAIN}" | tee -a $log
	fi
}

function UnlockiQiyiIntlTest() {
	curl --user-agent "${BrowserUA}" -s -I --max-time 10 "https://www.iq.com/" >/tmp/iqiyi
    if [ $? -eq 1 ]; then
        echo -e " iQIYI International  : ${RED}Network connection failed${PLAIN}" | tee -a $log
        return
    fi

    local result="$(cat /tmp/iqiyi | grep 'mod=' | awk '{print $2}' | cut -f2 -d'=' | cut -f1 -d';')";
	rm -f /tmp/iqiyi

    if [ -n "$result" ]; then
        if [[ "$result" == "ntw" ]]; then
            result=TW
            echo -e " iQIYI International  : ${GREEN}Yes (Region: ${result})${PLAIN}" | tee -a $log
            return
        else
            result=$(echo $result | tr [:lower:] [:upper:])
            echo -e " iQIYI International  : ${GREEN}Yes (Region: ${result})${PLAIN}" | tee -a $log
            return
        fi
    else
        echo -e " iQIYI International  : ${RED}Failed${PLAIN}" | tee -a $log
        return
    fi
}

function UnlockChatGPTTest() {
	if [[ $(curl --max-time 10 -sS https://chat.openai.com/ -I | grep "text/plain") != "" ]]
	then
        echo -e " ChatGPT              : ${RED}IP is BLOCKED${PLAIN}" | tee -a $log
        return
	fi
    local countryCode="$(curl --max-time 10 -sS https://chat.openai.com/cdn-cgi/trace | grep "loc=" | awk -F= '{print $2}')";
	if [ $? -eq 1 ]; then
        echo -e " ChatGPT              : ${RED}Network connection failed${PLAIN}" | tee -a $log
        return
    fi
	if [ -n "$countryCode" ]; then
        support_countryCodes=(T1 XX AL DZ AD AO AG AR AM AU AT AZ BS BD BB BE BZ BJ BT BA BW BR BG BF CV CA CL CO KM CR HR CY DK DJ DM DO EC SV EE FJ FI FR GA GM GE DE GH GR GD GT GN GW GY HT HN HU IS IN ID IQ IE IL IT JM JP JO KZ KE KI KW KG LV LB LS LR LI LT LU MG MW MY MV ML MT MH MR MU MX MC MN ME MA MZ MM NA NR NP NL NZ NI NE NG MK NO OM PK PW PA PG PE PH PL PT QA RO RW KN LC VC WS SM ST SN RS SC SL SG SK SI SB ZA ES LK SR SE CH TH TG TO TT TN TR TV UG AE US UY VU ZM BO BN CG CZ VA FM MD PS KR TW TZ TL GB)
		if [[ "${support_countryCodes[@]}"  =~ "${countryCode}" ]];  then
            echo -e " ChatGPT              : ${GREEN}Yes (Region: ${countryCode})${PLAIN}" | tee -a $log
            return
        else
			echo -e " ChatGPT              : ${RED}No${PLAIN}" | tee -a $log
            return
        fi
    else
        echo -e " ChatGPT              : ${RED}Failed${PLAIN}" | tee -a $log
        return
    fi
}


function StreamingMediaUnlockTest(){
    Install_oth
    clear
    About
	UnlockNetflixTest
	UnlockYouTubePremiumTest
	YouTubeCDNTest
	UnlockBilibiliTest
	UnlockTiktokTest
	UnlockiQiyiIntlTest
	UnlockChatGPTTest
}

StreamingMediaUnlockTest
Next
