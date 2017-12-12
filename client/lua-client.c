#define LUA_LIB

#include <lua.h>
#include <lauxlib.h>
#include <string.h>
#include <stdint.h>
#include <pthread.h>
#include <stdlib.h>

#include <netinet/in.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <netdb.h>
#include <netinet/tcp.h>
#include <assert.h>

#define QUEUE_SIZE 1024

struct queue {
    pthread_mutex_t lock;
    int head;
    int tail;
    char * queue[QUEUE_SIZE];
};

static void *
readline_stdin(void * arg) {
    struct queue * q = arg;
    char tmp[1024];
    while (!feof(stdin)) {
        if (fgets(tmp,sizeof(tmp),stdin) == NULL) {
            // read stdin failed
            exit(1);
        }
        int n = strlen(tmp) -1;

        char * str = malloc(n+1);
        memcpy(str, tmp, n);
        str[n] = 0;

        pthread_mutex_lock(&q->lock);
        q->queue[q->tail] = str;

        if (++q->tail >= QUEUE_SIZE) {
            q->tail = 0;
        }
        if (q->head == q->tail) {
            // queue overflow
            exit(1);
        }
        pthread_mutex_unlock(&q->lock);
    }
    return NULL;
}

static int
lreadstdin(lua_State *L) {
    struct queue *q = lua_touserdata(L, lua_upvalueindex(1));
    pthread_mutex_lock(&q->lock);
    if (q->head == q->tail) {
        pthread_mutex_unlock(&q->lock);
        return 0;
    }
    char * str = q->queue[q->head];
    if (++q->head >= QUEUE_SIZE) {
        q->head = 0;
    }
    pthread_mutex_unlock(&q->lock);
    lua_pushstring(L, str);
    free(str);
    return 1;
}

static void*
thread_run(void * arg) {
    lua_State *L = arg;
    int n = lua_gettop(L);
    assert(n >= 1);
    int err = lua_pcall(L, n-1, 0, 0);
    if (err) {
        fprintf(stderr,"%s\n",lua_tostring(L,-1));
        lua_close(L);
    }
    return 0;
}

static int
lnewthread(lua_State *L) {
    pthread_t pid;
    pthread_create(&pid, NULL, thread_run, L);
    return 0;
}

static int
ltostring(lua_State *L) {
    void * ptr = lua_touserdata(L, 1);
    int size = luaL_checkinteger(L, 2);
    if (ptr == NULL) {
        lua_pushliteral(L, "");
    } else {
        lua_pushlstring(L, (const char *)ptr, size);
        free(ptr);
    }
    return 1;
}

LUAMOD_API int
luaopen_lclient(lua_State *L) {
    luaL_checkversion(L);
    luaL_Reg l[] = {
        { "newthread", lnewthread},
        { "tostring", ltostring },
        { NULL, NULL},
    };
    luaL_newlib(L, l);

    struct queue * q = lua_newuserdata(L, sizeof(*q));
    memset(q, 0, sizeof(*q));
    pthread_mutex_init(&q->lock, NULL);
    lua_pushcclosure(L, lreadstdin, 1);
    lua_setfield(L, -2, "readstdin");

    pthread_t pid;
    pthread_create(&pid, NULL, readline_stdin, q);

    return 1;
}