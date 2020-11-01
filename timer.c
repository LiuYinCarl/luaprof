// 由于 Lua 提供的 os.clock() 函数获取时间存在很大误差，所以这里使用 Lua C 拓展编写获取时间的函数

#include <lua5.3/lua.h>
#include <lua5.3/lauxlib.h>
#include <lua5.3/lualib.h>
#include <stdint.h>
#include <time.h>

#ifdef WIN32
#include <windows.h>
#else
#include <sys/time.h>
#endif
#ifdef WIN32
int gettimeofday(struct timeval *tp, void *tzp)
{
    time_t clock;
    struct tm tm;
    SYSTEMTIME wtm;
    GetLocalTime(&wtm);
    tm.tm_year = wtm.wYear - 1900;
    tm.tm_mon = wtm.wMonth - 1;
    tm.tm_mday = wtm.wDay;
    tm.tm_hour = wtm.wHour;
    tm.tm_min = wtm.wMinute;
    tm.tm_sec = wtm.wSecond;
    tm.tm_isdst = -1;
    clock = mktime(&tm);
    tp->tv_sec = clock;
    tp->tv_usec = wtm.wMilliseconds * 1000;
    return (0);
}
#endif

// 获取微秒时间戳
static int microsecTimestamp(lua_State *L)
{
    struct timeval tv;
    gettimeofday(&tv, NULL);
    int64_t n = tv.tv_sec * 1000000 + tv.tv_usec;

    lua_pushnumber(L, n);
    return 1;
}

// 获取毫秒时间戳
static int millisecTimestamp(lua_State *L) {
        struct timeval tv;
        gettimeofday(&tv, NULL);
        int64_t n = tv.tv_sec * 1000000 + tv.tv_usec;
        n /= 1000;

        lua_pushnumber(L, n);
        return 1;
}

static const struct luaL_Reg timer_Lib[] = {
    {"microsecTimestamp", microsecTimestamp},
    {"millisecTimestamp", millisecTimestamp},
    {NULL, NULL}};

int luaopen_timerlib(lua_State *L)
{
    luaL_newlib(L, timer_Lib);
    return 1;
}
