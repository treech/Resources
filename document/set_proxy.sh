#!/bin/bash
echo 'Please choose your operation:'
echo '1: add git http proxy'
echo '2: delete git http proxy'
read num

proxy(){
    if [[ 1 == $num ]]; then
        git config --global http.proxy https://127.0.0.1:1080
        git config --global https.proxy http://127.0.0.1:1080
        return 1
    elif [[ 2 == $num ]]; then
        git config --global --unset http.proxy
        git config --global --unset https.proxy
        return 2
    fi
}

proxy

if [ 1 == $? ]; then
	echo "git proxy was setted!"
else
    echo 'git proxy was deleted!'
fi

echo 'final proxy info'	
	git config --global --get http.proxy
	git config --global --get https.proxy