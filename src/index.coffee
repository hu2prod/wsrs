class Ws_request_service
  ws : null
  request_uid : 0
  response_hash : {}
  _interval : null
  interval: 30000
  timeout : 30000
  quiet   : false
  bin_encode_fn : null
  bin_decode_fn : null
  
  constructor : (@ws)->
    @response_hash = {}
    @ws.on "data", (data)=>
      # puts data
      if data instanceof Buffer
        if !@bin_decode_fn
          if !@quiet
            perr "unexpected binary data. No bin_decode_fn"
          return
        try
          data = @bin_decode_fn data
        catch err
          if !@quiet
            perr "decode error", err
          return
      if data.request_uid?
        if @response_hash[data.request_uid]?
          cb = @response_hash[data.request_uid].callback
          if data.error
            cb new Error(data.error), data
          else
            cb null, data
        else
          if !@quiet
            perr "missing request_uid = #{data.request_uid}. Possible timeout. switch=#{data.switch}"
      return
    setTimeout ()=>
      @_interval = setInterval ()=>
        now = Date.now()
        for k,v of @response_hash
          if now > v.end_ts
            delete @response_hash[k]
            if !@quiet
              perr "ws_request_service timeout"
              perr v.hash
              perr v.callback_orig.toString()
            v.callback new Error "timeout"
        return
      , @interval
  
  delete : ()->
    clearInterval @_interval
  
  request : (hash, handler, opt = {})->
    is_binary = opt.bin or opt.binary
    if is_binary and !@bin_encode_fn
      return handler new Error "no bin_encode_fn"
    err_handler = null
    callback = (err, res)=>
      @ws.off "error", err_handler
      delete @response_hash[hash.request_uid] if err or !res.continious_request
      delete res.request_uid if res?
      handler err, res
    
    @ws.once "error", err_handler = (err)=>
      callback err
    
    hash.request_uid = @request_uid++
    @response_hash[hash.request_uid] = {
      hash
      callback
      callback_orig : handler
      end_ts    : Date.now() + (opt.timeout or @timeout)
    }
    if is_binary
      @ws.write @bin_encode_fn hash
    else
      @ws.write hash
    return hash.request_uid
  
  request_bin : (hash, handler, opt = {})->
    opt.binary = true
    @request hash, handler, opt
  
  send : @prototype.request
  
  send_bin      : @prototype.request_bin
  request_binary: @prototype.request_bin
  send_binary   : @prototype.request_bin

module.exports = Ws_request_service
