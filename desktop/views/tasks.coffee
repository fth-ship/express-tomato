task = require 'views/task'

class exports.Tasks extends Backbone.View
  el: $('#tasks')

  events:
    'sortupdate': 'sortUpdated'
    'keypress #new-task': 'keyPressed'

  initialize: ->
    @cursor = parseInt(document.location.hash.replace(/^\#/, '')) or 1

    @input = $('#new-task')

    @collection.bind 'add', @addOne
    @collection.bind 'reset', @addAll
    @collection.bind 'all', @render

    @collection.fetch()

  render: =>
    @

  sortUpdated: ->
    @$('li.task').each (i, item) =>
      @collection.get($(item).attr('id')).save order: i

  keyPressed: (e) ->
    return if e.keyCode isnt 13
    @collection.create name: @input.val()
    @input.val ''

  addOne: (item) =>
    view = new task.Task(model: item)
    view.bind 'task:select', @select
    view.bind 'task:start', @start

    el = view.render().el
    $(@el).find('li').first().after el
    $(el).removeClass 'active'

    if @collection.length is 1
      @select item.id
    else
      @selectNext()

  addAll: =>
    reversed = (item for item in @collection.models)
    while item = reversed.pop()
      @addOne item
    @setCursor @cursor

  setCursor: (c) =>
    @$('li').eq(@cursor).removeClass 'active'
    @cursor = c
    @$('li').eq(@cursor).addClass 'active'
    Backbone.history.navigate '' + @cursor

  selected: =>
    @collection.at @cursor - 1

  selectPrev: =>
    return if @cursor is 1
    @setCursor @cursor - 1

  selectNext: =>
    return if @cursor is @collection.length
    @setCursor @cursor + 1

  select: (id) =>
    @collection.each (task, i) =>
      if task.id is id
        @setCursor i + 1
        @render()

  start: (id) =>
    @select id
    @selected().start()
