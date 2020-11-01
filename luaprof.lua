-- lua 性能监控程序

-- todo
-- 添加按函数执行时间进行剪枝的功能    

-- NOTE: 如果找不到 C 模块的话，就使用 os.clock() 替代模块中的函数，但是要注意，C模块中返回的是时间戳，替代函数返回的是程序从启动后经过的时间
local _loadModuleSucc, proftimer = pcall(require, "timerlib")
if not _loadModuleSucc then
    print("ERROR: the C extern module 'timerlib' not found, use os.clock() to replace. millisecTimestamp/microsecTimestamp will return the millisecond/microsecond since program start.")
    proftimer = {
        millisecTimestamp = function()
            local now = function()
                return 1000 * os.clock()
            end
            return now()
        end,

        microsecTimestamp = function()
            local now = function()
                return 1000000 * os.clock()
            end
            return now()
        end,
    }
end

-- 定义模块
local profiler = {}


--------- 配置项  -----------

-- 是否开启剪枝
profiler.openReduceBranch = true
-- 开启剪枝时的剪枝的界限，对低于配置数量的叶子节点不显示， 注意，这个选项时递归的，
-- 当一个父节点的所有叶子节点都不显示的时候，这个父节点变成新的叶子节点，也要进行剪枝判断
profiler.reduceBranchCallCount = 2 -- 对调用次数少于10次的函数不展示

-- 统计结果展示函数的真实被调用次数还是它出现在调用栈中的次数之和（它自身的被调用次数+它调用的函数的次数+它调用的函数调用的函数的次数+...）
profiler.showRealCalledCount = true

-- 不想统计的函数名，这样子写的原因是防止有些函数名中间带空格（如 for iterator）
profiler.notWatchFunc = {}
profiler.notWatchFunc["stop"] = true
profiler.notWatchFunc["sethook"] = true
-------------------------


-- 当前函数调用栈
profiler.curCallStack = {}
-- 函数调用图
-- profiler.callMap = {}
-- 全局函数调用次数统计表
profiler.funcCallInfoTable = {}
-- k: funcName v:funcState
profiler.funcMap = {}
-- 记录启动函数
profiler.startFunc = nil
-- 所有函数总调用次数
profiler.totalCallCount = 0


-- 图表节点颜色设置
local nodeLevel = {
    {val = 0.1, cor = "color=red"},
    {val = 0.05, cor = "color=yellow"},
    {val = 0.03, cor = "color=blue"},
    {val = 0.01, cor = "color=black"},
}

function profiler:_print_all_func()
    print("-----------all func-----------")
    for funcName, _ in pairs(self.funcMap) do
        print(funcName)    
    end
    print("-------------------------------")
end

-- 获取函数名
function profiler:_get_func_name(funcInfo)
    assert(funcInfo)
    -- 返回函数名:行号
    local name = funcInfo.name .. ":" .. funcInfo.currentline or "anonymous"
    return name
end

-- 监控函数调用
function profiler:_profiling_call(funcInfo)
    local funcName = self:_get_func_name(funcInfo)

    -- 不统计想排除的函数
    if self.notWatchFunc[funcName] then
        return
    end

    self.totalCallCount = self.totalCallCount + 1

    -- 缓存当前时间，避免多次调用 proftimer.microsecTimestamp()
    local nowTime = proftimer.microsecTimestamp()

    -- 检查这个函数之前是否出现过，没出现过则添加到 profiler.funcMap
    local funcState = self.funcMap[funcName]
    if not funcState then
        funcState = {
            name = funcName,    -- 函数名
            show = true,  -- 导出图像的时候是否绘制该节点
            callCnt = 0,        -- 被调用次数
            callFuncs = {},      -- 本函数调用的函数
            totalRunTime = 0,  --  函数的总运行时间 
            recursiveStack = { -- 存储函数执行的一些信息，程序中只用一个表存储一个函数的信息，所以需要这个栈来保存本函数递归执行中的一些信息
                {
                    resumeTime = nowTime,  -- 函数调用开始时间或者函数被中断后重新获得控制权的时间
                    suspendTime = 0, -- 函数暂时时间，当该函数调用其他函数的时候需要设置
                },
            },
        }
        self.funcMap[funcName] = funcState
        -- 记录第一个被调用的函数
        if not self.startFunc then
            self.startFunc = funcState
        end
    else -- 这个函数之前被调用过，函数信息已经创建
        local tb = {
            resumeTime = nowTime,
            suspendTime = 0,
        }
        table.insert(funcState.recursiveStack, tb)
    end

    -- 当前函数调用次数+1
    funcState.callCnt = funcState.callCnt + 1

    local len = #self.curCallStack
    if len ~= 0 then
        -- 获取该函数的主调函数
        local lastFunc = self.curCallStack[len]

        -- 防止将一个函数多次加入到另一个函数的调用记录表中
        local added = false
        for _, f in ipairs(lastFunc.callFuncs) do
            if f.name == funcState.name then
                added = true
                break
            end
        end
        if not added then
            table.insert(lastFunc.callFuncs, funcState)
        end
        
        -- 累计主调函数的运行用时
        local recurStackLen = #lastFunc.recursiveStack
        assert(recurStackLen > 0)  -- 运行到此处，recursiveStack中至少有一个元素
        lastFuncCurRecursiveInfo = lastFunc.recursiveStack[recurStackLen]
        lastFuncCurRecursiveInfo.suspendTime = nowTime
        lastFunc.totalRunTime = lastFunc.totalRunTime + (lastFuncCurRecursiveInfo.suspendTime - lastFuncCurRecursiveInfo.resumeTime)
    end
    -- 函数信息推入调用栈
    table.insert(self.curCallStack, funcState)

    if not self.showRealCalledCount then
        local tmpFuncMap = {}
        for _, f in ipairs(self.curCallStack) do
            -- 在递归的情况下，调用栈中可以出现一个函数的信息多次，下面代码防止对这些函数多次计数
            if not tmpFuncMap[f.name] then
                f.callCnt = f.callCnt + 1
                tmpFuncMap[f.name] = true
            end
        end
    end
end


--  监控函数返回
function profiler:_profiling_return(funcInfo)
    -- 调用set_hook()函数后会执行该函数，所以不能做 assert
    -- assert(#self.curCallStack > 0)

    -- 不统计想排除的函数
    local funcName = self:_get_func_name(funcInfo)
    if self.notWatchFunc[funcName] then
        return
    end

    local len = #self.curCallStack

    if len == 0 then
        return
    end

    local nowTime = proftimer.microsecTimestamp()

    -- 累计本函数的运行时间
    local curFunc = self.curCallStack[len]

    local recurStackLen = #curFunc.recursiveStack
    assert(recurStackLen > 0)  -- 运行到此处，recursiveStack中至少有一个元素
    curFuncCurRecursiveInfo = curFunc.recursiveStack[recurStackLen]

    curFunc.totalRunTime = curFunc.totalRunTime + (nowTime - curFuncCurRecursiveInfo.resumeTime)

    -- 函数本次调用统计信息清除
    table.remove(curFunc.recursiveStack)

    -- 函数信息从调用栈推出
    table.remove(self.curCallStack)

    -- 设置该函数的主调函数的resumeTime
    if len > 1 then
        local lastFunc = self.curCallStack[len-1]
        local _len = #lastFunc.recursiveStack
        local _lastFuncCurRecurInfo = lastFunc.recursiveStack[_len]
        _lastFuncCurRecurInfo.resumeTime = nowTime
    end
end

-- deepth 调用栈深度
function profiler:print_funcMap()
    assert(self.startFunc)

    print("startFunc:", self.startFunc.name)
    print("totalCallCount", self.totalCallCount)
    print("---------------------------------")

    self:_print_funcMap(self.startFunc, 0, {})
end


function profiler:_print_funcMap(func, deepth, tbPrintedFunc)
    if tbPrintedFunc[func.name] then  -- 之前打印过，直接返回，防止无限递归
        return
    end

    self:_print_blank(deepth)

    local info = string.format("%s(%d %.2f%% %.3fs)\n", 
                    func.name, func.callCnt, func.callCnt/self.totalCallCount, func.totalRunTime/1000000)
    io.write(info)

    tbPrintedFunc[func.name] = true
    

    for _, f in ipairs(func.callFuncs) do
        self:_print_funcMap(f, deepth+1, tbPrintedFunc)
    end

    -- 清除标记
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
    local funcInfo = debug.getinfo(2, "nlS")

    if hookType == "call" then
        profiler:_profiling_call(funcInfo)
    elseif hookType == "return" then
        profiler:_profiling_return(funcInfo)
    end
end

function profiler:gen_node_define()
    assert(self.startFunc)

    self.pFile:write("// node define\n")
    self:_gen_node_define(self.startFunc, {})
    self.pFile:write("\n\n")
end

function profiler:_gen_node_define(func, tbVisitedFunc)
    if tbVisitedFunc[func.name] then
        return
    end
    
    -- 节点颜色选取
    local warmVal = func.callCnt / self.totalCallCount
    local color = ""
    for _, elem in ipairs(nodeLevel) do
        if warmVal > elem.val then
            color = elem.cor
            break
        end
    end

    if func.show then
        local info = string.format("%s[label=\"%s\\n %d %.2f%% %.3fs\" %s];\n", 
                    func.name, func.name, func.callCnt, func.callCnt / self.totalCallCount, func.totalRunTime/1000000, color)
        self.pFile:write(info)
    end

    tbVisitedFunc[func.name] = true

    for _, f in ipairs(func.callFuncs) do
        self:_gen_node_define(f, tbVisitedFunc)
    end
end

function profiler:check_node()
    assert(self.startFunc)

    if self.openReduceBranch == false then
        return
    end

    self:_check_node(self.startFunc, {})
end

-- 调用这个函数，说明开启了剪枝，这个函数用来确定要绘制的节点
function profiler:_check_node(func, tbVisitedFunc)
    if tbVisitedFunc[func.name] then
        return func.show  -- todo 这样子会导致递归函数一定会展示
    end

    tbVisitedFunc[func.name] = true  

    local showSelfNode = true  -- 默认绘制本节点

    if func.callCnt < self.reduceBranchCallCount then  -- 先检测本节点数量是否满足剪枝的要求
        showSelfNode = false
    end

    local _showChildNode = false  -- 是否有子节点需要绘制
    for _, f in ipairs(func.callFuncs) do
        if self:_check_node(f, tbVisitedFunc) == true then
            _showChildNode = true
        end
    end

    showSelfNode = _showChildNode  -- 只要有一个子节点需要被绘制，本节点就需要绘制，不然子节点可能变成孤立节点

    func.show = showSelfNode  -- 设置节点是否展示
    return showSelfNode
end

function profiler:gen_graph()
    assert(self.startFunc)

    self.pFile = io.open("luaprof.dot", "w")
    self.pFile:write("digraph {\n")

    self:check_node()

    self:gen_node_define(self.startFunc, {})

    self:_gen_graph(self.startFunc, {}, {})

    self.pFile:write("}\n")
    self.pFile:close()
end

function profiler:_gen_graph(func, tbVisitedFunc, tbVisitStack)
    if func.show == false then
        return
    end

    if tbVisitedFunc[func.name] then
        return
    end

    local len = #tbVisitStack
    if len > 0 then
        local lastFunc = tbVisitStack[len]
        local info = string.format("%s -> %s;\n", lastFunc.name, func.name)
        self.pFile:write(info)
    end

    tbVisitedFunc[func.name] = true
    table.insert(tbVisitStack, func)

    for _, f in ipairs(func.callFuncs) do
        self:_gen_graph(f, tbVisitedFunc, tbVisitStack)
    end

    -- tbVisitedFunc[func.name] = nil    --todo 这个是否可以防止重复绘制 A-> B 的线
    table.remove(tbVisitStack)
end


function profiler:start()
    debug.sethook(profiler._profiling_handler, "cr", 0)
end

function profiler:stop()
    debug.sethook()
end

-- 返回模块
return profiler
