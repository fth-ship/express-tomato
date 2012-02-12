class exports.Title extends Backbone.View
  el: $('#title')

  events:
    'click .slug': 'edit'
    'keypress .input': 'updateOnEnter'

  initialize: ->
    _.bindAll @, 'render', 'close'

    @model.bind 'change', @render

    @render()

  render: ->
    slug = @model.get 'slug'
    @$('.slug').text slug
    @input = @$('.input')
    @input.bind 'blur', @close
    @input.val slug
    @

  edit: ->
    $(@el).toggleClass 'editing'
    @input.focus()
    @input.select()

  close: ->
    params = slug: @input.val()
    @model.save params, wait: true
    $(@el).removeClass 'editing'

  updateOnEnter: (e) ->
    @close() if e.keyCode is 13
