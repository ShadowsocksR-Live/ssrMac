//
//  net_port_is_free.c
//
//  Created by ssrlive on 2020/10/12.
//  Copyright © 2020 ssrLive. All rights reserved.
//
#include <netinet/in.h>
#include <stdbool.h>
#include <sys/socket.h>
#include <netdb.h>
#include <unistd.h>

#include "net_port_is_free.h"

bool net_port_is_free(const char *addr_str, uint16_t port) {
    bool result = false;
    struct addrinfo *ai = NULL;
    int fd = 0;
    do {
        struct sockaddr_in *addr;
        fd = socket(AF_INET, SOCK_STREAM, 0);
        if (fd == -1) {
            break;
        }
        if (getaddrinfo(addr_str, NULL, NULL, &ai) != 0) {
            break;
        }

        addr = (struct sockaddr_in *)ai->ai_addr;
        addr->sin_port = htons(port);

        if (bind(fd, (struct sockaddr *)addr, sizeof(struct sockaddr_in)) != 0) {
            break;
        }
        result = true;
    } while (0);
    if (fd) {
        close(fd);
    }
    if (ai) {
        freeaddrinfo(ai);
    }
    return result;
}
