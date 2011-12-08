class exports.Timer extends Backbone.View
  el: $('#timer')

  events:
    'click': 'toggle'

  initialize: ->
    $(@el).addClass @model.get 'flavor'

    @model.bind 'change:startedAt', @startedOrCancelled
    @model.bind 'change:flavor', @flavorChanged
    @model.bind 'change:seconds', @render

  render: =>
    time = @format @model.get 'seconds'
    $(@el).html time
    title = $('title').text().replace /^\d+:\d+ -/, ''
    if @model.isRunning()
      title = "#{time} - #{title}"
    $('title').text title
    @

  toggle: ->
    @model.toggle()

  format: (seconds) ->
    mins = Math.floor seconds / 60
    secs = seconds - 60 * mins
    if secs < 10 then "#{mins}:0#{secs}" else "#{mins}:#{secs}"

  startedOrCancelled: =>
    if not @model.isRunning()
      $(@el).addClass 'running'
      $('#screen').addClass 'running'
    else
      $(@el).removeClass 'running'
      $('#screen').removeClass 'running'
    @render()

  flavorChanged: =>
    $(@el).removeClass 'work'
    $(@el).removeClass 'break'
    $(@el).addClass @model.get 'flavor'
    @render()
