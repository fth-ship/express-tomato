task = require 'views/task'

class exports.Tasks extends Backbone.View
  el: $('#tasks')

  events:
    'sortupdate': 'sortUpdated'

  initialize: ->
    @cursor = parseInt(document.location.hash.replace(/^\#/, '')) or 1

    @collection.bind 'add', @addOne
    @collection.bind 'reset', @addAll
    @collection.bind 'all', @render

    @collection.fetch()

  render: =>
    @

  sortUpdated: ->
    @$('li.task').each (i, item) =>
      @collection.get($(item).attr('id')).save order: i

  addOne: (item) =>
    view = new task.Task(model: item)
    view.bind 'task:select', @select
    view.bind 'task:start', @start

    el = view.render().el
    $(@el).prepend el
    $(el).removeClass 'active'

  addAll: =>
    reversed = (item for item in @collection.models)
    while item = reversed.pop()
      @addOne item
    @setCursor @cursor

  setCursor: (c) =>
    @$('li').eq(@cursor - 1).removeClass 'active'

    @cursor = Math.min c, @collection.length

    el = @$('li').eq @cursor - 1
    el.addClass 'active'

    hh = $('#header').height()
    wh = $(window).height()
    elTop = el.offset().top
    elBottom = elTop + el.height()
    winTop = $(window).scrollTop() + hh
    winBottom = winTop + wh - hh
    $(window).scrollTop(elBottom - wh + 20) if elBottom > winBottom
    $(window).scrollTop elTop - hh if elTop < winTop

    Backbone.history.navigate '' + @cursor

  selected: =>
    @collection.at @cursor - 1

  selectPrev: =>
    return if @cursor <= 1
    @setCursor @cursor - 1

  selectNext: =>
    return if @cursor >= @collection.length
    @setCursor @cursor + 1

  select: (id) =>
    @collection.each (task, i) =>
      if task.id is id
        @setCursor i + 1
        @render()

  start: (id) =>
    @select id
    @selected().start()
