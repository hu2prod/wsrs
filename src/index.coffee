class Ws_request_service
  ws : null
  request_uid : 0
  response_hash : {}
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
      setInterval ()=>
        now = Date.now()
        for k,v of @response_hash
          if now > v.end_ts
            delete @response_hash[k]
            if !@quiet
              perr "ws_request_service timeout"
              perr v.req
              perr v.callback_orig.toString()
            v.callback new Error "timeout"
        return
      , @interval
  
  request : (req, cb, opt = {})->
    is_binary = opt.bin or opt.binary
    if is_binary and !@bin_encode_fn
      return cb new Error "no bin_encode_fn"
    
    if opt.retry? and opt.retry > 1
      opt = clone opt
      {retry} = opt
      delete opt.retry
      err = null
      res = null
      for i in [0 ... retry]
        await @request req, defer(err, res), opt
        break if !err
        break if !err._is_connection_error
        perr err
      
      cb err, res
      return
    
    err_handler = null
    callback = (err, res)=>
      @ws.off "error", err_handler
      delete @response_hash[req.request_uid] if err or !res.continious_request
      delete res.request_uid if res?
      cb err, res
    
    @ws.once "error", err_handler = (err)=>
      err._is_connection_error = true
      callback err
    
    req.request_uid = @request_uid++
    @response_hash[req.request_uid] = {
      req
      callback
      callback_orig : cb
      end_ts    : Date.now() + (opt.timeout or @timeout)
    }
    if is_binary
      @ws.write @bin_encode_fn req
    else
      @ws.write req
    return req.request_uid
  
  request_bin : (req, cb, opt = {})->
    opt.binary = true
    @request req, cb, opt
  
  send : @prototype.request
  
  send_bin      : @prototype.request_bin
  request_binary: @prototype.request_bin
  send_binary   : @prototype.request_bin

module.exports = Ws_request_service
