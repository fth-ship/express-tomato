timer_model = require 'models/timer'

tasks = require 'views/tasks'
timer = require 'views/timer'
title = require 'views/title'

class exports.App extends Backbone.View
  el: $('#app')

  initialize: ->
    Backbone.history or= new Backbone.History

    @timer = new timer_model.Timer(tomato: @model)
    @timerView = new timer.Timer(model: @timer)
    @timerView.render()

    @title = new title.Title(model: @model)
    @tasks = new tasks.Tasks(model: @model, collection: @collection)

    @model.bind 'change:slug', @redirect

    @timer.bind 'timer:start', @timerStarted
    @timer.bind 'timer:cancel', @timerCancelled

    @collection.bind 'task:start', @taskStarted
    @collection.bind 'reset', @tasksReset

    $(document).bind 'keypress', @keyPressed

  redirect: (model, slug) =>
    document.location.href = "#{@model.get 'basepath'}/#{slug}"

  timerStarted: =>
    $('#new-task').focus()
    if 'work' is @timer.get 'flavor'
      @tasks.selected().addTomato()

  timerCancelled: =>
    if 'work' isnt @timer.get 'flavor'
      @tasks.selected().removeTomato()

  taskStarted: (task) =>
    @timer.start()

  tasksReset: (tasks) =>
    return $('#about').hide().fadeIn(300) if tasks.length is 0
    workSec = @model.get 'workSec'
    now = Date.now()
    tasks.each (task) =>
      for tom in task.get('tomatoes') or []
        elapsedSec = (now - new Date tom) / 1000
        if elapsedSec < workSec
          @timer.set flavor: 'work', seconds: Math.round workSec - elapsedSec
          @timer.start silent: true
          $('#new-task').focus()
          return

  keyPressed: (e) =>
    return if e.target.value? or @timer.isRunning()
    console.log e.which, String.fromCharCode e.which

    if e.which in [61, 43]
      $('#new-task').focus()
      return false

    if e.which is 107
      @tasks.selectPrev()
      return false

    if e.which is 106
      @tasks.selectNext()
      return false

    if e.which is 102
      @tasks.selected().toggleFinished()
      return false

    if e.which is 13
      @tasks.selected().start()
