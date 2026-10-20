local ffi = require('ffi')
local json = require('cjson.safe')
ffi.cdef[[typedef struct lb_client lb_client;
typedef struct {void *context; void (*on_sign_in)(void*,const char*,const char*); double (*clock)(void*); int (*machine_binding)(void*,char*,size_t); int (*cancelled)(void*);} lb_callbacks;
int lb_client_create_json(const char*,const lb_callbacks*,lb_client**);
int lb_client_call_json(lb_client*,const char*,const char*,char**);
void lb_client_destroy(lb_client*);void lb_free(void*);
const char* lb_result_code(int);const char* lb_error_code(lb_client*);const char* lb_error_message(lb_client*);
int lb_native_binding(const char*,char*,size_t);int lb_derive_binding(const char*,const char*,const char*,char*,size_t);
int lb_verify_lease_json(const char*,const char*,const char*,double,char**);]]
local path=os.getenv('LICENSEBOX_LIBRARY') or (os.getenv('LICENSEBOX_LIB_DIR') and os.getenv('LICENSEBOX_LIB_DIR')..'/liblicensebox.so') or 'licensebox'
local C=ffi.load(path)
local M={version='0.3.0',null=json.null}
local function fail(code,detail) error({code=code,message=detail or code},0) end
local function arg(s) if type(s)~='string' or s:find('\0',1,true) then fail('invalid_argument') end return s end
local function finite(n) return type(n)=='number' and n==n and math.abs(n)~=math.huge end
local function encode(v) local s,e=json.encode(v);if not s then fail('invalid_argument',e) end return s end
local function keys(v) for k,s in pairs(v) do arg(k);arg(s) end return encode(v) end
local function err(r,h)
 local code=ffi.string(C.lb_result_code(r));local detail=code
 if h~=nil and code~='invalid_argument' then local saved=ffi.string(C.lb_error_code(h));if saved~='ok' then code=saved end;detail=ffi.string(C.lb_error_message(h)) end
 fail(code,detail)
end
local function output(p)
 if p==nil then fail('protocol_error') end
 local s=ffi.string(p);C.lb_free(p);local v,e=json.decode(s);if e then fail('protocol_error',e) end return v
end
function M.derive_binding(product,source,raw)
 raw=raw:gsub('%z+$','');if raw:find('\0',1,true) then fail('identity_unavailable') end
 local out=ffi.new('char[128]');local r=C.lb_derive_binding(arg(product),arg(source),raw,out,128);if r~=0 then err(r) end return ffi.string(out)
end
function M.native_binding(product) local out=ffi.new('char[128]');local r=C.lb_native_binding(arg(product),out,128);if r~=0 then err(r) end return ffi.string(out) end
function M.verify_lease(token,product,trusted,now)
 if not finite(now) then fail('invalid_argument') end
 local out=ffi.new('char*[1]');local r=C.lb_verify_lease_json(arg(token),arg(product),keys(trusted),now,out)
 if r~=0 then C.lb_free(out[0]);err(r) end return output(out[0])
end
local Client={};Client.__index=Client
-- hooks contains trusted clock/machine_binding/on_sign_in/cancelled functions.
function M.new(options,hooks)
 hooks=hooks or {};local opts={product=arg(options.product),keys=options.keys,version=arg(options.version or '')};keys(opts.keys)
 for _,name in ipairs({'server','directory','ca_bundle'}) do if options[name] then opts[name]=arg(options[name]) end end
 local self=setmetatable({callbacks={},busy=false},Client);local cb=ffi.new('lb_callbacks');self.structure=cb
 local function wrap(ctype,f,fallback)
  local c=ffi.cast(ctype,function(...)local ok,v=pcall(f,...);if not ok then self.failure=v;return fallback end return v end)
  self.callbacks[#self.callbacks+1]=c;return c
 end
 if hooks.on_sign_in then cb.on_sign_in=wrap('void(*)(void*,const char*,const char*)',function(_,u,c)hooks.on_sign_in(ffi.string(u),ffi.string(c))end,nil) end
 if hooks.clock then cb.clock=wrap('double(*)(void*)',function()local v=hooks.clock();if not finite(v) then fail('invalid_argument') end return v end,0) end
 if hooks.machine_binding then cb.machine_binding=wrap('int(*)(void*,char*,size_t)',function(_,p,n)local s=arg(hooks.machine_binding());if #s>=tonumber(n) then return 1 end;ffi.copy(p,s,#s+1);return 0 end,1) end
 cb.cancelled=wrap('int(*)(void*)',function()return (self.failure or (hooks.cancelled and hooks.cancelled())) and 1 or 0 end,1)
 local out=ffi.new('lb_client*[1]');local r=C.lb_client_create_json(encode(opts),cb,out)
 if r~=0 or self.failure then if out[0]~=nil then C.lb_client_destroy(out[0]) end;for _,c in ipairs(self.callbacks)do c:free()end;if self.failure then fail('callback_error') end;err(r) end
 self.handle=ffi.gc(out[0],C.lb_client_destroy);return self
end
function Client:close()
 if self.busy then fail('invalid_argument','callback reentry') end
 if self.handle~=nil then C.lb_client_destroy(ffi.gc(self.handle,nil));self.handle=nil end
 for _,c in ipairs(self.callbacks)do c:free()end;self.callbacks={}
end
local function call(self,op,args)
 if self.busy or self.handle==nil then fail('invalid_argument','closed or reentered client') end
 self.busy=true
 local ok,value=pcall(function()
  local out=ffi.new('char*[1]');local r=C.lb_client_call_json(self.handle,op,encode(args or {}),out)
  if r~=0 or self.failure then C.lb_free(out[0]);if self.failure then self.failure=nil;fail('callback_error') end;err(r,self.handle) end
  return output(out[0])
 end)
 self.busy=false;if not ok then error(value,0) end return value
end
function Client:lease()return call(self,'lease')end
function Client:heartbeat(name)return call(self,'heartbeat',{module=arg(name)})end
function Client:require_module(name)return call(self,'require',{module=arg(name)})end
function Client:status()return call(self,'status')end
function Client:sign_in(timeout)timeout=timeout or 0;if not finite(timeout)then fail('invalid_argument')end;return call(self,'sign_in',{timeout=timeout})end
function Client:logout()return call(self,'logout')end
function Client:modules()return call(self,'modules')end
function Client:requests()return call(self,'requests')end
function Client:request_access(modules,note)for _,s in ipairs(modules)do arg(s)end;return call(self,'request',{modules=modules,note=arg(note or '')})end
function Client:access_link()return call(self,'access-link')end
function Client:record(command,success,elapsed)if type(success)~='boolean' or not finite(elapsed) or elapsed<0 then fail('invalid_argument')end;return call(self,'record',{command=arg(command),success=success,elapsed=elapsed})end
return M
