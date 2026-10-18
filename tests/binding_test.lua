local lb=require('licensebox')
assert(lb.derive_binding('demo','linux-machine-id','12345678123456789abc1234567890ab\0'):match('^m1:'))
local ok,e=pcall(lb.verify_lease,'bad','demo',{},0);assert(not ok and e.code=='malformed')
print('Lua binding checks passed')
local dir=os.tmpname();os.remove(dir)
local c=lb.new({product='demo',keys={['test-key']='A6EHv_POEL4dcN0Y50vAmWfk1jCbpQ1fHdyGZBJVMbg'},directory=dir},{machine_binding=function()error('synthetic callback failure')end})
local success,failure=pcall(function()c:sign_in(.1)end);assert(not success and failure.code=='callback_error');c:close();c:close()
for _,name in ipairs({'install.key','install.lock','seen','lease','policy-denial','usage.json'})do os.remove(dir..'/'..name)end
os.remove(dir)
