#! /bin/sh

product=$(( RANDOM % 100))
quantity=$(( RANDOM % 10 ))
price=$(( (RANDOM<<1) | RANDOM ))

case "$1" in
    "c") #create
        curl --header "Content-Type: application/json" \
          --request POST \
          --data '{ "product":"'$product'", "quantity":'$quantity', "price":'$price' }' \
          http://localhost:80/order
        ;;

    "u") #update
        curl --header "Content-Type: application/json" \
          --request PUT \
          --data '{ "status":"complete"}' \
          http://localhost:80/order/$2
        ;;

    "g") #get
        curl --request GET \
          http://localhost:80/order/$2
        ;;

    "p") #get all
        curl --request GET \
          http://localhost:80/orders
        ;;

    *)
        echo -e "Usage:
        c            - create
        u <order_id> - update
        g <order_id> - get one
        p            - print all"

esac
