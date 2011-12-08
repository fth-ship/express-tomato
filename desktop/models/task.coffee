class exports.Task extends Backbone.Model
  toggleFinished: ->
    @save finishedAt: if @isFinished() then null else Date.now()

  isFinished: ->
    null isnt @get 'finishedAt'

  start: ->
    @trigger 'task:start'

  addTomato: ->
    toms = @get 'tomatoes'
    toms.push Date.now()
    @save tomatoes: toms

  removeTomato: (index) ->
    toms = @get 'tomatoes'
    i = if index? then index else toms.length - 1
    @save tomatoes: toms[0...i].concat toms[i+1...]

  toTemplate: ->
    formatDate = (d) ->
      return '' if not d
      d = new Date d
      "#{d.getFullYear()}-#{d.getMonth()}-#{d.getDay()} #{d.getHours()}:#{d.getMinutes()}"

    json = @toJSON()
    json.safeName = @get('name').replace /</, '&lt;'
    json.finishedClass = if @isFinished() then 'finished' else ''
    json.timestamp = formatDate json.finishedAt or json.createdAt
    return json
