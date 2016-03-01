@echo off
php -r "$ch = curl_init('http://documentup.com/compiled');curl_setopt($ch, CURLOPT_POSTFIELDS, (isset($argv[2])?'theme='.$argv[2].'&':'').'name=Ragnarok Act&content='.urlencode(file_get_contents($argv[1])));curl_exec($ch);curl_close($ch);" act.md %1 > index.html
start index.html