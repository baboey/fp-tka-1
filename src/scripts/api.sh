#! /bin/sh

product=$(( RANDOM % 100 ))
quantity=$(( RANDOM % 10 ))
price=$(( (RANDOM<<1) | RANDOM ))

case "$1" in
    "c") #create
        curl --header "Content-Type: application/json" \
          --request POST \
          --data '{ "product":"'$product'", "quantity":'$quantity', "price":'$price' }' \
          http://localhost:80/order
        ;;

esac
