local profiler = require("luaprof")
local proftimer = require("timerlib")


-- 测试链式调用
function level1()
    level2()
end

function level2()
    level3()
end

function level3()
    level4()
end

function level4()
    level5()
end

function level5()
    level6()
end

function level6()
    return
end

-- 测试链式递归调用
function recursionA(n)
    if n <= 0 then
        return
    end
    recursionB(n-1)
end

function recursionB(n)
    if n <= 0 then
        return
    end
    recursionC(n-1)
end

function recursionC(n)
    if n <= 0 then
        return
    end
    recursionD(n-1)
end

function recursionD(n)
    if n <= 0 then
        return
    end
    recursionA(n-1)
end

-- 测试递归调用
function recursion(n)
    if n <= 0 then
        return
    end
    recursion(n-1)
end

-- 测试函数被打断多次
function multiSuspend()
    suspend1()
    suspend2()
    suspend3()
    suspend4()
end

function suspend1()
    for i = 1, 100 do
        local tmp = 10 * 10
    end
end

function suspend2()
    for i = 1, 10000 do
        local tmp = 10 * 10
    end
end

function suspend3()
    -- local begintime = proftimer.nowMicroSecond()
    for i = 1, 1000000 do
        local tmp = 10 * 10
    end
    -- local endtime = proftimer.nowMicroSecond()
    -- print("suspend3 cost:", (endtime - begintime) / 1000000.0)
end

function suspend4()
    -- local begintime = proftimer.nowMicroSecond()
    for i = 1, 100000000 do
        local tmp = 10 * 10
    end
    -- local endtime = proftimer.nowMicroSecond()
    -- print("suspend4 cost:", (endtime - begintime) / 1000000.0)
end


function main()
    level1()
    recursionA(4)
    recursion(6)
    multiSuspend()
end




profiler:start()
main()
profiler:stop()
-- profiler:_print_all_func()
profiler:gen_graph()
profiler:print_funcMap()