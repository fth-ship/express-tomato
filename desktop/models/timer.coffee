class exports.Timer extends Backbone.Model
  initialize: ->
    @ringer = new Audio()
    @ring()
    tomato = @get 'tomato'
    secs = tomato.get 'workSec'
    @set startedAt: null, interval: null, flavor: 'work', seconds: secs

  toggle: =>
    if @isRunning() then @cancel() else @start()

  isRunning: =>
    null isnt @get 'interval'

  start: (options) =>
    return if @isRunning()
    secs = @get 'seconds'
    secs--
    @set startedAt: Date.now(), seconds: secs, interval: setInterval @tick, 1000
    unless options?.silent
      @trigger 'timer:start', @get 'flavor'

  cancel: (options) =>
    return unless @isRunning()
    @clear()
    unless options?.silent
      @trigger 'timer:cancel', @get 'flavor'

  clear: =>
    clearInterval @get 'interval'
    @set startedAt: null, interval: null
    flavor = @get 'flavor'
    @set flavor: if flavor is 'work' then 'break' else 'work'
    @reset()

  tick: =>
    secs = @get 'seconds'
    secs--
    @set seconds: secs
    if secs <= 0
      @clear()
      @ring()
      @trigger 'timer:finish', @get 'flavor'

  ring: ->
    # ringing sound clip
    # from http://www.freesound.org/samplesViewSingle.php?id=14262
    # by xyzr_kx
    # licensed under CC Sampling Plus 1.0
    @ringer.play()
    @ringer = new Audio '/tomato.mp3'

  reset: ->
    flavor = @get 'flavor'
    tomato = @get 'tomato'
    @set seconds: tomato.get "#{flavor}Sec"
