local json=require('cjson.safe');local lb=require('licensebox');local r=assert(json.decode(io.read('*a')))
local function run()
 if r.op=='derive' then return lb.derive_binding(r.product,r.source,r.raw_id) end
 if r.op=='native' then return lb.native_binding(r.product) end
 if r.op=='verify' then return lb.verify_lease(r.token,r.product,r.keys,r.now) end
 local c=lb.new({product=r.product,keys=r.keys,version='conformance',server=r.server,ca_bundle=r.ca_bundle,directory=r.directory},{clock=function()return r.now end,machine_binding=function()return r.binding end,on_sign_in=function()end})
 local ok,v=pcall(function()
  if r.op=='require' then return c:require_module(r.module or 'core')
  elseif r.op=='heartbeat' then return c:heartbeat(r.module or 'core')
  elseif r.op=='heartbeat-repeat' then c:heartbeat(r.module or 'core');return c:heartbeat(r.module or 'core')
  elseif r.op=='heartbeat-after-require' then c:require_module(r.module or 'core');return c:heartbeat(r.module or 'core')
  elseif r.op=='repeat' then c:require_module('core');return c:require_module('core')
  elseif r.op=='sign_in' then return c:sign_in(3)
  elseif r.op=='request' then return c:request_access({'export'},'café – test')
  elseif r.op=='access-link' then return c:access_link()
  elseif r.op=='record' then c:record('export',true,.125);c:record('export',false,.025);return lb.null
  else return c[r.op](c) end
 end)
 c:close();if not ok then error(v,0)end;return v
end
local ok,v=pcall(run);if ok then print(json.encode({ok=true,value=v}))else print(json.encode({ok=false,error=type(v)=='table' and v.code or 'adapter_error'}))end
