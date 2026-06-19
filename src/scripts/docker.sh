#!/bin/sh

case $1 in
    restart)
        docker-compose down && \
            docker-compose up -d --remove-orphans && \ 
            docker-compose ps
        ;;
    clean)
        docker-compose down
        docker system prune --volumes -f
        docker volume prune -a -f
        docker image prune -f
        ;;
    stats)
        docker-compose ps
        ;;
    test)
        curl http://localhost:80/orders
        ;;
    *)
        echo "docker.sh [restart | clean | stats]"
esac
