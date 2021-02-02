class Ws_request_service
  ws : null
  request_uid : 0
  response_hash : {}
  interval: 30000
  timeout : 30000

  constructor : (@ws)->
    @response_hash = {}
    @ws.on "data", (data)=>
      # puts data
      if data.request_uid?
        if @response_hash[data.request_uid]?
          cb = @response_hash[data.request_uid].callback
          if data.error
            cb new Error(data.error), data
          else
            cb null, data
        else
          perr "missing request_uid = #{data.request_uid}. Possible timeout. switch=#{data.switch}"
      return
    setTimeout ()=>
      setInterval ()=>
        now = Date.now()
        for k,v of @response_hash
          if now > v.end_ts
            delete @response_hash[k]
            perr "ws_request_service timeout"
            perr v.hash
            perr v.callback_orig.toString()
            v.callback new Error "timeout"
        return
      , @interval
  
  request : (hash, handler, opt = {})->
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
    @ws.write hash
    return hash.request_uid
  
  send : @prototype.request

module.exports = Ws_request_service
