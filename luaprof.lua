-- lua 性能监控程序

-- todo
-- 函数同名如何处理（使用文件名+函数名来表示函数名）
-- 递归调用如何处理
-- funcA -> funcB -> funcA 递归如何处理
-- 如果调用太复杂的话，对于少于一定数量的调用，可以不做显示


-- 定义模块
local profiler = {}

-- 当前函数调用栈
profiler.curCallStack = {}
-- 函数调用图
profiler.callMap = {}
-- 全局函数调用次数统计表
profiler.funcCallInfoTable = {}
-- k: funcName v:funcStatistics
profiler.funcMap = {}
-- 记录启动函数
profiler.startFunc = nil
-- 所有函数总调用次数
profiler.totalCallCount = 0


-- 获取函数名
function profiler:_get_func_name(funcInfo)
    assert(funcInfo)

    local name = funcInfo.name or "anonymous"
    return name
end

-- 监控函数调用
function profiler:_profiling_call(funcInfo)
    self.totalCallCount = self.totalCallCount + 1

    local funcName = self:_get_func_name(funcInfo)

    -- 检查这个函数之前是否出现过，没出现过则添加到 profiler.funcMap
    local funcStatistics = self.funcMap[funcName]
    if not funcStatistics then
        funcStatistics = {
            name = funcName,    -- 函数名
            callCnt = 0,        -- 被调用次数
            callFuncs = {}      -- 本函数调用的函数
        }
        self.funcMap[funcName] = funcStatistics
        -- 记录第一个被调用的函数
        if not self.startFunc then
            self.startFunc = funcStatistics
        end
    end

    local len = #self.curCallStack
    if len ~= 0 then
        local lastFunc = self.curCallStack[len]

        -- 防止将一个函数多次加入到另一个函数的调用记录表中
        local added = false
        for _, f in ipairs(lastFunc.callFuncs) do
            if f.name == funcStatistics.name then
                added = true
                break
            end
        end

        if not added then
            table.insert(lastFunc.callFuncs, funcStatistics)
        end
    end
    -- 函数信息推入调用栈
    table.insert(self.curCallStack, funcStatistics)

    local tmpFuncMap = {}
    for _, f in ipairs(self.curCallStack) do
        -- 在递归的情况下，调用栈中可以出现一个函数的信息多次，下面代码防止对这些函数多次计数
        if not tmpFuncMap[f.name] then
            f.callCnt = f.callCnt + 1
            tmpFuncMap[f.name] = true
        end
    end
end


--  监控函数返回
function profiler:_profiling_return(funcInfo)
    -- 调用set_hook()函数后会执行该函数，所以不能做 assert
    -- assert(#self.curCallStack > 0)

    if #self.curCallStack <= 0 then
        return
    end

    -- 函数信息从调用栈推出
    table.remove(self.curCallStack)
end

-- deepth 调用栈深度
function profiler:print_funcMap()
    assert(self.startFunc)

    print("startFunc:", self.startFunc.name)

    self:_print_funcMap(self.startFunc, 0, {})
end


function profiler:_print_funcMap(func, deepth, tbPrintedFunc)
    if tbPrintedFunc[func.name] then  -- 之前打印过，直接返回，防止无限递归
        return
    end

    self:_print_blank(deepth)

    local info = string.format("%s:(%d  %.2f)\n", func.name, func.callCnt, func.callCnt / self.totalCallCount)
    io.write(info)

    tbPrintedFunc[func.name] = true
    

    for _, f in ipairs(func.callFuncs) do
        self:_print_funcMap(f, deepth+1, tbPrintedFunc)
    end

    -- 清楚标记
    tbPrintedFunc[func.name] = nil
end


function profiler:_print_blank(deepth)
    local blank = "|  "
    local str = ""
    for i = 0, deepth-1 do
        str = str .. blank
    end
    io.write(str)
end

function profiler._profiling_handler(hookType)
    -- 拿到被调用函数的函数名和文件名，函数定义的起始和结束行号
    local funcInfo = debug.getinfo(2, "nS")

    if hookType == "call" then
        profiler:_profiling_call(funcInfo)
    elseif hookType == "return" then
        profiler:_profiling_return(funcInfo)
    end
end


function profiler:start()
    debug.sethook(profiler._profiling_handler, "cr", 0)
end

function profiler:stop()
    debug.sethook()
end

-- 返回模块
return profiler
