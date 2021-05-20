// because Lua's os.clock() have deviation ，so we write a function to replace it
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <stdint.h>
#include <time.h>

#ifdef WIN32
#include <windows.h>
#else
#include <sys/time.h>
#endif
#ifdef WIN32
int gettimeofday(struct timeval * tp, struct timezone * tzp)
{
    // Note: some broken versions only have 8 trailing zero's, the correct epoch has 9 trailing zero's
    // This magic number is the number of 100 nanosecond intervals since January 1, 1601 (UTC)
    // until 00:00:00 January 1, 1970 
    static const uint64_t EPOCH = ((uint64_t) 116444736000000000ULL);

    SYSTEMTIME  system_time;
    FILETIME    file_time;
    uint64_t    time;

    GetSystemTime( &system_time );
    SystemTimeToFileTime( &system_time, &file_time );
    time =  ((uint64_t)file_time.dwLowDateTime )      ;
    time += ((uint64_t)file_time.dwHighDateTime) << 32;

    tp->tv_sec  = (long) ((time - EPOCH) / 10000000L);
    tp->tv_usec = (long) (system_time.wMilliseconds * 1000);
    return 0;
}
#endif

// get microsecond timestamp
static int microsecTimestamp(lua_State *L)
{
    struct timeval tv;
    gettimeofday(&tv, NULL);
    int64_t n = tv.tv_sec * 1000000 + tv.tv_usec;

    lua_pushnumber(L, n);
    return 1;
}

// get millisecond timestamp
static int millisecTimestamp(lua_State *L)
{
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
