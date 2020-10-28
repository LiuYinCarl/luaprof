local profiler = require("luaprof")


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

function main()
    level1()
    recursionA(6)
    recursion(6)
end


profiler:start()
main()
profiler:stop()
profiler:print_funcMap()