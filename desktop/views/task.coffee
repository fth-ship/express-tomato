class exports.Task extends Backbone.View
  tagName: 'li'
  className: 'task'

  template: _.template $('#task-template').html()

  events:
    'dblclick': 'triggerStart'
    'click .name': 'edit'
    'click .finish': 'toggleFinished'
    'click .remove': 'remove'
    'click .cursor': 'triggerSelect'
    'keypress .input': 'updateOnEnter'

  initialize: ->
    @model.bind 'change', @render
    @model.bind 'task:edit', @edit, @

  render: =>
    $(@el).attr 'id', @model.id
    $(@el).html @template @model.toTemplate()

    toms = @$ '.tomatoes'
    for tom in @model.get('tomatoes') or []
      toms.append '<span></span>'

    if @model.isFinished()
      $(@el).addClass 'finished'
    else
      $(@el).removeClass 'finished'

    name = @model.get 'name'

    @$('.name').text name

    @input = @$ '.input'
    @input.bind 'blur', @close
    @input.val name
    @

  toggleFinished: ->
    @model.toggleFinished()

  edit: ->
    return if @model.isFinished()
    $(@el).addClass 'editing'
    @input.focus()
    return false

  close: =>
    name = @input.val()
    if name isnt @model.get 'name'
      @model.save name: name
    $(@el).removeClass 'editing'
    $('body').focus()

  updateOnEnter: (e) ->
    @close() if e.keyCode is 13

  remove: ->
    @model.destroy()
    $(@el).remove()

  triggerSelect: ->
    return if @model.isFinished()
    @trigger 'task:select', @model.id

  triggerStart: ->
    return if @model.isFinished()
    @trigger 'task:start', @model.id
