-- lua 性能监控程序

-- todo
-- 函数同名如何处理（使用文件名+函数名来表示函数名）
-- 递归调用如何处理
-- funcA -> funcB -> funcA 递归如何处理
-- 如果调用太复杂的话，对于少于一定数量的调用，可以不做显示





-- 定义模块
local profiler = {}

--------- 配置项  -----------

-- 是否开启剪枝
profiler.openReduceBranch
-- 开启剪枝时的剪枝的界限，对低于配置数量的叶子节点不显示， 注意，这个选项时递归的，
-- 当一个父节点的所有叶子节点都不显示的时候，这个父节点变成新的叶子节点，也要进行剪枝判断
profiler.reduceBranchCallCount

-- 统计结果展示函数的真实被调用次数还是它出现在调用栈中的次数之和（它自身的被调用次数+它调用的函数的次数+它调用的函数调用的函数的次数+...）
profiler.showRealCalledCount = true

-------------------------


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


-- 图表节点颜色设置
local nodeLevel = {
    {val = 0.8, cor = "color=red"},
    {val = 0.5, cor = "color=yellow"},
    {val = 0.3, cor = "color=blue"},
    {val = 0.0, cor = "color=black"},
}


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

function profiler:gen_node_define()
    assert(self.startFunc)

    self.pFile:write("//节点定义\n")
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

    local info = string.format("%s[label=\"%s %d %.2f\" %s];\n", func.name, func.name, func.callCnt, func.callCnt / self.totalCallCount, color)
    self.pFile:write(info)

    tbVisitedFunc[func.name] = true

    for _, f in ipairs(func.callFuncs) do
        self:_gen_node_define(f, tbVisitedFunc)
    end
end

function profiler:gen_graph()
    assert(self.startFunc)

    self.pFile = io.open("graph.dot", "w")
    self.pFile:write("digraph {\n")

    self:gen_node_define(self.startFunc, {})

    self:_gen_graph(self.startFunc, {}, {})

    self.pFile:write("}\n")
    self.pFile:close()
end

function profiler:_gen_graph(func, tbVisitedFunc, tbVisitStack)
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

    tbVisitedFunc[func.name] = nil
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
