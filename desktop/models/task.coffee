class exports.Task extends Backbone.Model
  validate: (attrs) ->
    return unless 'name' of attrs
    return 'name must be nonempty' unless attrs.name.match /\S+/

  toggleFinished: ->
    @save finishedAt: if @isFinished() then null else Date.now()

  isFinished: ->
    null isnt @get 'finishedAt'

  start: ->
    @trigger 'task:start'

  edit: ->
    @trigger 'task:edit'

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
    json.escapedName = @escape 'name'
    json.timestamp = formatDate json.finishedAt or json.createdAt
    return json

  hideUnlessMatch: (regexp) ->
    @set hidden: not regexp.test @get 'name'
